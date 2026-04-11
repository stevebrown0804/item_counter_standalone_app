// /ui/settings/sheets/EditCountableItems.dart

part of '../../../main.dart';

Future<void> doEditCountableItemsSheet({
  required BuildContext context,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit countable items'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
        body: const SizedBox.expand(),
      );
    },
  );
}

class _EditCountableItemsRow extends StatelessWidget {
  const _EditCountableItemsRow({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Align(
        alignment: Alignment.center,
        child: OutlinedButton(
          onPressed: onPressed,
          child: const Text('Edit countable items'),
        ),
      ),
    );
  }
}