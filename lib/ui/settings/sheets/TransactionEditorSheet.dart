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

  String fmtTime(DateTime d) =>
      '${_AppDateLogic.twoDigits(d.hour)}:${_AppDateLogic.twoDigits(d.minute)}:${_AppDateLogic.twoDigits(d.second)}';

  final dateCtrl = TextEditingController(text: _AppDateLogic.formatDashDate(local));
  final timeCtrl = TextEditingController(text: fmtTime(local));
  final qtyCtrl = TextEditingController(text: tx.qty.toString());

  // Resolve current item from the store by name
  final items = store.items;
  _Item? selectedItem;
  for (final p in items) {
    if (p.name == tx.item) {
      selectedItem = p;
      break;
    }
  }
  selectedItem ??= items.isNotEmpty ? items.first : null;

  // Basic parser / normalizer for local date+time fields.
  // Accepts:
  //   dateText: "YYYY-MM-DD"
  //   timeText: "HH:MM" or "HH:MM:SS"
  // Returns a normalized "YYYY-MM-DD HH:MM:SS" string, or null if invalid.
  String? normalizeLocalDateTime(String dateText, String timeText) {
    final parsed = _AppDateLogic.parseDashTimestampSeconds('$dateText $timeText');
    if (parsed == null) {
      return null;
    }

    return _AppDateLogic.formatDbTimestamp(parsed);
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
          bottom: _bottomSheetBottomPadding(editCtx, _roomierBottomSheetBottomPadding),
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
                        dateCtrl.text = _AppDateLogic.formatDashDate(picked);
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
                        final h = _AppDateLogic.twoDigits(picked.hour);
                        final m = _AppDateLogic.twoDigits(picked.minute);
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
                    child: DropdownButton<_Item>(
                      isExpanded: true,
                      value: selectedItem,
                      items: items
                          .map(
                            (p) => DropdownMenuItem<_Item>(
                          value: p,
                          child: Text(p.name),
                        ),
                      )
                          .toList(),
                      onChanged: (p) {
                        selectedItem = p;
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
                      final item = selectedItem;
                      final qtyText = qtyCtrl.text.trim();

                      if (dateText.isEmpty ||
                          timeText.isEmpty ||
                          item == null ||
                          qtyText.isEmpty) {
                        ScaffoldMessenger.of(editCtx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Some fields are missing.',
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
                          [ _Entry(item.id, qty) ],
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