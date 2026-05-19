// /ui/settings/ImportDatabase.dart

part of '../../main.dart';

class _ImportDatabaseRow extends StatelessWidget {
  const _ImportDatabaseRow({
    required this.onInteractionComplete,
    required this.onToast,
  });

  final Future<void> Function(String) onInteractionComplete;
  final void Function(String) onToast;

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
    BuildContext? progressDialogContext;

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
      await db.validateImportDatabaseSchema(path);

      if (!context.mounted) return;
      onToast('Selected import file: $path');

      final selectedTables = await _showImportTableDialog(context);
      if (!context.mounted) return;
      if (selectedTables == null) return;

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          progressDialogContext = ctx;
          return const AlertDialog(
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
          );
        },
      );

      await Future<void>.delayed(Duration.zero);

      try {
        await db.importSelectedTablesFromDatabase(
          path,
          importItemTransactions: selectedTables['itemTransactions'] ?? false,
          importItems: selectedTables['items'] ?? false,
          importSettings: selectedTables['settings'] ?? false,
          importTimeZones: selectedTables['timeZones'] ?? false,
        );

        final dialogContext = progressDialogContext;
        if (dialogContext != null && dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
        }

        final main = _MainScreenState._lastMounted;
        if (main != null && main.mounted) {
          main._store.clearUndoRedo();
          await main._store.refreshFromDatabase();
          main.setState(() {});
        }

        if (!context.mounted) return;
        await onInteractionComplete('Import complete.');
      } catch (e) {
        final dialogContext = progressDialogContext;
        if (dialogContext != null && dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
        }
        if (!context.mounted) return;
        await _showImportErrorDialog(context, e);
      }
    } catch (e) {
      if (!context.mounted) return;
      onToast('Import file selection failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Align(
        alignment: Alignment.center,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.upload),
          label: const Text('Import database'),
          onPressed: () async => await _pickImportDatabaseFile(context),
        ),
      ),
    );
  }
}