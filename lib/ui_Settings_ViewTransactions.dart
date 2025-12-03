part of 'main.dart';

class _ViewTransactionsRow extends StatelessWidget {
  const _ViewTransactionsRow({
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
          icon: const Icon(Icons.list_alt),
          label: const Text('View transactions'),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
