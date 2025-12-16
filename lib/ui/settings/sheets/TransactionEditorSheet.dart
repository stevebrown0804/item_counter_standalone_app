part of '../../../main.dart';

/// Opens the "Edit transaction" bottom sheet for a single transaction.
///
/// Returns `true` if the transaction was successfully updated, `false` otherwise.
Future<bool> openTransactionEditorSheet({
  required BuildContext context,
  required _Db db,
  required _Store store,
  required tz.Location loc,
  required _TxRow tx,
}) async {
  // Convert original UTC timestamp to local so we can show/edit it
  final local = tz.TZDateTime.from(tx.utc, loc);

  String two(int n) => n < 10 ? '0$n' : '$n';
  String fmtDate(tz.TZDateTime d) =>
      '${d.year}-${two(d.month)}-${two(d.day)}';
  String fmtTime(tz.TZDateTime d) =>
      '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';

  final dateCtrl = TextEditingController(text: fmtDate(local));
  final timeCtrl = TextEditingController(text: fmtTime(local));
  final qtyCtrl = TextEditingController(text: tx.qty.toString());

  // Resolve current pill from the store by name
  final pills = store.pills;
  _Pill? selectedPill;
  for (final p in pills) {
    if (p.name == tx.pill) {
      selectedPill = p;
      break;
    }
  }
  selectedPill ??= pills.isNotEmpty ? pills.first : null;

  // Basic parser / normalizer for local date+time fields.
  // Accepts:
  //   dateText: "YYYY-MM-DD"
  //   timeText: "HH:MM" or "HH:MM:SS"
  // Returns a normalized "YYYY-MM-DD HH:MM:SS" string, or null if invalid.
  String? normalizeLocalDateTime(String dateText, String timeText) {
    final dateParts = dateText.split('-');
    if (dateParts.length != 3) return null;

    final year  = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day   = int.tryParse(dateParts[2]);

    if (year == null || month == null || day == null) {
      return null;
    }

    final timeParts = timeText.split(':');
    if (timeParts.length < 2 || timeParts.length > 3) return null;

    final hour   = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);

    if (hour == null || minute == null) {
      return null;
    }

    int second = 0;
    if (timeParts.length == 3) {
      final s = int.tryParse(timeParts[2]);
      if (s == null) return null;
      second = s;
    }

    try {
      final dt = DateTime(year, month, day, hour, minute, second);
      String two(int n) => n.toString().padLeft(2, '0');
      final y = dt.year.toString().padLeft(4, '0');
      final m = two(dt.month);
      final d = two(dt.day);
      final h = two(dt.hour);
      final min = two(dt.minute);
      final sec = two(dt.second);
      return '$y-$m-$d $h:$min:$sec';
    } catch (_) {
      return null;
    }
  }

  final result = await showModalBottomSheet<bool>(
  context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (editCtx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(editCtx).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit transaction',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              // Row 1: Date
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 80,
                    child: Text('Date:'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: dateCtrl,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      final initial =
                      DateTime(local.year, local.month, local.day);
                      final picked = await showDatePicker(
                        context: editCtx,
                        initialDate: initial,
                        firstDate: DateTime(2000, 1, 1),
                        lastDate: DateTime(2100, 12, 31),
                        helpText: 'Choose date',
                      );
                      if (picked != null) {
                        dateCtrl.text = fmtDate(
                          tz.TZDateTime.from(
                            picked,
                            loc,
                          ),
                        );
                      }
                    },
                    child: const Text('Choose date'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 2: Time
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 80,
                    child: Text('Time:'),
                  ),
                  Expanded(
                    child: TextField(
                      controller: timeCtrl,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      final initialTime = TimeOfDay(
                        hour: local.hour,
                        minute: local.minute,
                      );
                      final picked = await showTimePicker(
                        context: editCtx,
                        initialTime: initialTime,
                      );
                      if (picked != null) {
                        final h = two(picked.hour);
                        final m = two(picked.minute);
                        // Keep seconds at 00 when choosing a new time.
                        timeCtrl.text = '$h:$m:00';
                      }
                    },
                    child: const Text('Choose time'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 3: Item
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 80,
                    child: Text('Item:'),
                  ),
                  Expanded(
                    child: DropdownButton<_Pill>(
                      isExpanded: true,
                      value: selectedPill,
                      items: pills
                          .map(
                            (p) => DropdownMenuItem<_Pill>(
                          value: p,
                          child: Text(p.name),
                        ),
                      )
                          .toList(),
                      onChanged: (p) {
                        selectedPill = p;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row 4: Quantity
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 80,
                    child: Text('Quantity:'),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(editCtx).pop(false);
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () async {
                      final dateText = dateCtrl.text.trim();
                      final timeText = timeCtrl.text.trim();
                      final pill = selectedPill;
                      final qtyText = qtyCtrl.text.trim();

                      if (dateText.isEmpty ||
                          timeText.isEmpty ||
                          pill == null ||
                          qtyText.isEmpty) {
                        ScaffoldMessenger.of(editCtx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please fill in all fields.',
                            ),
                          ),
                        );
                        return;
                      }

                      final qty = int.tryParse(qtyText);
                      if (qty == null || qty <= 0) {
                        ScaffoldMessenger.of(editCtx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Quantity must be a positive integer.',
                            ),
                          ),
                        );
                        return;
                      }

                      // Normalize and validate local date/time before calling backend.
                      final normalizedLocalTs =
                      normalizeLocalDateTime(dateText, timeText);
                      if (normalizedLocalTs == null) {
                        ScaffoldMessenger.of(editCtx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Invalid date or time. Use "YYYY-MM-DD" for the date and "HH:MM" or "HH:MM:SS" for the time.',
                            ),
                          ),
                        );
                        return;
                      }

                      String utcTs;
                      try {
                        utcTs =
                        await db.localToUtcDbTimestamp(normalizedLocalTs);
                      } catch (e) {
                        ScaffoldMessenger.of(editCtx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to interpret date/time: $e',
                            ),
                          ),
                        );
                        return;
                      }

                      try {
                        // Insert replacement transaction at chosen time
                        await db.insertManyAtUtcReturningIds(
                          [ _Entry(pill.id, qty) ],
                          utcTs,
                        );

                        // Remove the original transaction
                        await db.deleteTransactionById(tx.id);

                        // Refresh main averages and clear undo/redo
                        await store.refreshFromDatabase();
                        store.clearUndoRedo();

                        // Hide the "Added:" banner and mark dismissed
                        final main = _MainScreenState._lastMounted;
                        if (main != null && main.mounted) {
                          main.setState(() {
                            main._lastAdded = null;
                          });
                          await main._db.upsertSettingString(
                            'last_added_banner_dismissed',
                            '1',
                          );
                        }

                        Navigator.of(editCtx).pop(true);
                      } catch (e) {
                        ScaffoldMessenger.of(editCtx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to update transaction: $e',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Accept'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  return result == true;
}
