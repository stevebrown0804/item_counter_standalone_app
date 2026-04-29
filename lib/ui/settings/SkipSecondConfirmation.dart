// /ui/settings/sheets/SkipSecondConfirmation.dart

part of '../../main.dart';

class _SkipSecondConfirmationSetting extends StatefulWidget {
  const _SkipSecondConfirmationSetting({
    super.key,
    required this.onDirtyChanged,
    required this.onSaved,
  });

  final void Function(bool) onDirtyChanged;
  final VoidCallback onSaved;

  @override
  State<_SkipSecondConfirmationSetting> createState() =>
      _SkipSecondConfirmationSettingState();
}

class _SkipSecondConfirmationSettingState
    extends State<_SkipSecondConfirmationSetting> {
  final _db = _Db();
  bool? _current;
  bool _saving = false;

  void discardChanges() {
    widget.onDirtyChanged(false);
  }

  @override
  void initState() {
    super.initState();
    widget.onDirtyChanged(false);
    _load();
  }

  Future<void> _load() async {
    final v = await _db.readSkipDeleteSecondConfirm();
    if (!mounted) return;
    setState(() {
      _current = v;
    });
    widget.onDirtyChanged(false);
  }

  Future<void> _save(bool value) async {
    if (_saving) return;

    final previous = _current;

    setState(() {
      _current = value;
      _saving = true;
    });

    widget.onDirtyChanged(false);

    try {
      await _db.setSkipDeleteSecondConfirm(value);
      if (!mounted) return;
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preference saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _current = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save preference: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;

    if (current == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: SizedBox(height: 56),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Skip second confirmation when deleting transactions',
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: current,
            onChanged: _saving ? null : (value) async => await _save(value),
          ),
        ],
      ),
    );
  }
}