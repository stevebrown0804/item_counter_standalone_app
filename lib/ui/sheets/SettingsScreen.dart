// /ui/sheets/SettingsScreen.dart

part of '../../main.dart';

enum _SettingsLeaveAction {
  save,
  abandon,
}

enum _SettingsRowId {
  averagingWindow,
  timeZone,
  skipSecondConfirmation,
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GlobalKey<_SummaryStatisticRowState> _avgKey = GlobalKey<
      _SummaryStatisticRowState>();
  final GlobalKey<_TzRowState> _tzKey = GlobalKey<_TzRowState>();
  final GlobalKey<_SkipSecondConfirmationSettingState> _skipKey =
  GlobalKey<_SkipSecondConfirmationSettingState>();

  final Map<_SettingsRowId, bool> _dirty = <_SettingsRowId, bool>{};
  final Map<_SettingsRowId, bool> _blocked = <_SettingsRowId, bool>{};
  final GlobalKey _settingsBackArrowIconKey = GlobalKey();
  static const double _settingsIndicatorLightDiameterScale = 1.0 / 3.0;
  Size? _settingsBackArrowIconSize;
  bool _returnHomeAfterSettingsInteraction = false;
  bool _settingsHaveBeenSavedSinceOpening = false;
  final _settingsToastController = _StackedToastController();

  bool get _hasUnsavedChanges => _dirty.values.any((v) => v);
  bool get _hasBlockedChanges => _blocked.values.any((v) => v);
  bool get _averagingWindowHasPendingChanges =>
      (_dirty[_SettingsRowId.averagingWindow] ?? false) ||
          (_blocked[_SettingsRowId.averagingWindow] ?? false);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _settingsToastController.dispose();
    super.dispose();
  }

  void _measureSettingsBackArrowIconAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final arrowIconContext = _settingsBackArrowIconKey.currentContext;
      if (arrowIconContext == null) {
        return;
      }

      final renderObject = arrowIconContext.findRenderObject();
      if (renderObject is! RenderBox) {
        throw StateError('Settings back arrow icon render object was not a RenderBox.');
      }

      final measuredSize = renderObject.size;
      if (_settingsBackArrowIconSize == measuredSize) {
        return;
      }

      setState(() {
        _settingsBackArrowIconSize = measuredSize;
      });
    });
  }

  double? _settingsLeadingWidth() {
    final arrowIconSize = _settingsBackArrowIconSize;
    if (arrowIconSize == null) {
      return null;
    }

    final indicatorDiameter =
        arrowIconSize.height * _settingsIndicatorLightDiameterScale;
    final indicatorGap = indicatorDiameter * 0.25;

    return kMinInteractiveDimension + indicatorGap + indicatorDiameter;
  }

  Color _settingsIndicatorLightColor(BuildContext context) {
    if (_hasUnsavedChanges || _hasBlockedChanges) {
      return Colors.red;
    }

    if (_settingsHaveBeenSavedSinceOpening) {
      return Colors.green;
    }

    return Theme.of(context).disabledColor;
  }

  Widget _buildSettingsLeading(BuildContext context) {
    final arrowIconSize = _settingsBackArrowIconSize;

    if (arrowIconSize == null) {
      return IconButton(
        icon: Icon(
          Icons.arrow_back,
          key: _settingsBackArrowIconKey,
        ),
        onPressed: () async => await _attemptLeaveSettings(),
      );
    }

    final indicatorDiameter =
        arrowIconSize.height * _settingsIndicatorLightDiameterScale;
    final indicatorGap = indicatorDiameter * 0.25;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(
            Icons.arrow_back,
            key: _settingsBackArrowIconKey,
          ),
          onPressed: () async => await _attemptLeaveSettings(),
        ),
        SizedBox(width: indicatorGap),
        SizedBox(
          width: indicatorDiameter,
          height: indicatorDiameter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _settingsIndicatorLightColor(context),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  void _showSettingsToast(String message) {
    if (!mounted) {
      return;
    }

    _settingsToastController.show(message);
  }

  Future<void> _refreshMainScreenAfterSettingsInteraction() async {
    final main = _MainScreenState._lastMounted;
    if (main == null || !main.mounted) {
      return;
    }

    await main._store.refreshFromDatabase();
    await main._loadActiveTzDisplay();

    if (!main.mounted) {
      return;
    }

    main.setState(() {});
  }

  Future<void> _completeSettingsInteraction(String message) async {
    if (_returnHomeAfterSettingsInteraction) {
      await _refreshMainScreenAfterSettingsInteraction();

      final main = _MainScreenState._lastMounted;
      if (mounted) {
        Navigator.of(context).pop();
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (main != null && main.mounted) {
          main.showHomeToast(message);
        }
      });

      return;
    }

    _showSettingsToast(message);
  }

  Future<void> _returnHomeAfterNestedSettingsSheetClosed() async {
    if (!_returnHomeAfterSettingsInteraction) {
      return;
    }

    await _refreshMainScreenAfterSettingsInteraction();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _setDirty(_SettingsRowId rowId, bool isDirty) {
    final prev = _dirty[rowId];
    if (prev == isDirty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _dirty[rowId] = isDirty;
        if (isDirty) {
          _settingsHaveBeenSavedSinceOpening = false;
        }
      });
    });
  }

  void _setBlocked(_SettingsRowId rowId, bool isBlocked) {
    final prev = _blocked[rowId];
    if (prev == isBlocked) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _blocked[rowId] = isBlocked;
        if (isBlocked) {
          _settingsHaveBeenSavedSinceOpening = false;
        }
      });
    });
  }

  void _markSettingsSaved() {
    if (!mounted) return;
    setState(() {
      _settingsHaveBeenSavedSinceOpening = true;
    });
  }

  Future<void> _attemptLeaveSettings() async {
    if (!_hasUnsavedChanges && !_hasBlockedChanges) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final action = await showDialog<_SettingsLeaveAction>(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            title: const Text('Unsaved changes'),
            content: const Text(
              'There are unsaved changes in Settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(
                  _SettingsLeaveAction.abandon,
                ),
                child: const Text('Abandon changes'),
              ),
              FilledButton(
                onPressed: _hasBlockedChanges
                    ? null
                    : () => Navigator.of(ctx).pop(
                  _SettingsLeaveAction.save,
                ),
                child: const Text('Save changes'),
              ),
            ],
          ),
    );

    if (action == null) return;

    if (action == _SettingsLeaveAction.save) {
      final saved = await (_avgKey.currentState?._submit() ?? Future<bool>.value(true));
      if (!saved) return;

      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (action == _SettingsLeaveAction.abandon) {
      _avgKey.currentState?.discardChanges();
      _tzKey.currentState?.discardChanges();
      _skipKey.currentState?.discardChanges();

      if (mounted) Navigator.of(context).pop();
      return;
    }

    throw StateError('Unexpected settings leave action: $action');
  }

  Future<bool> _resolveAveragingWindowBeforeDeletingTransactions() async {
    if (!_averagingWindowHasPendingChanges) {
      return true;
    }

    final avgState = _avgKey.currentState;
    if (avgState == null) {
      throw StateError('Averaging window state is unavailable while resolving pending changes.');
    }

    return avgState.resolvePendingChangesBeforeDeletingTransactions();
  }

  //NOTE: If you want to shuffle around the rows of the settings sheet, here's the place to do that
  @override
  Widget build(BuildContext context) {
    _measureSettingsBackArrowIconAfterLayout();

    final bottomSystemPadding = MediaQuery.viewPaddingOf(context).bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _attemptLeaveSettings();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          leadingWidth: _settingsLeadingWidth(),
          leading: _buildSettingsLeading(context),
        ),
        body: Padding(
          padding: EdgeInsets.only(bottom: bottomSystemPadding),
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const Divider(),
                        _ViewTransactionsRow(
                          onBackPressed: _returnHomeAfterNestedSettingsSheetClosed,
                        ),
                        const Divider(),
                        _SummaryStatisticRow(
                          key: _avgKey,
                          onDirtyChanged: (v) => _setDirty(
                            _SettingsRowId.averagingWindow,
                            v,
                          ),
                          onBlockedChanged: (v) => _setBlocked(
                            _SettingsRowId.averagingWindow,
                            v,
                          ),
                          onSaved: _markSettingsSaved,
                          onToast: _showSettingsToast,
                          onInteractionComplete: _completeSettingsInteraction,
                        ),
                        const Divider(),
                        _TzRow(
                          key: _tzKey,
                          onDirtyChanged: (v) => _setDirty(
                            _SettingsRowId.timeZone,
                            v,
                          ),
                          onSaved: _markSettingsSaved,
                          onInteractionComplete: _completeSettingsInteraction,
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _EditCountableItemsRow(
                              onInteractionComplete: _completeSettingsInteraction,
                            ),
                            const SizedBox(width: 12),
                            _EditTimeZonesRow(
                              onTimeZonesChanged: () async {
                                await _tzKey.currentState?._loadOptions();
                              },
                              onInteractionComplete: _completeSettingsInteraction,
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ExportDatabaseRow(
                              onInteractionComplete: _completeSettingsInteraction,
                              onToast: _showSettingsToast,
                            ),
                            const SizedBox(width: 12),
                            _ImportDatabaseRow(
                              onInteractionComplete: _completeSettingsInteraction,
                              onToast: _showSettingsToast,
                            ),
                          ],
                        ),
                        const Divider(),
                      ],
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      children: [
                        _ReturnHomeAfterSettingsInteractionRow(
                          onChanged: (value) {
                            if (_returnHomeAfterSettingsInteraction == value) {
                              return;
                            }
                            setState(() {
                              _returnHomeAfterSettingsInteraction = value;
                            });
                          },
                          onSaved: _markSettingsSaved,
                          onToast: _showSettingsToast,
                        ),
                        const Spacer(),
                        const Divider(),
                        const SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                            child: Text(
                              'Danger Zone',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        _DeleteOutdatedTransactions(
                          onResolvePendingAveragingWindow: _resolveAveragingWindowBeforeDeletingTransactions,
                          onSkipSecondConfirmationSaved: () {
                            _skipKey.currentState?.applySavedValueFromExternalWrite(true);
                            _markSettingsSaved();
                          },
                          onInteractionComplete: _completeSettingsInteraction,
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        _SkipSecondConfirmationSetting(
                          key: _skipKey,
                          onDirtyChanged: (v) => _setDirty(
                            _SettingsRowId.skipSecondConfirmation,
                            v,
                          ),
                          onSaved: _markSettingsSaved,
                          onInteractionComplete: _completeSettingsInteraction,
                        ),
                        const Divider(),
                      ],
                    ),
                  ),
                ],
              ),
              _StackedToastHost(controller: _settingsToastController),
            ],
          ),
        ),
      ),
    );
  }
}