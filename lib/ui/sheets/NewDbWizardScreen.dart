// /ui/sheets/NewDbWizardScreen.dart

part of '../../main.dart';

enum _NewDbWizardStep {
  countableItems,
  timeZones,
  activeTimeZone,
}

class _NewDbWizardScreen extends StatefulWidget {
  const _NewDbWizardScreen();

  @override
  State<_NewDbWizardScreen> createState() => _NewDbWizardScreenState();
}

class _NewDbWizardScreenState extends State<_NewDbWizardScreen> {
  static const double _screenPadding = 16.0;
  static const double _stepGap = 18.0;
  static const double _buttonGap = 12.0;
  static const double _stepBlockPadding = 12.0;
  static const double _stepBorderRadius = 12.0;
  static const double _activeBorderWidth = 2.0;
  static const double _inactiveBorderWidth = 1.0;
  static const double _labelToControlGap = 12.0;
  static const double _checkIconSize = 22.0;

  final _db = _Db();

  bool _loading = true;
  bool _hasCountableItems = false;
  bool _timeZonesWereAdded = false;
  bool _activeTimeZoneWasSelected = false;
  bool _savingTimeZone = false;
  Object? _loadError;
  List<String> _timeZoneOptions = const [];
  String? _selectedTimeZoneDisplayString;

  _NewDbWizardStep get _currentStep {
    if (!_hasCountableItems) {
      return _NewDbWizardStep.countableItems;
    }

    if (!_timeZonesWereAdded) {
      return _NewDbWizardStep.timeZones;
    }

    return _NewDbWizardStep.activeTimeZone;
  }

  bool get _canUseOptionalSteps => _hasCountableItems;
  bool get _canFinish => _hasCountableItems;

  @override
  void initState() {
    super.initState();
    unawaited(_loadWizardState());
  }

  Future<int?> _readNewestTimeZoneAliasIdOrNull() async {
    final rows = await _db.rawQuery(
      '''
SELECT id
FROM time_zone_aliases
ORDER BY id DESC
LIMIT 1
''',
    );

    if (rows.isEmpty || rows.first['id'] == null) {
      return null;
    }

    final rawId = rows.first['id'];
    return rawId is num ? rawId.toInt() : int.parse(rawId.toString());
  }

  Future<void> _loadWizardState() async {
    try {
      final items = await _db.listItemsOrdered();
      final options = await _db.listTzAliasStrings();
      final activeDisplayString = await _db.readActiveTzAliasString();

      String? selectedDisplayString;
      if (options.contains(activeDisplayString)) {
        selectedDisplayString = activeDisplayString;
      } else {
        selectedDisplayString = _findUtcDisplayString(options);
        if (selectedDisplayString != null) {
          final aliasToSave = await _db.interpretTzAliasInput(selectedDisplayString);
          await _db.setActiveTzByAlias(aliasToSave);
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _hasCountableItems = items.any((item) => item.showItem);
        _timeZoneOptions = options;
        _selectedTimeZoneDisplayString = selectedDisplayString;
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _loadError = e;
      });
    }
  }

  String? _findUtcDisplayString(List<String> options) {
    for (final option in options) {
      final normalized = option.toUpperCase();
      if (normalized == 'UTC' || normalized.contains('/UTC') || normalized.contains('UTC/')) {
        return option;
      }
    }

    return null;
  }

  Future<void> _refreshCountableItemsStatus() async {
    final items = await _db.listItemsOrdered();

    if (!mounted) {
      return;
    }

    setState(() {
      _hasCountableItems = items.any((item) => item.showItem);
    });
  }

  Future<void> _refreshTimeZoneOptions() async {
    final options = await _db.listTzAliasStrings();
    final activeDisplayString = await _db.readActiveTzAliasString();

    if (!mounted) {
      return;
    }

    setState(() {
      _timeZoneOptions = options;
      _selectedTimeZoneDisplayString =
      options.contains(activeDisplayString) ? activeDisplayString : _findUtcDisplayString(options);
    });
  }

  Future<void> _openCountableItemsEditor() async {
    await _doEditCountableItemsSheet(
      context: context,
      db: _db,
      onInteractionComplete: (_) async {},
    );

    await _refreshCountableItemsStatus();

    final main = _MainScreenState._lastMounted;
    if (main != null && main.mounted) {
      await main._store.refreshFromDatabase();
      await main._loadActiveTzDisplay();
    }
  }

  Future<void> _openTimeZoneEditor() async {
    final newestIdBefore = await _readNewestTimeZoneAliasIdOrNull();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _EditTimeZonesSheet(
          db: _db,
          showBackButton: false,
          showBottomCloseButtons: true,
          onTimeZonesChanged: () async {
            await _refreshTimeZoneOptions();
          },
        );
      },
    );

    final newestIdAfter = await _readNewestTimeZoneAliasIdOrNull();
    final addedTimeZone =
        newestIdAfter != null &&
            (newestIdBefore == null || newestIdAfter > newestIdBefore);

    if (addedTimeZone) {
      await _db.upsertSettingString(
        'time_zone_id',
        newestIdAfter.toString(),
      );
    }

    await _refreshTimeZoneOptions();

    if (!mounted) {
      return;
    }

    if (addedTimeZone) {
      final savedDisplayString = await _db.readActiveTzAliasString();

      if (!mounted) {
        return;
      }

      setState(() {
        _timeZonesWereAdded = true;
        _selectedTimeZoneDisplayString = savedDisplayString;
        _activeTimeZoneWasSelected = true;
      });
    }
  }

  Future<void> _saveSelectedTimeZone(String selectedDisplayString) async {
    if (_savingTimeZone) {
      return;
    }

    if (selectedDisplayString == _selectedTimeZoneDisplayString && _activeTimeZoneWasSelected) {
      return;
    }

    setState(() {
      _savingTimeZone = true;
    });

    try {
      final aliasToSave = await _db.interpretTzAliasInput(selectedDisplayString);
      await _db.setActiveTzByAlias(aliasToSave);
      final savedDisplayString = await _db.readActiveTzAliasString();

      final main = _MainScreenState._lastMounted;
      if (main != null && main.mounted) {
        await main._store.refreshFromDatabase();
        await main._loadActiveTzDisplay();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedTimeZoneDisplayString = savedDisplayString;
        _activeTimeZoneWasSelected = true;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save time zone: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingTimeZone = false;
        });
      }
    }
  }

  void _finishWizard() {
    Navigator.of(context).pop();
  }

  Widget _buildCheckIcon({
    required bool checked,
    required bool optional,
    required bool enabled,
  }) {
    if (checked) {
      return const Icon(
        Icons.check_circle,
        color: Colors.green,
        size: _checkIconSize,
      );
    }

    if (optional) {
      return Icon(
        Icons.check_circle,
        color: enabled ? Theme.of(context).disabledColor : Theme.of(context).disabledColor.withValues(alpha: 0.45),
        size: _checkIconSize,
      );
    }

    return SizedBox(
      width: _checkIconSize,
      height: _checkIconSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled
                ? Theme.of(context).disabledColor
                : Theme.of(context).disabledColor.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }

  Widget _buildStepBlock({
    required _NewDbWizardStep step,
    required bool checked,
    required bool optional,
    required bool enabled,
    required String title,
    required Widget child,
  }) {
    final isCurrent = _currentStep == step;
    final colorScheme = Theme.of(context).colorScheme;
    final disabledColor = Theme.of(context).disabledColor;
    final contentOpacity = enabled ? 1.0 : 0.38;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(_stepBlockPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_stepBorderRadius),
        border: Border.all(
          color: isCurrent && enabled ? colorScheme.primary : disabledColor,
          width: isCurrent && enabled ? _activeBorderWidth : _inactiveBorderWidth,
        ),
      ),
      child: Opacity(
        opacity: contentOpacity,
        child: IgnorePointer(
          ignoring: !enabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildCheckIcon(
                    checked: checked,
                    optional: optional,
                    enabled: enabled,
                  ),
                  const SizedBox(width: _buttonGap),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: _labelToControlGap),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountableItemsStep() {
    return _buildStepBlock(
      step: _NewDbWizardStep.countableItems,
      checked: _hasCountableItems,
      optional: false,
      enabled: true,
      title: 'Step 1. Add items to count',
      child: Align(
        alignment: Alignment.center,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.edit),
          label: const Text('Add countable items'),
          onPressed: _openCountableItemsEditor,
        ),
      ),
    );
  }

  Widget _buildTimeZonesStep() {
    return _buildStepBlock(
      step: _NewDbWizardStep.timeZones,
      checked: _timeZonesWereAdded,
      optional: true,
      enabled: _canUseOptionalSteps,
      title: 'Step 2. Add time zones',
      child: Align(
        alignment: Alignment.center,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.public),
          label: const Text('Edit time zones'),
          onPressed: _openTimeZoneEditor,
        ),
      ),
    );
  }

  Widget _buildChooseTimeZoneStep() {
    final selectedValue = _timeZoneOptions.contains(_selectedTimeZoneDisplayString)
        ? _selectedTimeZoneDisplayString
        : null;

    return _buildStepBlock(
      step: _NewDbWizardStep.activeTimeZone,
      checked: _activeTimeZoneWasSelected,
      optional: true,
      enabled: _canUseOptionalSteps,
      title: 'Step 3. Choose a time zone',
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: selectedValue,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: _timeZoneOptions.map((option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              onChanged: _savingTimeZone
                  ? null
                  : (value) async {
                if (value == null) {
                  return;
                }
                await _saveSelectedTimeZone(value);
              },
            ),
          ),
          if (_savingTimeZone) ...[
            const SizedBox(width: _buttonGap),
            const SizedBox(
              width: _checkIconSize,
              height: _checkIconSize,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_loadError != null) {
      return Padding(
        padding: const EdgeInsets.all(_screenPadding),
        child: Text(
          'Error loading new database wizard: $_loadError',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: _screenPadding,
          right: _screenPadding,
          top: _screenPadding,
          bottom: _screenPadding + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCountableItemsStep(),
            const SizedBox(height: _stepGap),
            _buildTimeZonesStep(),
            const SizedBox(height: _stepGap),
            _buildChooseTimeZoneStep(),
            const SizedBox(height: _stepGap),
            Align(
              alignment: Alignment.center,
              child: FilledButton(
                onPressed: _canFinish ? _finishWizard : null,
                child: const Text('OK'),
              ),
            ),
            const SizedBox(height: _buttonGap),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New database setup'),
      ),
      body: _buildBody(),
    );
  }
}