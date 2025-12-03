part of '../../main.dart';

class _DeleteOutdatedTransactions extends StatelessWidget {
  const _DeleteOutdatedTransactions({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12.0),
        ),
        onPressed: onPressed,
        child: const Text('Delete outdated transactions'),
      ),
    );
  }
}
