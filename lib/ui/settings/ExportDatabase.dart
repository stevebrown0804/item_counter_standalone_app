// /ui/settings/ExportDatabase.dart

part of '../../main.dart';

class _ExportDatabaseRow extends StatelessWidget {
  const _ExportDatabaseRow({
    required this.onInteractionComplete,
    required this.onToast,
  });

  final Future<void> Function(String) onInteractionComplete;
  final void Function(String) onToast;

  Future<void> _exportDatabase(BuildContext context) async {
    try {
      //Construct the TZ alias string to affix to the DB export filename
      final s = _MainScreenState._lastMounted;
      final active = s?._store.activeTz;
      final tzName = active?.tzName ?? 'Etc/UTC';
      final alias = active?.alias ?? 'UTC';

      //Construct the timestamp to affix to the filename, padding timestamp pieces to 2 digits
      final now = tz.TZDateTime.now(_AppDateLogic.locationOrUtc(tzName));
      final ts = _AppDateLogic.formatDbTimestamp(now).replaceAll(' ', '_').replaceAll(':', '-');

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
        await onInteractionComplete('Database exported to: Downloads/$fileName');
      }
    } catch (e) {
      if (context.mounted) {
        debugPrint('Export failed: $e');

        onToast('Export failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Align(
        alignment: Alignment.center,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Export database'),
          onPressed: () async => await _exportDatabase(context),
        ),
      ),
    );
  }
}