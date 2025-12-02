part of 'main.dart';

class _ViewScreen extends StatefulWidget {
  const _ViewScreen();

  @override
  State<_ViewScreen> createState() => _ViewScreenState();
}

class _ViewScreenState extends State<_ViewScreen> {
  static _ViewScreenState? _lastMounted;

  final _store = _Store(_Db());
  bool _loading = true;
  String? _error;
  final _db = _Db();
  String? _tzDisplay;
  String? _lastAdded;
  // UI text loaded from settings table
  String? _appBarTitle;
  String? _lhsColumnHeader;
  String? _rhsHeaderTemplate;

  Future<void> _loadActiveTzDisplay() async {
    final s = await _db.readActiveTzAliasString();
    if (!mounted) return;
    setState(() => _tzDisplay = s);
  }

  Future<void> _loadUiTextFromSettings() async {
    try {
      final appBarTitle =
      await _db.readSettingString('appbar_title');
      final lhsHeader =
      await _db.readSettingString('lhs_column_header');
      final rhsTemplate =
      await _db.readSettingString('rhs_column_header');

      if (!mounted) return;
      setState(() {
        _appBarTitle = appBarTitle;
        _lhsColumnHeader = lhsHeader;
        _rhsHeaderTemplate = rhsTemplate;
      });
    } catch (e) {
      if (!mounted) return;
      // Preserve any existing error; otherwise record this one.
      _error ??= 'Failed to load UI text: $e';
      setState(() {});
    }
  }


  @override
  void initState() {
    super.initState();
    _lastMounted = this;
    _loadActiveTzDisplay();
    _loadUiTextFromSettings();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      await _store.load();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _lastMounted = null;
    super.dispose();
  }

  Future<void> _openAddSheet() async {
    final pills = _store.pills;
    if (pills.isEmpty) return;

    final qty = List<int>.filled(pills.length, 0);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 12,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Log pills',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: pills.length,
                        separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final p = pills[i];
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon:
                                const Icon(Icons.keyboard_arrow_down),
                                onPressed: () => setState(() {
                                  if (qty[i] > 0) qty[i]--;
                                }),
                              ),
                              SizedBox(
                                width: 48,
                                child: TextField(
                                  key: ValueKey('qty_$i'),
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding:
                                    EdgeInsets.symmetric(vertical: 6),
                                    border: OutlineInputBorder(),
                                  ),
                                  controller: TextEditingController(
                                      text: qty[i].toString()),
                                  onChanged: (s) {
                                    final v = int.tryParse(s) ?? 0;
                                    setState(() =>
                                    qty[i] = v.clamp(0, 1000000));
                                  },
                                ),
                              ),
                              IconButton(
                                icon:
                                const Icon(Icons.keyboard_arrow_up),
                                onPressed: () =>
                                    setState(() => qty[i] = qty[i] + 1),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final map = <int, int>{};
                            final parts = <String>[];
                            for (var i = 0; i < pills.length; i++) {
                              final q = qty[i];
                              if (q > 0) {
                                map[pills[i].id] = q;
                                parts.add(
                                    '${pills[i].name} x $q');
                              }
                            }
                            if (map.isEmpty) {
                              if (!mounted) return;
                              Navigator.of(context).pop();
                              return;
                            }
                            await _store.addBatch(map);

                            if (!mounted) return;

                            final message =
                                'Added: ${parts.join(', ')}';

                            if (mounted) {
                              setState(() {
                                _lastAdded = message;
                              });
                            }

                            Navigator.of(context).pop();
                          },
                          child: const Text('Submit'),
                        ),
                      ],
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

  void _openTransactionViewer(BuildContext context) async {
    final tzName = _store.activeTz.tzName;
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

    Future<void> runQuery() async {
      setState(() {
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
            items = await _db.queryTransactionsToday();
            break;

          case _TxMode.lastNDays:
            final n = int.tryParse(lastDaysCtrl.text.trim());
            final days = (n == null || n <= 0) ? 1 : n;
            items = await _db.queryTransactionsLastNDays(days);
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
            items = await _db.queryTransactionsRangeLocal(
              startLocal: startStr,
              endLocal: endStr,
            );
            break;

          case _TxMode.all:
            items = await _db.queryTransactionsAll();
            break;
        }
      } catch (ex) {
        error = ex.toString();
      } finally {
        setState(() {
          busy = false;
        });
      }
    }

    await runQuery();
    if (!mounted) return;

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
              if (mounted) setSheetState(f);
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
                  bottom:
                  MediaQuery.of(ctx).viewInsets.bottom + 12,
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
                    const SizedBox(height: 8),
                    radioRow(_TxMode.today, const Text('Today')),
                    const Divider(),
                    radioRow(
                        _TxMode.lastNDays,
                        Row(
                          children: [
                            const Text('Last'),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 72,
                              child: TextField(
                                controller: lastDaysCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    isDense: true,
                                    border:
                                    OutlineInputBorder()),
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
                            const SizedBox(height: 6),
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
                                const SizedBox(height: 6),
                              ],
                            ),
                          ],
                        )),
                    const Divider(),
                    radioRow(_TxMode.all, const Text('All')),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.search),
                        label: const Text('Apply'),
                        onPressed: busy
                            ? null
                            : () async {
                          FocusManager
                              .instance.primaryFocus
                              ?.unfocus();
                          await runQuery();
                          ss(() {});
                        },
                      ),
                    ),
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
                                      child: Text('Pill name')),
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
                                  final local =
                                  tz.TZDateTime.from(
                                      it.utc, loc);
                                  String two(int n) =>
                                      n < 10
                                          ? '0$n'
                                          : '$n';
                                  final tsStr =
                                      '${local.year}-${two(local.month)}-${two(local.day)} '
                                      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';

                                  return Padding(
                                    padding:
                                    const EdgeInsets
                                        .symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                      children: [
                                        Expanded(
                                            flex: 44,
                                            child:
                                            Text(tsStr)),
                                        const SizedBox(
                                            width: 8),
                                        Expanded(
                                            flex: 44,
                                            child: Text(
                                                it.pill,
                                                softWrap:
                                                true)),
                                        const SizedBox(
                                            width: 8),
                                        Expanded(
                                          flex: 12,
                                          child: Text(
                                            it.qty
                                                .toString(),
                                            textAlign:
                                            TextAlign
                                                .right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
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

  @override
  Widget build(BuildContext context) {
    final titleDays = _store.days;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _appBarTitle ?? 'Item Counter',
            ),
            const SizedBox(height: 3),
            if (_tzDisplay != null)
              Text(
                'Time zone: $_tzDisplay',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const SettingsScreen()),
              );
              if (!mounted) return;
              await _store.load();
              await _loadActiveTzDisplay();
              if (!mounted) return;
              setState(() {});
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_error!,
            style: const TextStyle(color: Colors.red)),
      )
          : AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          return Column(
            children: [
              const SizedBox.shrink(),
              const SizedBox(height: 4),
              if (_lastAdded != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12),
                  child: Card(
                    elevation: 0,
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: Padding(
                      padding:
                      const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(
                                top: 2),
                            child: Icon(Icons.history),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                MediaQuery.of(
                                    context)
                                    .size
                                    .height *
                                    0.35,
                              ),
                              child:
                              SingleChildScrollView(
                                padding:
                                const EdgeInsets
                                    .only(
                                    right: 8),
                                child: SelectionArea(
                                  child: Text(
                                    _lastAdded!,
                                    softWrap: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Clear',
                            icon:
                            const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _lastAdded = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _lhsColumnHeader ?? 'Pill',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      (_rhsHeaderTemplate ?? 'Avg. ({days} day(s))')
                          .replaceAll('{days}', titleDays.toString()),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _store.rows.length,
                  itemExtent: 28.0,
                  itemBuilder: (context, i) {
                    final r = _store.rows[i];
                    return Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets
                              .symmetric(
                              horizontal: 12,
                              vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.pillName,
                                  maxLines: 1,
                                  overflow:
                                  TextOverflow
                                      .ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.0),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                r.avg
                                    .toStringAsFixed(
                                    2),
                                style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.0),
                                textAlign:
                                TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment
                                .bottomCenter,
                            child: Container(
                              height: 1,
                              color:
                              Colors.grey.shade300,
                              margin: const EdgeInsets
                                  .symmetric(
                                  horizontal: 8),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _store,
            builder: (context, _) {
              final enabled = _store.canUndo;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Opacity(
                  opacity: enabled ? 1.0 : 0.38,
                  child: IgnorePointer(
                    ignoring: !enabled,
                    child: FloatingActionButton(
                      heroTag: 'undo_fab',
                      onPressed: enabled
                          ? () async => await _store.undoLast()
                          : null,
                      mini: true,
                      tooltip: 'Undo last',
                      child: const Icon(Icons.undo),
                    ),
                  ),
                ),
              );
            },
          ),
          FloatingActionButton.extended(
            heroTag: 'add_fab',
            onPressed: _openAddSheet,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
          AnimatedBuilder(
            animation: _store,
            builder: (context, _) {
              final enabled = _store.canRedo;
              return Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Opacity(
                  opacity: enabled ? 1.0 : 0.38,
                  child: IgnorePointer(
                    ignoring: !enabled,
                    child: FloatingActionButton(
                      heroTag: 'redo_fab',
                      onPressed: enabled
                          ? () async => await _store.redoLast()
                          : null,
                      mini: true,
                      tooltip: 'Redo last',
                      child: const Icon(Icons.redo),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
