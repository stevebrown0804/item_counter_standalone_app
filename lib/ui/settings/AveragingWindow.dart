// // /ui/settings/sheets/AveragingWindow.dart

part of '../../main.dart';

class _SummaryStatisticRow extends StatefulWidget {
  const _SummaryStatisticRow({
    super.key,
    required this.onDirtyChanged,
  });

  final void Function(bool) onDirtyChanged;

  @override
  State<_SummaryStatisticRow> createState() => _SummaryStatisticRowState();
}

class _SummaryStatisticRowState extends State<_SummaryStatisticRow> {
  final _db = _Db();
  final TextEditingController _summaryStatisticTextInputBox = TextEditingController();
  final FocusNode _summaryStatisticFocusNode = FocusNode();
  final TextEditingController _endDateTextInputBox = TextEditingController();
  final FocusNode _endDateFocusNode = FocusNode();

  bool _canSubmit = false;
  int? _currentAveragingWindowDays;
  bool _showingDisplayString = false;
  bool _showingEndDateDisplayString = true;
  bool _pinStartDate = false;
  bool _pinEndDate = false;

  void _setCanSubmit(bool v) {
    if (_canSubmit == v) return;
    setState(() => _canSubmit = v);
    widget.onDirtyChanged(_canSubmit);
  }

  void _recomputeCanSubmit() {
    final startHasUserInput =
        !_showingDisplayString && _summaryStatisticTextInputBox.text.trim().isNotEmpty;
    final endHasUserInput =
        !_showingEndDateDisplayString && _endDateTextInputBox.text.trim().isNotEmpty;
    _setCanSubmit(startHasUserInput || endHasUserInput);
  }

  String _displayStringForDays(int days) {
    return '$days days ago';
  }

  void _showCurrentDisplayString() {
    final days = _currentAveragingWindowDays;
    if (days == null) {
      _summaryStatisticTextInputBox.clear();
      _showingDisplayString = false;
      return;
    }

    _summaryStatisticTextInputBox.value = TextEditingValue(
      text: _displayStringForDays(days),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _showingDisplayString = true;
  }

  void _showEndDateDisplayString() {
    _endDateTextInputBox.text = 'Today';
    _showingEndDateDisplayString = true;
  }

  Future<void> _loadCurrentAveragingWindowDays() async {
    try {
      final days = await _db.readAveragingWindowDays();
      if (!mounted) return;

      setState(() {
        _currentAveragingWindowDays = days;
        _showCurrentDisplayString();
        _showEndDateDisplayString();
      });
      _setCanSubmit(false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load averaging window: $e')),
      );
    }
  }

  void _handleFocusChanged() {
    if (_summaryStatisticFocusNode.hasFocus) {
      if (_showingDisplayString) {
        setState(() {
          _summaryStatisticTextInputBox.clear();
          _showingDisplayString = false;
        });
      }
      _recomputeCanSubmit();
      return;
    }

    final raw = _summaryStatisticTextInputBox.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _showCurrentDisplayString();
      });
    }
    _recomputeCanSubmit();
  }

  void _handleEndDateFocusChanged() {
    if (_endDateFocusNode.hasFocus) {
      if (_showingEndDateDisplayString) {
        setState(() {
          _endDateTextInputBox.clear();
          _showingEndDateDisplayString = false;
        });
      }
      _recomputeCanSubmit();
      return;
    }

    final raw = _endDateTextInputBox.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _showEndDateDisplayString();
      });
    }
    _recomputeCanSubmit();
  }

  void discardChanges() {
    FocusScope.of(context).unfocus();
    setState(() {
      _showCurrentDisplayString();
      _showEndDateDisplayString();
    });
    _setCanSubmit(false);
  }

  @override
  void initState() {
    super.initState();
    widget.onDirtyChanged(false);
    _summaryStatisticFocusNode.addListener(_handleFocusChanged);
    _endDateFocusNode.addListener(_handleEndDateFocusChanged);
    _showEndDateDisplayString();
    _loadCurrentAveragingWindowDays();
  }

  @override
  void dispose() {
    _summaryStatisticFocusNode.removeListener(_handleFocusChanged);
    _summaryStatisticFocusNode.dispose();
    _summaryStatisticTextInputBox.dispose();
    _endDateFocusNode.removeListener(_handleEndDateFocusChanged);
    _endDateFocusNode.dispose();
    _endDateTextInputBox.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    // Default range for the picker.  Seems "reasonable" <---sarcasm
    DateTime firstDate = DateTime(2000, 1, 1);
    DateTime lastDate  = DateTime(2100, 12, 31);
    DateTime initialDate = DateTime.now();

    try {
      // Oldest transaction date in the currently-active time zone, truncated to Y-M-D.
      final oldestLocal = await _db.readOldestTransactionLocalDate();
      debugPrint('readOldestTransactionLocalDate -> $oldestLocal');

      final today = DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
      );

      if (oldestLocal == null) {
        // No transactions exist -> only allow selecting today
        firstDate = today;
        lastDate  = today;
        initialDate = today;
      } else {
        // At least one transaction exists-> do "this"  <---those are air quotes, btw
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
      //Error -> keep the default bounds
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
        _showingDisplayString = false;
      });
      _recomputeCanSubmit();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to compute window days: $e')),
      );
    }
  }

  Future<void> _pickEndDate() async {
    // Default range for the picker.  Seems "reasonable" <---sarcasm
    DateTime firstDate = DateTime(2000, 1, 1);
    DateTime lastDate  = DateTime(2100, 12, 31);
    DateTime initialDate = DateTime.now();

    try {
      // Oldest transaction date in the currently-active time zone, truncated to Y-M-D.
      final oldestLocal = await _db.readOldestTransactionLocalDate();
      debugPrint('readOldestTransactionLocalDate -> $oldestLocal');

      final today = DateTime(
        initialDate.year,
        initialDate.month,
        initialDate.day,
      );

      if (oldestLocal == null) {
        // No transactions exist -> only allow selecting today
        firstDate = today;
        lastDate  = today;
        initialDate = today;
      } else {
        // At least one transaction exists-> do "this"  <---those are air quotes, btw
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
      //Error -> keep the default bounds
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Choose an end date for the averaging window:',
    );
    if (picked == null) return;

    if (!mounted) return;
    setState(() {
      _endDateTextInputBox.text = '${picked.month}/${picked.day}/${picked.year}';
      _showingEndDateDisplayString = false;
    });
    _recomputeCanSubmit();
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
      _currentAveragingWindowDays = days;
      _showCurrentDisplayString();
      _showEndDateDisplayString();
    });
    _setCanSubmit(false);
  }

  @override
  Widget build(BuildContext context) {
    final inputStyle = Theme.of(context).textTheme.bodyMedium;
    final textScaler = MediaQuery.textScalerOf(context);

    double measureTextWidth(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: style,
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();

      return painter.width;
    }

    String widestDigit(TextStyle? style) {
      var widest = '0';
      var widestWidth = 0.0;

      for (final digit in const ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) {
        final width = measureTextWidth(digit, style);
        if (width > widestWidth) {
          widestWidth = width;
          widest = digit;
        }
      }

      return widest;
    }

    final displayText = _displayStringForDays(_currentAveragingWindowDays ?? 99999);
    final todayDisplayText = 'Today';

    const horizontalContentPadding = 12.0;
    const borderWidthPerSide = 1.0;
    const extraInteriorSlack = 20.0;

    final textWidthForDisplayString = measureTextWidth(displayText, inputStyle);
    final startTextFieldWidth =
        textWidthForDisplayString +
            (horizontalContentPadding * 2) +
            (borderWidthPerSide * 2) +
            extraInteriorSlack;

    final wd = widestDigit(inputStyle);
    final widestPossibleDateString = '$wd$wd/$wd$wd/$wd$wd$wd$wd';

    final todayWidth = measureTextWidth(todayDisplayText, inputStyle);
    final widestPossibleDateWidth = measureTextWidth(widestPossibleDateString, inputStyle);
    final endTextWidth = todayWidth > widestPossibleDateWidth
        ? todayWidth
        : widestPossibleDateWidth;

    final endTextFieldWidth =
        endTextWidth +
            (horizontalContentPadding * 2) +
            (borderWidthPerSide * 2) +
            extraInteriorSlack;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Averaging window',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: startTextFieldWidth,
                  child: TextField(
                    controller: _summaryStatisticTextInputBox,
                    focusNode: _summaryStatisticFocusNode,
                    keyboardType: TextInputType.number,
                    readOnly: _showingDisplayString,
                    style: _showingDisplayString
                        ? inputStyle?.copyWith(color: Theme.of(context).hintColor)
                        : inputStyle,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onTap: () {
                      if (_showingDisplayString) {
                        setState(() {
                          _summaryStatisticTextInputBox.clear();
                          _showingDisplayString = false;
                        });
                        _recomputeCanSubmit();
                      }
                    },
                    onChanged: (_) => _recomputeCanSubmit(),
                    decoration: const InputDecoration(
                      hintText: '#',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('to'),
                const SizedBox(width: 8),
                SizedBox(
                  width: endTextFieldWidth,
                  child: TextField(
                    controller: _endDateTextInputBox,
                    focusNode: _endDateFocusNode,
                    style: _showingEndDateDisplayString
                        ? inputStyle?.copyWith(color: Theme.of(context).hintColor)
                        : inputStyle,
                    readOnly: _showingEndDateDisplayString,
                    onTap: () {
                      if (_showingEndDateDisplayString) {
                        setState(() {
                          _endDateTextInputBox.clear();
                          _showingEndDateDisplayString = false;
                        });
                        _recomputeCanSubmit();
                      }
                    },
                    onChanged: (_) => _recomputeCanSubmit(),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 10),
                  label: const Text('Pick start date'),
                  onPressed: _pickDate,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 10),
                  label: const Text('Pick end date'),
                  onPressed: _pickEndDate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('Pin start date'),
                const SizedBox(width: 8),
                Switch(
                  value: _pinStartDate,
                  onChanged: (value) {
                    setState(() {
                      _pinStartDate = value;
                    });
                  },
                ),
                const SizedBox(width: 24),
                const Text('...and end date'),
                const SizedBox(width: 8),
                Switch(
                  value: _pinEndDate,
                  onChanged: (value) {
                    setState(() {
                      _pinEndDate = value;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.center,
            child: FilledButton(
              onPressed: _canSubmit ? _submit : null,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}