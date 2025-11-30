part of 'main.dart';

//Btw this is "window" as in "averaging window," ie. the number of days over which the average is taken

// <editor-fold desc="The UI">

class _WindowRow extends StatefulWidget {
  const _WindowRow();
  @override
  State<_WindowRow> createState() => _WindowRowState();
}

class _WindowRowState extends State<_WindowRow> {
  final _db = _Db();
  final TextEditingController _ctrl = TextEditingController();
  bool _canSubmit = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Choose the initial date of transaction',
    );
    if (picked == null) return;

    try {
      String two(int n) => n.toString().padLeft(2, '0');
      // Local calendar date in "YYYY-MM-DD" for the backend to interpret
      // in the active time zone. Backend decides how many days the window is.
      final localDate =
          '${picked.year}-${two(picked.month)}-${two(picked.day)}';

      final days =
      await _db.computeAveragingWindowDaysFromPickedLocalDate(localDate);

      if (!mounted) return;
      setState(() {
        _ctrl.text = days.toString();
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
    final raw = _ctrl.text.trim();
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
      _ctrl.clear();
      _canSubmit = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Averaging window, in days',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    TextField(
                      controller: _ctrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      onChanged: (v) =>
                          setState(() => _canSubmit = v.trim().isNotEmpty),
                      decoration: const InputDecoration(
                        hintText: 'e.g., 30',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range, size: 18),
                      label: const Text('Pick start date'),
                      onPressed: _pickDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _canSubmit ? _submit : null,
                child: const Text('Submit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// </editor-fold>