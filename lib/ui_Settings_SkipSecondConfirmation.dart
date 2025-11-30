part of 'main.dart';

class _SkipSecondConfirmSetting extends StatefulWidget {
  const _SkipSecondConfirmSetting();

  @override
  State<_SkipSecondConfirmSetting> createState() =>
      _SkipSecondConfirmSettingState();
}

class _SkipSecondConfirmSettingState
    extends State<_SkipSecondConfirmSetting> {
  final _db = _Db();
  bool? _initial;
  bool _current = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await _db.readSkipDeleteSecondConfirm();
    if (!mounted) return;
    setState(() {
      _initial = v;
      _current = v;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _db.setSkipDeleteSecondConfirm(_current);
      if (!mounted) return;
      setState(() => _initial = _current);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preference saved.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initial == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: SizedBox(height: 56),
      );
    }

    final changed = _initial != _current;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          CheckboxListTile(
            value: _current,
            onChanged: (v) => setState(() => _current = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
                'Skip second confirmation when deleting transactions'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: (!changed || _saving) ? null : _save,
              child: _saving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Save'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
