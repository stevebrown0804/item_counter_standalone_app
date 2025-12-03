part of '../main.dart';

class _MainScreen extends StatefulWidget {
  const _MainScreen();

  @override
  State<_MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<_MainScreen> {
  static _MainScreenState? _lastMounted;

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

  Future<void> _loadLastAddedBanner() async {
    try {
      final text =
      await _db.tryReadSettingString('last_added_banner_text');
      if (text == null || text.isEmpty) {
        return;
      }

      final dismissedStr =
      await _db.tryReadSettingString('last_added_banner_dismissed');
      final dismissed = dismissedStr == '1';

      if (dismissed) {
        return;
      }

      if (!mounted) return;
      setState(() {
        _lastAdded = text;
      });
    } catch (e) {
      debugPrint('Failed to load last-added banner: $e');
    }
  }


  @override
  void initState() {
    super.initState();
    _lastMounted = this;
    _loadActiveTzDisplay();
    _loadUiTextFromSettings();
    _loadLastAddedBanner();
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

                            // Persist banner text and mark as not dismissed
                            await _db.upsertSettingString(
                                'last_added_banner_text', message);
                            await _db.upsertSettingString(
                                'last_added_banner_dismissed', '0');

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
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              setState(() {
                                _lastAdded = null;
                              });
                              await _db.upsertSettingString(
                                'last_added_banner_dismissed',
                                '1',
                              );
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
