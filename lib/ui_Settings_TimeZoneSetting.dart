part of 'main.dart';

class _TzRow extends StatefulWidget {
  const _TzRow();
  @override
  State<_TzRow> createState() => _TzRowState();
}

class _TzRowState extends State<_TzRow> {
  final _db = _Db();
  final _ctrl = TextEditingController();
  String _query = '';
  List<String> _options = const [];
  bool _loading = true;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final opts = await _db.listTzAliasStrings();
      if (!mounted) return;
      setState(() {
        _options = opts;
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

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) return;

    try {
      final aliasToSave = await _db.interpretTzAliasInput(raw);
      await _db.setActiveTzByAlias(aliasToSave);

      final displayString = await _db.readActiveTzAliasString();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Time zone: ($displayString) saved')),
      );

      FocusScope.of(context).unfocus();

      _ctrl.clear();
      setState(() => _canSubmit = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save time zone: $e')),
      );
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
            child: Autocomplete<String>(
              optionsBuilder: (TextEditingValue tev) {
                final q = tev.text.trim().toLowerCase();
                if (q.isEmpty) return _options;
                return _options.where((s) => s.toLowerCase().contains(q));
              },
              onSelected: (value) {
                _ctrl.text = value;
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                controller.text = _ctrl.text;
                controller.addListener(() {
                  _ctrl.text = controller.text;
                  final next = controller.text.trim();
                  final changed = next != _query;
                  final canSubmitNow = next.isNotEmpty;
                  if (changed || canSubmitNow != _canSubmit) {
                    setState(() {
                      _query = next;
                      _canSubmit = canSubmitNow;
                    });
                  }
                });

                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    hintText: 'e.g., MT/MST/MDT or MT',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                final q = _query.trim().toLowerCase();
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: options.map((opt) {
                          final aliases = opt.split('/');
                          final match = q.isNotEmpty &&
                              aliases.any((a) => a.toLowerCase() == q);

                          final title = Text.rich(
                            TextSpan(
                              children: [
                                for (int i = 0; i < aliases.length; i++) ...[
                                  TextSpan(
                                    text: aliases[i],
                                    style: TextStyle(
                                      fontWeight: (q.isNotEmpty &&
                                          aliases[i].toLowerCase() == q)
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  if (i < aliases.length - 1)
                                    const TextSpan(text: '/'),
                                ]
                              ],
                            ),
                          );

                          return ListTile(
                            dense: true,
                            selected: match,
                            title: title,
                            onTap: () => onSelected(opt),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _canSubmit ? _submit : null,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}