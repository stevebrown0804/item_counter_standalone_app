// /ui/settings/ReturnHomeAfterSettingsInteraction.dart

part of '../../main.dart';

class _ReturnHomeAfterSettingsInteractionRow extends StatefulWidget {
  const _ReturnHomeAfterSettingsInteractionRow({
    required this.db,
    required this.onChanged,
    required this.onSaved,
    required this.onToast,
  });

  final _Db db;
  final void Function(bool) onChanged;
  final VoidCallback onSaved;
  final void Function(String) onToast;

  @override
  State<_ReturnHomeAfterSettingsInteractionRow> createState() =>
      _ReturnHomeAfterSettingsInteractionRowState();
}

class _ReturnHomeAfterSettingsInteractionRowState
    extends State<_ReturnHomeAfterSettingsInteractionRow> {
  _Db get _db => widget.db;

  bool _value = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final value = await _db.readReturnHomeAfterSettingsInteraction();

      if (!mounted) {
        return;
      }

      setState(() {
        _value = value;
        _loading = false;
      });

      widget.onChanged(value);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      widget.onToast('Failed to load return-home setting: $e');
    }
  }

  Future<void> _save(bool value) async {
    if (_saving) {
      return;
    }

    final previousValue = _value;

    setState(() {
      _value = value;
      _saving = true;
    });
    widget.onChanged(value);

    try {
      await _db.setReturnHomeAfterSettingsInteraction(value);

      if (!mounted) {
        return;
      }

      widget.onSaved();
      widget.onToast(
        value
            ? 'Settings interactions will return to the home screen.'
            : 'Settings interactions will remain on the Settings screen.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _value = previousValue;
      });
      widget.onChanged(previousValue);

      widget.onToast('Failed to save return-home setting: $e');
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ListTile(
        title: Text('Settings sheet interactions immediately return you to the home screen'),
        subtitle: Text('Loading…'),
      );
    }

    return SwitchListTile(
      title: Text(
        'Settings sheet interactions immediately return you to the home screen',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      value: _value,
      onChanged: _saving ? null : (value) async => await _save(value),
    );
  }
}

