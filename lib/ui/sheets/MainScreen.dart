part of '../../main.dart';

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

  // In-memory stack of "Added: ..." banner messages for this app session
  final List<String> _bannerStack = <String>[];

  // Index of the currently active banner in _bannerStack, or -1 if none is active.
  int _bannerIndex = -1;

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
      // Preserve any existing error; otherwise record this one
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
        _bannerStack
          ..clear()
          ..add(text);
        _bannerIndex = 0;
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
      await _store.refreshFromDatabase();
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

  void _pushBannerMessage(String message) {
    final keepUpTo = _bannerIndex < 0 ? 0 : _bannerIndex + 1;
    if (keepUpTo < _bannerStack.length) {
      _bannerStack.removeRange(keepUpTo, _bannerStack.length);
    }
    _bannerStack.add(message);
    _bannerIndex = _bannerStack.length - 1;
    _lastAdded = message;
  }

  Future<void> _persistBannerVisible(String message) async {
    await _db.upsertSettingString('last_added_banner_text', message);
    await _db.upsertSettingString('last_added_banner_dismissed', '0');
  }

  Future<void> _persistBannerHidden() async {
    await _db.upsertSettingString('last_added_banner_dismissed', '1');
  }

  void _applyBannerIndex() {
    if (_bannerIndex < 0 || _bannerIndex >= _bannerStack.length) {
      _bannerIndex = -1;
      _lastAdded = null;
    } else {
      _lastAdded = _bannerStack[_bannerIndex];
    }
  }

  Future<void> _handleUndoPressed() async {
    if (!_store.canUndo) return;

    await _store.undoLastOperation();

    // Step back one banner in history (if any) and hide the card
    if (_bannerIndex >= 0) {
      _bannerIndex--;
    }

    setState(() {
      _applyBannerIndex(); // This will typically null out _lastAdded.
    });

    // Persist that the banner is currently not shown
    await _persistBannerHidden();
  }

  Future<void> _handleRedoPressed() async {
    if (!_store.canRedo) return;

    await _store.redoLastOperation();

    // Step forward one banner in history, if possible
    if (_bannerStack.isNotEmpty) {
      final nextIndex = _bannerIndex + 1;
      if (nextIndex >= 0 && nextIndex < _bannerStack.length) {
        _bannerIndex = nextIndex;
      }
    }

    setState(() {
      _applyBannerIndex();
    });

    if (_lastAdded != null) {
      await _persistBannerVisible(_lastAdded!);
    }
  }

  Future<void> _openAddSheet() async {
    final items = _store.items;
    if (items.isEmpty) return;

    final result = await showModalBottomSheet<_LogItemsSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _LogItemsSheet(
          items: items,
          activeTzName: _store.activeTz.tzName,
        );
      },
    );

    if (result == null || result.quantities.isEmpty) {
      return;
    }

    await _store.addBatchAndTrackUndo(
      result.quantities,
      overrideLocalTimestamp: result.localTimestampOverride,
    );

    if (!mounted) return;

    final message = result.summary;

    setState(() {
      _pushBannerMessage(message);
    });

    await _persistBannerVisible(message);
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
              await _store.refreshFromDatabase();
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
                              await _persistBannerHidden();
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
                        _lhsColumnHeader ?? 'Item',
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
                                  r.itemName,
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
                          ? () async => await _handleUndoPressed()
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
                          ? () async => await _handleRedoPressed()
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
