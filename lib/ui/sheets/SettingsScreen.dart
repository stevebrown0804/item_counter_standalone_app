// /ui/sheets/SettingsScreen.dart

part of '../../main.dart';

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

  final Map<String, bool> _dirty = <String, bool>{};
  bool _returnHomeAfterSettingsInteraction = false;

  bool get _hasUnsavedChanges => _dirty.values.any((v) => v);

  void _setDirty(String key, bool isDirty) {
    final prev = _dirty[key];
    if (prev == isDirty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _dirty[key] = isDirty;
      });
    });
  }

  Future<void> _attemptLeaveSettings() async {
    if (!_hasUnsavedChanges) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            title: const Text('Unsaved changes'),
            content: const Text(
              'There are unsaved changes in Settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('abandon'),
                child: const Text('Abandon changes'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop('save'),
                child: const Text('Save changes'),
              ),
            ],
          ),
    );

    if (action == null) return;

    if (action == 'save') {
      final saved = await (_avgKey.currentState?._submit() ?? Future<bool>.value(true));
      if (!saved) return;

      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (action == 'abandon') {
      _avgKey.currentState?.discardChanges();
      _tzKey.currentState?.discardChanges();
      _skipKey.currentState?.discardChanges();

      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<Map<String, bool>?> _showImportTableDialog(BuildContext context) async {
    bool itemsChecked = true;
    bool itemTransactionsChecked = true;
    bool timeZonesChecked = true;
    bool settingsChecked = true;

    return showDialog<Map<String, bool>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            void applyDependencies() {
              if (!itemsChecked) {
                itemTransactionsChecked = false;
              }
              if (!timeZonesChecked) {
                settingsChecked = false;
              }
            }

            applyDependencies();

            Widget buildRow({
              required bool value,
              required ValueChanged<bool?>? onChanged,
              required String label,
              double leftIndent = 0,
            }) {
              final enabled = onChanged != null;

              final checkboxTheme = Theme.of(ctx).checkboxTheme;
              final inactiveFillColor =
                  checkboxTheme.fillColor?.resolve({WidgetState.disabled}) ??
                      Theme.of(ctx).disabledColor.withValues(alpha: 0.38);

              final inactiveCheckColor =
                  checkboxTheme.checkColor?.resolve({WidgetState.disabled}) ??
                      Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.38);

              final checkbox = enabled
                  ? Checkbox(
                value: value,
                onChanged: onChanged,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )
                  : Theme(
                data: Theme.of(ctx).copyWith(
                  checkboxTheme: checkboxTheme.copyWith(
                    fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(WidgetState.disabled)) {
                        return inactiveFillColor;
                      }
                      return checkboxTheme.fillColor?.resolve(states);
                    }),
                    checkColor: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(WidgetState.disabled)) {
                        return inactiveCheckColor;
                      }
                      return checkboxTheme.checkColor?.resolve(states);
                    }),
                  ),
                ),
                child: Checkbox(
                  value: value,
                  onChanged: null,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );

              return Padding(
                padding: EdgeInsets.only(left: leftIndent),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    checkbox,
                    const SizedBox(width: 8),
                    Text(label),
                  ],
                ),
              );
            }

            return AlertDialog(
              title: const Text('Import database'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildRow(
                    value: itemTransactionsChecked,
                    onChanged: itemsChecked
                        ? (v) => setState(() => itemTransactionsChecked = v ?? false)
                        : null,
                    label: 'item transactions',
                  ),
                  buildRow(
                    value: itemsChecked,
                    onChanged: (v) => setState(() {
                      itemsChecked = v ?? false;
                      if (!itemsChecked) {
                        itemTransactionsChecked = false;
                      }
                    }),
                    label: 'items',
                    leftIndent: 28,
                  ),
                  const SizedBox(height: 8),
                  buildRow(
                    value: settingsChecked,
                    onChanged: timeZonesChecked
                        ? (v) => setState(() => settingsChecked = v ?? false)
                        : null,
                    label: 'settings',
                  ),
                  buildRow(
                    value: timeZonesChecked,
                    onChanged: (v) => setState(() {
                      timeZonesChecked = v ?? false;
                      if (!timeZonesChecked) {
                        settingsChecked = false;
                      }
                    }),
                    label: 'time zones',
                    leftIndent: 28,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop({
                    'itemTransactions': itemTransactionsChecked,
                    'items': itemsChecked,
                    'settings': settingsChecked,
                    'timeZones': timeZonesChecked,
                  }),
                  child: const Text('Import'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showImportErrorDialog(BuildContext context, Object error) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import failed'),
        content: Text(error.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showImportInProgressDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        title: Text('Importing database'),
        content: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text('Import in progress...'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImportDatabaseFile(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Select database to import',
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'sqlite3'],
        allowMultiple: false,
        withData: false,
      );

      if (!context.mounted) return;
      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;
      if (path == null || path.isEmpty) {
        throw StateError('Selected file has no readable path.');
      }

      final db = _Db();
      final schemaResult = await db.validateImportDatabaseSchema(path);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected import file: $path\n\n$schemaResult'),
          duration: const Duration(seconds: 10),
        ),
      );

      final selectedTables = await _showImportTableDialog(context);
      if (!context.mounted) return;
      if (selectedTables == null) return;

      _showImportInProgressDialog(context);

      try {
        await db.importSelectedTablesFromDatabase(
          path,
          importItemTransactions: selectedTables['itemTransactions'] ?? false,
          importItems: selectedTables['items'] ?? false,
          importSettings: selectedTables['settings'] ?? false,
          importTimeZones: selectedTables['timeZones'] ?? false,
        );

        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        final main = _MainScreenState._lastMounted;
        if (main != null && main.mounted) {
          main._store.clearUndoRedo();
          await main._store.refreshFromDatabase();
          main.setState(() {});
        }

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Import complete.'),
            duration: Duration(seconds: 6),
          ),
        );
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        if (!context.mounted) return;
        await _showImportErrorDialog(context, e);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import file selection failed: $e'),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> _exportDatabase(BuildContext context) async {
    try {
      //Construct the TZ alias string to affix to the DB export filename
      final s = _MainScreenState._lastMounted;
      final active = s?._store.activeTz;
      final tzName = active?.tzName ?? 'Etc/UTC';
      final alias = active?.alias ?? DateTime
          .now()
          .timeZoneName;

      //Construct the timestamp to affix to the filename, padding timestamp pieces to 2 digits
      final now = tz.TZDateTime.now(tz.getLocation(tzName));
      String two(int n) => n.toString().padLeft(2, '0');
      final ts = '${now.year}-${two(now.month)}-${two(now.day)}_'
          '${two(now.hour)}-${two(now.minute)}-${two(now.second)}';

      //Build the DB export filename from the kDbFileName defined in main.dart
      final fileName = '${kDbFileName.replaceAll(
          RegExp(r'\.db$'), '')}-${ts}_($alias).db';

      //Export and announce
      final dbDir = await getDatabasesPath();
      final liveDb = File(p.join(dbDir, kDbFileName));
      if (!await liveDb.exists()) {
        throw FileSystemException('Database not found', liveDb.path);
      }

      final tmpDir = p.normalize(p.join(dbDir, '..', 'files'));
      await Directory(tmpDir).create(recursive: true);
      final tmpPath = p.join(tmpDir, fileName);

      final tmpFile = File(tmpPath);
      if (await tmpFile.exists() && tmpFile.path != liveDb.path) {
        await tmpFile.delete();
      }
      await liveDb.copy(tmpPath);

      final mediaStore = MediaStore();
      await mediaStore.saveFile(
        tempFilePath: tmpFile.path,
        dirType: DirType.download,
        dirName: DirName.download,
        relativePath: '',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database exported to: Downloads/$fileName'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        debugPrint('Export failed: $e');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            duration: const Duration(
                seconds: 8), //did we actually hard-code "8 seconds of waiting?" why, I wonder
          ),
        );
      }
    }
  }

  Future<void> _showDeleteOldTxDialog(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final db = _Db();

    final days = await db.readAveragingWindowDays();
    final count = await db.countTransactionsOlderThanDays(days);

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            title: const Text('Delete older transactions?'),
            content: Text(
              'This will permanently delete $count transactions older than $days days. '
                  'This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.of(ctx).pop();
                  await _handleDeleteOldTx(context, days);
                },
                child: const Text('Proceed'),
              ),
            ],
          ),
    );
  }

  Future<void> _handleDeleteOldTx(BuildContext context, int days) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final db = _Db();
    final skip = await db.readSkipDeleteSecondConfirm();

    if (skip) {
      final deleted = await db.deleteOldTransactionsWithPolicy(days);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
            Text('Deleted $deleted transactions older than $days days.')),
      );
      return;
    }

    bool skipNext = false;

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) =>
              AlertDialog(
                backgroundColor: Colors.red,
                title: const Text(
                  'Really delete transactions?',
                  style: TextStyle(color: Colors.white),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Abort!'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white),
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.transparent,
                            ),
                            onPressed: () async {
                              FocusManager.instance.primaryFocus?.unfocus();
                              if (skipNext) {
                                await db.setSkipDeleteSecondConfirm(true);
                              }
                              final deleted =
                              await db.deleteOldTransactionsWithPolicy(days);
                              if (!context.mounted) return;
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Deleted $deleted transactions older than $days days.')),
                              );
                            },
                            child: const Text('Proceed'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: skipNext,
                      onChanged: (v) => setState(() => skipNext = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: Colors.white,
                      checkColor: Colors.red,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Skip this step next time.\n(This can be undone in Settings.)',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
        );
      },
    );
  }

  //NOTE: If you want to shuffle around the rows of the settings sheet, here's the place to do that
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _attemptLeaveSettings();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async => await _attemptLeaveSettings(),
          ),
        ),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const Divider(),
                  _ViewTransactionsRow(
                    onPressed: () {
                      final s = _MainScreenState._lastMounted;
                      if (s != null) {
                        doTransactionViewerSheet(
                          context: context,
                          db: s._db,
                          store: s._store,
                          parentSetState: s.setState,
                          parentMounted: () => s.mounted,
                        );
                      }
                    },
                  ),
                  const Divider(),
                  _SummaryStatisticRow(
                    key: _avgKey,
                    onDirtyChanged: (v) => _setDirty('avg_window', v),
                  ),
                  const Divider(),
                  _TzRow(
                    key: _tzKey,
                    onDirtyChanged: (v) => _setDirty('tz', v),
                  ),
                  const Divider(),
                  _EditCountableItemsRow(
                    onPressed: () {
                      doEditCountableItemsSheet(context: context);
                    },
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ExportDatabaseRow(
                        onPressed: () async {
                          await _exportDatabase(context);
                        },
                      ),
                      const SizedBox(width: 12),
                      _ImportDatabaseRow(
                        onPressed: () async {
                          await _pickImportDatabaseFile(context);
                        },
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
                  SwitchListTile(
                    title: Text(
                      'Changing settings returns you to the home screen',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    value: _returnHomeAfterSettingsInteraction,
                    onChanged: (value) {
                      setState(() {
                        _returnHomeAfterSettingsInteraction = value;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reminder: Unimplemented')),
                      );
                    },
                  ),
                  const Spacer(),
                  const Divider(),
                  const _DangerZoneHeader(),
                  _DeleteOutdatedTransactions(
                    onPressed: () => _showDeleteOldTxDialog(context),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  _SkipSecondConfirmationSetting(
                    key: _skipKey,
                    onDirtyChanged: (v) => _setDirty('skip_second_confirm', v),
                  ),
                  const Divider(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}