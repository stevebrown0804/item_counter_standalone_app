part of '../../main.dart';

class _LogPillsSheetResult {
  final Map<int, int> quantities;
  final String summary;

  const _LogPillsSheetResult({
    required this.quantities,
    required this.summary,
  });
}

class _LogPillsSheet extends StatefulWidget {
  final List<dynamic> pills;

  const _LogPillsSheet({
    required this.pills,
  });

  @override
  State<_LogPillsSheet> createState() => _LogPillsSheetState();
}

class _LogPillsSheetState extends State<_LogPillsSheet> {
  late final List<int> _qty;

  @override
  void initState() {
    super.initState();
    _qty = List<int>.filled(widget.pills.length, 0);
  }

  @override
  Widget build(BuildContext context) {
    final pills = widget.pills;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Log pills',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: pills.length,
                separatorBuilder: (_, __) =>
                const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final p = pills[i];
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          (p.name as String),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon:
                        const Icon(Icons.keyboard_arrow_down),
                        onPressed: () {
                          setState(() {
                            if (_qty[i] > 0) _qty[i]--;
                          });
                        },
                      ),
                      SizedBox(
                        width: 48,
                        child: TextField(
                          key: ValueKey('qty_$i'),
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding:
                            EdgeInsets.symmetric(vertical: 6),
                            border: OutlineInputBorder(),
                          ),
                          controller: TextEditingController(
                              text: _qty[i].toString()),
                          onChanged: (s) {
                            final v = int.tryParse(s) ?? 0;
                            setState(() {
                              _qty[i] = v.clamp(0, 1000000);
                            });
                          },
                        ),
                      ),
                      IconButton(
                        icon:
                        const Icon(Icons.keyboard_arrow_up),
                        onPressed: () {
                          setState(() {
                            _qty[i] = _qty[i] + 1;
                          });
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            // --- Timestamp + pickers (flush right, buttons centered under field) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Timestamp:'),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 220, // width of the text box; buttons center under this  //TMP, I think
                      child: TextField(
                        enabled: false, // will become editable later when we wire picking
                        controller: TextEditingController(text: 'Now'),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 8,
                          ),
                        ),
                      ),
                    ),
                    //const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {
                            // Time picker logic to be added later
                          },
                          child: const Text('Pick time'),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () {
                            // Date picker logic to be added later
                          },
                          child: const Text('Pick date'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // --- Existing Cancel / Submit row ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: () {
                    final map = <int, int>{};
                    final parts = <String>[];
                    for (var i = 0; i < pills.length; i++) {
                      final q = _qty[i];
                      if (q > 0) {
                        final p = pills[i];
                        final id = p.id as int;
                        final name = p.name as String;
                        map[id] = q;
                        parts.add('$name x $q');
                      }
                    }
                    if (map.isEmpty) {
                      Navigator.of(context).pop();
                      return;
                    }

                    final summary = 'Added: ${parts.join(', ')}';

                    Navigator.of(context).pop(
                      _LogPillsSheetResult(
                        quantities: map,
                        summary: summary,
                      ),
                    );
                  },
                  child: const Text('Submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
