part of '../../main.dart';

class _LogPillsSheetResult {
  final Map<int, int> quantities;
  final String summary;
  /// Local wall-clock timestamp in the active time zone ("YYYY-MM-DD HH:MM:SS"),
  /// or null if the user left it as "Now".
  final String? localTimestampOverride;

  const _LogPillsSheetResult({
    required this.quantities,
    required this.summary,
    required this.localTimestampOverride,
  });
}

class _LogPillsSheet extends StatefulWidget {
  final List<dynamic> pills;
  /// IANA time zone name for the active app TZ, e.g. "America/Denver".
  final String activeTzName;

  const _LogPillsSheet({
    required this.pills,
    required this.activeTzName,
  });

  @override
  State<_LogPillsSheet> createState() => _LogPillsSheetState();
}

class _LogPillsSheetState extends State<_LogPillsSheet> {
  late final List<int> _qty;
  late final TextEditingController _timestampCtrl;

  tz.Location _activeLocation() {
    try {
      return tz.getLocation(widget.activeTzName);
    } catch (_) {
      // Fallback if something is misconfigured.
      return tz.getLocation('Etc/UTC');
    }
  }

  @override
  void initState() {
    super.initState();
    _qty = List<int>.filled(widget.pills.length, 0);
    _timestampCtrl = TextEditingController(text: 'Now');
  }

  @override
  void dispose() {
    _timestampCtrl.dispose();
    super.dispose();
  }

  DateTime? _parseTimestamp(String text) {
    if (text == 'Now') return null;

    final parts = text.split(' ');
    if (parts.length != 2) return null;

    final dateParts = parts[0].split('-');
    final timeParts = parts[1].split(':');
    if (dateParts.length != 3 || timeParts.length != 2) return null;

    final year = int.tryParse(dateParts[0]);
    final month = int.tryParse(dateParts[1]);
    final day = int.tryParse(dateParts[2]);
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);

    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null) {
      return null;
    }

    return DateTime(year, month, day, hour, minute);
  }

  String _formatTimestamp(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final y = dt.year.toString().padLeft(4, '0');
    final m = two(dt.month);
    final d = two(dt.day);
    final h = two(dt.hour);
    final min = two(dt.minute);
    return '$y-$m-$d $h:$min';
  }

  Future<void> _pickDate() async {
    final loc = _activeLocation();
    final current = _parseTimestamp(_timestampCtrl.text);

    // "Now" in the active app time zone, not the device zone.
    final nowLocal = tz.TZDateTime.now(loc);
    final initialDate = current != null
        ? DateTime(current.year, current.month, current.day)
        : DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Choose date of transaction',
    );
    if (picked == null) return;

    final base = _parseTimestamp(_timestampCtrl.text);
    late DateTime updated;

    if (base == null) {
      // Was "Now" (or unparsable): use picked date at midnight.
      updated = DateTime(picked.year, picked.month, picked.day, 0, 0);
    } else {
      // Replace date, keep time.
      updated = DateTime(
        picked.year,
        picked.month,
        picked.day,
        base.hour,
        base.minute,
      );
    }

    setState(() {
      _timestampCtrl.text = _formatTimestamp(updated);
    });
  }

  Future<void> _pickTime() async {
    final loc = _activeLocation();
    final current = _parseTimestamp(_timestampCtrl.text);

    final nowLocal = tz.TZDateTime.now(loc);
    final initialTime = current != null
        ? TimeOfDay(hour: current.hour, minute: current.minute)
        : TimeOfDay(hour: nowLocal.hour, minute: nowLocal.minute);

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Choose time of transaction',
    );
    if (picked == null) return;

    DateTime updated;
    if (current == null) {
      // Was "Now" (or unparsable): use "today" in the active TZ with chosen time.
      final todayLocal = tz.TZDateTime.now(loc);
      updated = DateTime(
        todayLocal.year,
        todayLocal.month,
        todayLocal.day,
        picked.hour,
        picked.minute,
      );
    } else {
      // Keep date, change time.
      updated = DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      );
    }

    setState(() {
      _timestampCtrl.text = _formatTimestamp(updated);
    });
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
                        controller: _timestampCtrl,
                        enabled: _timestampCtrl.text != 'Now',
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
                          onPressed: _pickDate,
                          child: const Text('Pick date'),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: _pickTime,
                          child: const Text('Pick time'),
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

                    // Build local override timestamp if the user changed it from "Now".
                    final tsText = _timestampCtrl.text.trim();
                    String? localOverride;
                    if (tsText != 'Now') {
                      final parsed = _parseTimestamp(tsText);
                      if (parsed == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invalid timestamp format. Use "YYYY-MM-DD HH:MM".'),
                          ),
                        );
                        return;
                      }
                      String two(int n) => n.toString().padLeft(2, '0');
                      final y = parsed.year.toString().padLeft(4, '0');
                      final m = two(parsed.month);
                      final d = two(parsed.day);
                      final h = two(parsed.hour);
                      final min = two(parsed.minute);
                      // Backend expects "YYYY-MM-DD HH:MM:SS".
                      localOverride = '$y-$m-$d $h:$min:00';
                    }

                    final summary = 'Added: ${parts.join(', ')}';

                    Navigator.of(context).pop(
                      _LogPillsSheetResult(
                        quantities: map,
                        summary: summary,
                        localTimestampOverride: localOverride,
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
