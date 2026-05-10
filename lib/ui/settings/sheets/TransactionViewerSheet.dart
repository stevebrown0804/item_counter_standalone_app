// /ui/settings/sheets/TransactionViewerSheet.dart

part of '../../../main.dart';

Future<DateTime?> _pickLocalDateTime(
    BuildContext context, {
      required tz.Location loc,
      required DateTime firstDate,
      required DateTime lastDate,
      DateTime? initialLocal,
    })
async {
  final nowLocal = tz.TZDateTime.now(loc);
  final initial = initialLocal ?? nowLocal;

  DateTime initialDate = DateTime(initial.year, initial.month, initial.day);
  if (initialDate.isBefore(firstDate)) {
    initialDate = firstDate;
  }
  if (initialDate.isAfter(lastDate)) {
    initialDate = lastDate;
  }

  final d = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  );
  if (d == null) return null;

  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );

  if (t == null) return null;

  return tz.TZDateTime(loc, d.year, d.month, d.day, t.hour, t.minute);
}

Future<void> doTransactionViewerSheet({
  required BuildContext context,
  required _Db db,
  required _Store store,
  required void Function(VoidCallback) parentSetState,
  required bool Function() parentMounted,
  required Future<void> Function() onBackPressed,
})
async {
  final tzName = store.activeTz.tzName;
  final loc = _AppDateLogic.locationOrUtc(tzName);

  _TxMode mode = _TxMode.today;
  final lastDaysCtrl = TextEditingController();
  DateTime? startLocal;
  DateTime? endLocal;

  List<_TxRow> items = [];
  bool busy = false;
  bool filterNeedsApply = false;
  String? error;
  int? selectedIndex;

  Future<DateTime?> readOldestTransactionDateOnly() async {
    final oldestLocal = await db.readOldestTransactionLocalDate();
    if (oldestLocal == null) {
      return null;
    }

    return DateTime(
      oldestLocal.year,
      oldestLocal.month,
      oldestLocal.day,
    );
  }

  Future<int> readOldestTransactionDigitCountForLastDaysBox() async {
    final oldestDate = await readOldestTransactionDateOnly();
    if (oldestDate == null) {
      return 1;
    }

    final daysAgo = _AppDateLogic.daysAgoFromDate(
      date: oldestDate,
      tzName: tzName,
    );

    final digitCount = daysAgo.toString().length;
    return digitCount < 1 ? 1 : digitCount;
  }

  final oldestTransactionDateOnly = await readOldestTransactionDateOnly();
  final todayDateOnly = _AppDateLogic.todayDateOnly(tzName);
  final yesterdayDateOnly = _AppDateLogic.startDateFromDaysAgo(
    daysAgo: 1,
    tzName: tzName,
  );

  DateTime transactionViewerStartPickerFirstDate() {
    final oldestDate = oldestTransactionDateOnly;
    if (oldestDate == null) {
      return yesterdayDateOnly;
    }

    if (oldestDate.isAfter(yesterdayDateOnly)) {
      return yesterdayDateOnly;
    }

    return oldestDate;
  }

  DateTime transactionViewerStartPickerLastDate() {
    return yesterdayDateOnly;
  }

  DateTime transactionViewerEndPickerFirstDate() {
    final oldestDate = oldestTransactionDateOnly;
    if (oldestDate == null) {
      return todayDateOnly;
    }

    final oneDayAfterOldest = DateTime(
      oldestDate.year,
      oldestDate.month,
      oldestDate.day + 1,
    );

    if (oneDayAfterOldest.isAfter(todayDateOnly)) {
      return todayDateOnly;
    }

    return oneDayAfterOldest;
  }

  DateTime transactionViewerEndPickerLastDate() {
    return todayDateOnly;
  }

  final lastDaysTextBoxDigitCount =
  await readOldestTransactionDigitCountForLastDaysBox();

  int? parseLastDaysInput() {
    final raw = lastDaysCtrl.text.trim();
    if (!RegExp(r'^[0-9]+$').hasMatch(raw)) {
      return null;
    }

    return int.parse(raw);
  }

  Future<int?> oldestTransactionDaysAgo() async {
    final oldestDate = await readOldestTransactionDateOnly();
    if (oldestDate == null) {
      return null;
    }

    return _AppDateLogic.daysAgoFromDate(
      date: oldestDate,
      tzName: tzName,
    );
  }

  void setLastDaysText(int days) {
    final text = days.toString();
    lastDaysCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  bool lastDaysFilterIsValid() {
    return parseLastDaysInput() != null;
  }

  Future<void> runQuery() async {
    parentSetState(() {
      busy = true;
      error = null;
    });

    String formatLocal(DateTime dt) {
      return _AppDateLogic.formatDbTimestamp(dt);
    }

    try {
      switch (mode) {
        case _TxMode.today:
          items = await db.queryTransactionsToday();
          break;

        case _TxMode.lastNDays:
          final requestedDays = parseLastDaysInput();
          if (requestedDays == null) {
            throw StateError('Enter a non-negative integer for Last # days.');
          }

          final effectiveRequestedDays = requestedDays == 0 ? 1 : requestedDays;
          final oldestDays = await oldestTransactionDaysAgo();
          final days = oldestDays == null || effectiveRequestedDays <= oldestDays
              ? effectiveRequestedDays
              : oldestDays;

          if (days != requestedDays) {
            setLastDaysText(days);
          }

          items = await db.queryTransactionsLastNDays(days);
          break;

        case _TxMode.range:
          String? startStr;
          String? endStr;
          if (startLocal != null) {
            startStr = formatLocal(startLocal!);
          }
          if (endLocal != null) {
            endStr = formatLocal(endLocal!);
          }
          items = await db.queryTransactionsRangeLocal(
            startLocal: startStr,
            endLocal: endStr,
          );
          break;

        case _TxMode.all:
          items = await db.queryTransactionsAll();
          break;
      }

      filterNeedsApply = false;
    } catch (ex) {
      error = ex.toString();
    } finally {
      parentSetState(() {
        busy = false;
      });
    }
  }

  await runQuery();
  if (!parentMounted()) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          void ss(VoidCallback f) {
            if (parentMounted()) setSheetState(f);
          }

          void markFilterNeedsApply() {
            ss(() {
              filterNeedsApply = mode != _TxMode.lastNDays || lastDaysFilterIsValid();
            });
          }

          void setModeAndMarkFilterNeedsApply(_TxMode nextMode) {
            ss(() {
              mode = nextMode;
              filterNeedsApply = mode != _TxMode.lastNDays || lastDaysFilterIsValid();
            });
          }

          String fmtLocal(DateTime? d) {
            if (d == null) return '';
            return _AppDateLogic.formatDashTimestampMinutes(d);
          }

          String endDateDisplayText() {
            if (endLocal == null) {
              return 'Today';
            }

            return fmtLocal(endLocal);
          }

          double measureTextWidth(String text, TextStyle? style) {
            final painter = TextPainter(
              text: TextSpan(
                text: text,
                style: style,
              ),
              textDirection: TextDirection.ltr,
              textScaler: MediaQuery.textScalerOf(ctx),
            )..layout();

            return painter.width;
          }

          String widestDigit(TextStyle? style) {
            var widest = '0';
            var widestWidth = 0.0;

            for (final digit in const <String>[
              '0',
              '1',
              '2',
              '3',
              '4',
              '5',
              '6',
              '7',
              '8',
              '9',
            ]) {
              final width = measureTextWidth(digit, style);
              if (width > widestWidth) {
                widestWidth = width;
                widest = digit;
              }
            }

            return widest;
          }

          Widget radioRow(_TxMode m, Widget trailing) => Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Radio<_TxMode>(
                value: m,
                groupValue: mode,
                onChanged: (v) {
                  if (v == null) {
                    return;
                  }

                  setModeAndMarkFilterNeedsApply(v);
                },
              ),
              const SizedBox(width: 4),
              Expanded(child: trailing),
            ],
          );

          final inputStyle = Theme.of(ctx).textTheme.bodyMedium;
          const horizontalContentPadding = 12.0;
          const verticalContentPadding = 8.0;
          const borderWidthPerSide = 1.0;
          const extraInteriorSlack = 20.0;

          final wd = widestDigit(inputStyle);
          final widestLastDaysString = List<String>.filled(
            lastDaysTextBoxDigitCount,
            wd,
          ).join();

          final lastDaysTextWidth = measureTextWidth(
            widestLastDaysString,
            inputStyle,
          );

          final lastDaysTextBoxWidth =
              lastDaysTextWidth +
                  (horizontalContentPadding * 2) +
                  (borderWidthPerSide * 2) +
                  extraInteriorSlack;

          final lastDaysInputDecoration = InputDecoration(
            isDense: true,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: horizontalContentPadding,
              vertical: verticalContentPadding,
            ),
          );

          final canApplyFilter = filterNeedsApply &&
              !busy &&
              (mode != _TxMode.lastNDays || lastDaysFilterIsValid());

          final applyFilterButton = canApplyFilter
              ? FilledButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('Apply filter'),
            onPressed: () async {
              FocusManager.instance.primaryFocus?.unfocus();
              await runQuery();
              ss(() {
                // Clear any selected transaction after applying a new filter.
                selectedIndex = null;
              });
            },
          )
              : ElevatedButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('Apply filter'),
            onPressed: null,
          );

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await onBackPressed();
                        },
                      ),
                      const SizedBox(width: 4),
                      const Text('Transaction Viewer',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Refresh',
                        icon: const Icon(Icons.refresh),
                        onPressed: busy
                            ? null
                            : () async {
                          await runQuery();
                          ss(() {
                            selectedIndex = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  radioRow(_TxMode.today, const Text('Today')),
                  const Divider(),
                  radioRow(
                      _TxMode.lastNDays,
                      Row(
                        children: [
                          const Text('Last'),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: lastDaysTextBoxWidth,
                            child: TextField(
                              controller: lastDaysCtrl,
                              keyboardType: TextInputType.number,
                              style: inputStyle,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: lastDaysInputDecoration,
                              onTap: () => setModeAndMarkFilterNeedsApply(
                                _TxMode.lastNDays,
                              ),
                              onChanged: (_) => markFilterNeedsApply(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('days'),
                        ],
                      )),
                  const Divider(),
                  radioRow(
                      _TxMode.range,
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('From'),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  readOnly: true,
                                  controller: TextEditingController(
                                      text: fmtLocal(startLocal)),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border:
                                    const OutlineInputBorder(),
                                    hintText: fmtLocal(startLocal)
                                        .isEmpty
                                        ? '— select date —'
                                        : null,
                                    hintStyle: const TextStyle(
                                        color: Colors.grey),
                                  ),
                                  onTap: () => setModeAndMarkFilterNeedsApply(
                                    _TxMode.range,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () async {
                                  setModeAndMarkFilterNeedsApply(
                                    _TxMode.range,
                                  );
                                  final picked =
                                  await _pickLocalDateTime(
                                      context,
                                      loc: loc,
                                      firstDate: transactionViewerStartPickerFirstDate(),
                                      lastDate: transactionViewerStartPickerLastDate(),
                                      initialLocal:
                                      startLocal);
                                  if (picked == null) {
                                    return;
                                  }
                                  ss(() {
                                    startLocal = picked;
                                    filterNeedsApply = true;
                                  });
                                },
                                child:
                                const Text('Pick start date'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Text('to'),
                                  const SizedBox(width: 26),
                                  Expanded(
                                    child: Stack(
                                      alignment:
                                      Alignment.center,
                                      children: [
                                        TextField(
                                          readOnly: true,
                                          controller:
                                          TextEditingController(
                                              text: endDateDisplayText()),
                                          style: endLocal == null
                                              ? TextStyle(
                                            color: Theme.of(ctx).hintColor,
                                          )
                                              : null,
                                          decoration:
                                          const InputDecoration(
                                            isDense: true,
                                            border:
                                            OutlineInputBorder(),
                                          ),
                                          onTap: () => setModeAndMarkFilterNeedsApply(
                                            _TxMode.range,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton(
                                    onPressed: () async {
                                      setModeAndMarkFilterNeedsApply(
                                        _TxMode.range,
                                      );
                                      final picked =
                                      await _pickLocalDateTime(
                                          context,
                                          loc: loc,
                                          firstDate: transactionViewerEndPickerFirstDate(),
                                          lastDate: transactionViewerEndPickerLastDate(),
                                          initialLocal:
                                          endLocal);
                                      if (picked == null) {
                                        return;
                                      }
                                      ss(() {
                                        endLocal = picked;
                                        filterNeedsApply = true;
                                      });
                                    },
                                    child:
                                    const Text('Pick end date'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                          ),
                        ],
                      )),
                  const Divider(),
                  radioRow(_TxMode.all, const Text('All')),
                  Align(
                    alignment: Alignment.center,
                    child: applyFilterButton,
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: TextStyle(
                            color: Theme.of(ctx)
                                .colorScheme
                                .error),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius:
                        BorderRadius.circular(16),
                        border: Border.all(
                            color: Theme.of(ctx)
                                .dividerColor),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding:
                            const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8),
                            child: Row(
                              children: const [
                                Expanded(
                                    flex: 44,
                                    child: Text('Timestamp')),
                                Expanded(
                                    flex: 44,
                                    child: Text('Item name')),
                                Expanded(
                                    flex: 12,
                                    child: Text('Qty.',
                                        textAlign:
                                        TextAlign.right)),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: busy
                                ? const Center(
                                child:
                                CircularProgressIndicator())
                                : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (c, i) {
                                final it = items[i];
                                final local = tz.TZDateTime.from(it.utc, loc);
                                final tsStr = _AppDateLogic.formatDbTimestamp(local);

                                final isSelected = selectedIndex == i;
                                final highlightColor = Theme.of(ctx)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.08);

                                return InkWell(
                                  onTap: () => ss(() {
                                    selectedIndex =
                                    isSelected ? null : i;
                                  }),
                                  child: Container(
                                    color: isSelected ? highlightColor : null,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 44,
                                          child: Text(tsStr),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 44,
                                          child: Text(
                                            it.item,
                                            softWrap: true,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 12,
                                          child: Text(
                                            it.qty.toString(),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete transaction'),
                          onPressed: selectedIndex == null
                              ? null
                              : () async {
                            final idx = selectedIndex;
                            if (idx == null || idx < 0 || idx >= items.length) {
                              return;
                            }
                            final tx = items[idx];

                            //Ask for confirmation in a modal dialog
                            final confirmed = await showDialog<bool>(
                              context: ctx,
                              builder: (dialogCtx) {
                                return AlertDialog(
                                  title: const Text('Confirm deletion?'),
                                  content: const Text(
                                    'This will permanently delete the selected transaction.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogCtx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(dialogCtx).pop(true),
                                      child: const Text('Confirm'),
                                    ),
                                  ],
                                );
                              },
                            );
                            // Cancel (or dismiss) → do nothing; stay on the sheet
                            if (confirmed != true) {
                              return;
                            }
                            // Delete the transaction from the database
                            try {
                              await db.deleteTransactionById(tx.id);
                            } catch (e) {
                              ss(() {
                                error = 'Failed to delete transaction: $e';
                              });
                              return;
                            }

                            // Refresh main sheet's averages and clear the undo/redo history
                            await store.refreshFromDatabase();
                            store.clearUndoRedo();

                            //Close the "Added: ..." card on the main sheet and persist dismissal
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
                            //Refresh the list in this sheet and clear the selection
                            await runQuery();
                            ss(() {
                              selectedIndex = null;
                            });
                          },
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit transaction'),
                          onPressed: selectedIndex == null
                              ? null
                              : () async {
                            final idx = selectedIndex;
                            if (idx == null ||
                                idx < 0 ||
                                idx >= items.length) {
                              return;
                            }
                            final tx = items[idx];

                            final updated =
                            await openTransactionEditorSheet(
                              context: ctx,
                              db: db,
                              store: store,
                              loc: loc,
                              tx: tx,
                            );

                            if (updated == true) {
                              await runQuery();
                              ss(() {
                                selectedIndex = null;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}