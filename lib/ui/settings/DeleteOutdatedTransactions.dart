// /ui/settings/sheets/DeleteOutdatedTransactions.dart

part of '../../main.dart';

class _DeleteOutdatedTransactions extends StatelessWidget {
  const _DeleteOutdatedTransactions({
    required this.onResolvePendingAveragingWindow,
    required this.onSkipSecondConfirmationSaved,
    required this.onInteractionComplete,
  });

  final Future<bool> Function() onResolvePendingAveragingWindow;
  final VoidCallback onSkipSecondConfirmationSaved;
  final Future<void> Function(String) onInteractionComplete;

  Future<void> _beginDeleteOldTxProcess(BuildContext context) async {
    final resolved = await onResolvePendingAveragingWindow();
    if (!resolved) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    await _showDeleteOldTxDialog(context);
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
      await onInteractionComplete('Deleted $deleted transactions older than $days days.');
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
                                onSkipSecondConfirmationSaved();
                              }

                              final deleted =
                              await db.deleteOldTransactionsWithPolicy(days);
                              if (!context.mounted) return;
                              Navigator.of(ctx).pop();
                              await onInteractionComplete('Deleted $deleted transactions older than $days days.');
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 12.0,
            ),
          ),
          onPressed: () => unawaited(_beginDeleteOldTxProcess(context)),
          child: const Text('Delete outdated transactions'),
        ),
      ),
    );
  }
}