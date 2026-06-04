// /ui/settings/sheets/ViewTransactionButton.dart

part of '../../main.dart';

class _ViewTransactionsRow extends StatelessWidget {
  const _ViewTransactionsRow({
    required this.db,
    required this.onBackPressed,
  });

  final _Db db;
  final Future<void> Function() onBackPressed;

  Future<void> _openTransactionViewer(BuildContext context) async {
    final main = _MainScreenState._lastMounted;
    if (main == null) {
      return;
    }

    await _doTransactionViewerSheet(
      context: context,
      db: main._db,
      store: main._store,
      onBackPressed: onBackPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Align(
        alignment: Alignment.center,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.list_alt),
          label: const Text('View transactions'),
          onPressed: () async => await _openTransactionViewer(context),
        ),
      ),
    );
  }
}

