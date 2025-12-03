part of '../main.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _exportDatabase(BuildContext context) async {
    try {
      final s = _MainScreenState._lastMounted;
      final active = s?._store.activeTz;
      final tzName = active?.tzName ?? 'Etc/UTC';
      final alias = active?.alias ?? DateTime.now().timeZoneName;

      var loc = tz.getLocation('Etc/UTC');
      try {
        loc = tz.getLocation(tzName);
      } catch (_) {}
      final now = tz.TZDateTime.now(loc);

      String two(int n) => n.toString().padLeft(2, '0');
      final ts = '${now.year}-${two(now.month)}-${two(now.day)}_'
          '${two(now.hour)}-${two(now.minute)}-${two(now.second)}';

      final fileName = 'daily-pill-tracking-DB-${ts}_($alias).db';

      final dbDir = await getDatabasesPath();
      final liveDb = File(p.join(dbDir, kDbFileName));
      if (!await liveDb.exists()) {
        throw FileSystemException('Database not found', liveDb.path);
      }

      final tmpDir = p.normalize(p.join(dbDir, '..', 'files'));
      await Directory(tmpDir).create(recursive: true);
      final tmpPath = p.join(tmpDir, fileName);

      final tmpFile = File(tmpPath);
      if (await tmpFile.exists()) {
        try {
          if (tmpFile.path != liveDb.path) {
            try {
              await tmpFile.delete();
            } catch (_) {}
          }
        } catch (_) {}
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
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  Future<void> _showDeleteOldTxDialog(BuildContext context) async {
    final db = _Db();

    final days = await db.readAveragingWindowDays();
    final count = await db.countTransactionsOlderThanDays(days);

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
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
          builder: (ctx, setState) => AlertDialog(
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

  //If you want to shuffle around the rows of the settings sheet, here's the place to do that
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Divider(),
          _ViewTransactionsRow(
            onPressed: () {
              Navigator.of(context).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final s = _MainScreenState._lastMounted;
                if (s != null) {
                  openTransactionViewerSheet(
                    context: s.context,
                    db: s._db,
                    store: s._store,
                    parentSetState: s.setState,
                    parentMounted: () => s.mounted,
                  );

                }
              });
            },
          ),
          const Divider(),
          _ExportDatabaseRow(
            onPressed: () {
              Navigator.of(context).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _exportDatabase(context);
              });
            },
          ),
          const Divider(),
          const _SummaryStatisticRow(),
          const Divider(),
          const _TzRow(), //Time Zone row
          const Divider(),
          const _DangerZoneHeader(),
          _DeleteOutdatedTransactions(
            onPressed: () => _showDeleteOldTxDialog(context),
          ),
          const SizedBox(height: 8),
          const Divider(),
          const _SkipSecondConfirmationSetting(),
          const Divider(),
        ],
      ),
    );
  }
}
