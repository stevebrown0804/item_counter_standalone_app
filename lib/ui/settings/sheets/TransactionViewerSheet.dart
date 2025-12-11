part of '../../../main.dart';

Future<void> openTransactionViewerSheet({
  required BuildContext context,
  required _Db db,
  required _Store store,
  required void Function(VoidCallback) parentSetState,
  required bool Function() parentMounted,
})
async {
  final tzName = store.activeTz.tzName;
  tz.Location loc;
  try {
    loc = tz.getLocation(tzName);
  } catch (_) {
    loc = tz.getLocation('Etc/UTC');
  }

  _TxMode mode = _TxMode.today;
  final lastDaysCtrl = TextEditingController(text: '7');
  DateTime? startLocal;
  DateTime? endLocal;

  List<_TxRow> items = [];
  bool busy = false;
  String? error;
  int? selectedIndex;

  Future<void> runQuery() async {
    parentSetState(() {
      busy = true;
      error = null;
    });

    String formatLocal(DateTime dt) {
      String two(int n) => n.toString().padLeft(2, '0');
      return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
          '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
    }

    try {
      switch (mode) {
        case _TxMode.today:
          items = await db.queryTransactionsToday();
          break;

        case _TxMode.lastNDays:
          final n = int.tryParse(lastDaysCtrl.text.trim());
          final days = (n == null || n <= 0) ? 1 : n;
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

          String fmtLocal(DateTime? d) {
            if (d == null) return '';
            String two(int n) => n < 10 ? '0$n' : '$n';
            return '${d.year}-${two(d.month)}-${two(d.day)} '
                '${two(d.hour)}:${two(d.minute)}';
          }

          Widget radioRow(_TxMode m, Widget trailing) => Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Radio<_TxMode>(
                value: m,
                groupValue: mode,
                onChanged: (v) => ss(() {
                  mode = v!;
                }),
              ),
              const SizedBox(width: 4),
              Expanded(child: trailing),
            ],
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
                        onPressed: () => Navigator.of(ctx).pop(),
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
                          ss(() {});
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
                            width: 56,
                            child: TextField(
                              controller: lastDaysCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder()),
                              onTap: () => ss(() {
                                mode = _TxMode.lastNDays;
                              }),
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
                                  onTap: () => ss(() {
                                    mode = _TxMode.range;
                                  }),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () async {
                                  ss(() {
                                    mode = _TxMode.range;
                                  });
                                  final picked =
                                  await _pickLocalDateTime(
                                      context,
                                      loc: loc,
                                      initialLocal:
                                      startLocal);
                                  ss(() {
                                    startLocal = picked;
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
                                              text: fmtLocal(
                                                  endLocal)),
                                          decoration:
                                          InputDecoration(
                                            isDense: true,
                                            border:
                                            const OutlineInputBorder(),
                                            hintText: fmtLocal(
                                                startLocal)
                                                .isEmpty
                                                ? '— select date —'
                                                : null,
                                            hintStyle:
                                            const TextStyle(
                                                color: Colors
                                                    .grey),
                                          ),
                                          onTap: () => ss(() {
                                            mode =
                                                _TxMode.range;
                                          }),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton(
                                    onPressed: () async {
                                      ss(() {
                                        mode = _TxMode.range;
                                      });
                                      final picked =
                                      await _pickLocalDateTime(
                                          context,
                                          loc: loc,
                                          initialLocal:
                                          endLocal);
                                      ss(() {
                                        endLocal = picked;
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
                  //const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.center,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.search),
                      label: const Text('Apply filter'),
                      onPressed: busy
                          ? null
                          : () async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        await runQuery();
                        ss(() {
                          // Clear any selected transaction after applying a new filter.
                          selectedIndex = null;
                        });
                      },
                    ),
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
                                String two(int n) => n < 10 ? '0$n' : '$n';
                                final tsStr =
                                    '${local.year}-${two(local.month)}-${two(local.day)} '
                                    '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';

                                final isSelected = selectedIndex == i;
                                final highlightColor = Theme.of(ctx)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.08);

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
                                            it.pill,
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

                            // 1. Ask for confirmation in a modal dialog.
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
                            // 1a. Cancel (or dismiss) → do nothing, stay on the sheet.
                            if (confirmed != true) {
                              return;
                            }
                            // 1b.i. Delete the transaction from the database.
                            try {
                              await db.deleteTransactionById(tx.id);
                            } catch (e) {
                              ss(() {
                                error = 'Failed to delete transaction: $e';
                              });
                              return;
                            }

                            // Refresh main averages and clear undo/redo history.
                            await store.load();
                            store.clearUndoRedo();

                            // 1b.iii. Close the "Added: ..." card on the main sheet and persist dismissal.
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
                            // 1b.ii. Refresh the list in this sheet and clear the selection.
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
