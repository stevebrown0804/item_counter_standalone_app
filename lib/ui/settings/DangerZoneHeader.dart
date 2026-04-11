// /ui/settings/sheets/DangerZoneHeader.dart

part of '../../main.dart';

class _DangerZoneHeader extends StatelessWidget {
  const _DangerZoneHeader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Text(
          'Danger Zone',
          textAlign: TextAlign.left,
          style: TextStyle(
            color: Colors.red,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

}
