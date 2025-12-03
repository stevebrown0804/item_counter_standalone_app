part of '../../main.dart';

class _ExportDatabaseRow extends StatelessWidget {
  const _ExportDatabaseRow({
    required this.onPressed,
    super.key,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Align(
        alignment: Alignment.center,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Export database'),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
