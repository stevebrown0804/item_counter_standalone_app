// /ui/settings/ImportDatabase.dart

part of '../../main.dart';

class _ImportDatabaseRow extends StatelessWidget {
  const _ImportDatabaseRow({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Align(
        alignment: Alignment.center,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.upload),
          label: const Text('Import database'),
          onPressed: onPressed,
        ),
      ),
    );
  }
}