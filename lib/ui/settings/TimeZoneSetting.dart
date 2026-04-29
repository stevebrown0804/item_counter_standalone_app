// /ui/settings/sheets/timeZoneSetting.dart

part of '../../main.dart';

class _TzRow extends StatefulWidget {
  const _TzRow({
    super.key,
    required this.onDirtyChanged,
    required this.onSaved,
  });

  final void Function(bool) onDirtyChanged;
  final VoidCallback onSaved;

  @override
  State<_TzRow> createState() => _TzRowState();
}

class _TzRowState extends State<_TzRow> {
  final _db = _Db();
  List<String> _options = const [];
  String? _currentDisplayString;
  bool _loading = true;
  bool _saving = false;

  void discardChanges() {
    widget.onDirtyChanged(false);
  }

  @override
  void initState() {
    super.initState();
    widget.onDirtyChanged(false);
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final opts = await _db.listTzAliasStrings();
      final activeDisplayString = await _db.readActiveTzAliasString();

      if (!mounted) return;
      setState(() {
        _options = opts;
        _currentDisplayString = opts.contains(activeDisplayString) ? activeDisplayString : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load time zones: $e')),
      );
    }
  }

  Future<void> _saveSelectedTimeZone(String selectedDisplayString) async {
    if (_saving) {
      return;
    }

    if (selectedDisplayString == _currentDisplayString) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final aliasToSave = await _db.interpretTzAliasInput(selectedDisplayString);
      await _db.setActiveTzByAlias(aliasToSave);

      final savedDisplayString = await _db.readActiveTzAliasString();

      final main = _MainScreenState._lastMounted;
      if (main != null && main.mounted) {
        await main._store.refreshFromDatabase();
        await main._loadActiveTzDisplay();
        if (main.mounted) {
          main.setState(() {});
        }
      }

      if (!mounted) return;
      setState(() {
        _currentDisplayString = savedDisplayString;
      });
      widget.onDirtyChanged(false);
      widget.onSaved();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Time zone selected: $savedDisplayString')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save time zone: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ListTile(
        title: Text('Time Zone'),
        subtitle: Text('Loading…'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text(
            'Time Zone:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _currentDisplayString,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: _options.map((option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              onChanged: _saving
                  ? null
                  : (value) async {
                if (value == null) {
                  return;
                }
                await _saveSelectedTimeZone(value);
              },
            ),
          ),
          if (_saving) ...[
            const SizedBox(width: 12),
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }
}