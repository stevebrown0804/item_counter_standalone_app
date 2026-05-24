// /ui/settings/EditTimeZones.dart

part of '../../main.dart';

class _EditTimeZonesRow extends StatelessWidget {
  const _EditTimeZonesRow({
    required this.onInteractionComplete,
  });

  final Future<void> Function(String) onInteractionComplete;

  Future<void> _openEditTimeZonesSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return const _EditTimeZonesSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Align(
        alignment: Alignment.center,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.public),
          label: const Text('Edit time zones'),
          onPressed: () async => await _openEditTimeZonesSheet(context),
        ),
      ),
    );
  }
}

class _EditTimeZonesSheet extends StatelessWidget {
  const _EditTimeZonesSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: _bottomSheetBottomPadding(context, _standardBottomSheetBottomPadding),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Edit time zones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16),
            Text('Time zone editor forthcoming.'),
          ],
        ),
      ),
    );
  }
}