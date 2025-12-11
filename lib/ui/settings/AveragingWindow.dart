part of '../../main.dart';

// <editor-fold desc="(Eventually:) Summary statistic row of the settings sheet">

class _SummaryStatisticRow extends StatefulWidget {
  const _SummaryStatisticRow();
  @override
  State<_SummaryStatisticRow> createState() => _SummaryStatisticRowState();
}

class _SummaryStatisticRowState extends State<_SummaryStatisticRow> {
  final _db = _Db();
  final TextEditingController _summaryStatisticTextInputBox = TextEditingController();
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _summaryStatisticTextInputBox.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    // Default range for the picker.
    DateTime firstDate = DateTime(2000, 1, 1);
    DateTime lastDate  = DateTime(2100, 12, 31);
    DateTime initialDate = DateTime.now();

    try {
      // Oldest transaction date in the *active* time zone, truncated to Y-M-D.
      final oldestLocal = await _db.readOldestTransactionLocalDate();
      debugPrint('readOldestTransactionLocalDate -> $oldestLocal');

      if (oldestLocal != null) {
        // Strip time-of-day; showDatePicker only cares about Y/M/D.
        firstDate = DateTime(
          oldestLocal.year,
          oldestLocal.month,
          oldestLocal.day,
        );
        if (initialDate.isBefore(firstDate)) {
          initialDate = firstDate;
        }
      }
    } catch (e, st) {
      debugPrint('ERROR reading oldest transaction date: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read oldest transaction date: $e'),
          ),
        );
      }
      // On error we keep the default 2000-01-01 bound.
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Choose a start date for the averaging window:',
    );
    if (picked == null) return;

    try {
      String two(int n) => n.toString().padLeft(2, '0');
      final localDate =
          '${picked.year}-${two(picked.month)}-${two(picked.day)}';

      final days =
      await _db.computeAveragingWindowDaysFromPickedLocalDate(localDate);

      if (!mounted) return;
      setState(() {
        _summaryStatisticTextInputBox.text = days.toString();
        _canSubmit = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to compute window days: $e')),
      );
    }
  }

  Future<void> _submit() async {
    final raw = _summaryStatisticTextInputBox.text.trim();
    final days = int.tryParse(raw);
    if (days == null || days <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a positive number of days.')),
      );
      return;
    }

    await _db.setAveragingWindowDays(days);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Averaging window set to: $days days')),
    );

    FocusScope.of(context).unfocus();
    setState(() {
      _summaryStatisticTextInputBox.clear();
      _canSubmit = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Averaging window:',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _summaryStatisticTextInputBox,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (v) =>
                      setState(() => _canSubmit = v.trim().isNotEmpty),
                  decoration: const InputDecoration(
                    hintText: '##',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('days'),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _canSubmit ? _submit : null,
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.date_range, size: 10),
              label: const Text('Pick start date'),
              onPressed: _pickDate,
            ),
          ),
        ],
      ),
    );
  }
}

// </editor-fold>