// // /ui/settings/sheets/AveragingWindow.dart

part of '../../main.dart';

class _MaskedDateTextInputFormatter extends TextInputFormatter {
  static const String _template = '__/__/____';
  static const List<int> _monthSlots = <int>[0, 1];
  static const List<int> _daySlots = <int>[3, 4];
  static const List<int> _yearSlots = <int>[6, 7, 8, 9];

  bool _isDigit(String ch) {
    return RegExp(r'^[0-9]$').hasMatch(ch);
  }

  List<int> _regionSlotsForOffset(int offset) {
    if (offset <= 2) {
      return _monthSlots;
    }
    if (offset <= 5) {
      return _daySlots;
    }
    return _yearSlots;
  }

  String _digitsFromRegion(String text, List<int> regionSlots) {
    final chars = <String>[];
    for (final slot in regionSlots) {
      if (slot < text.length && _isDigit(text[slot])) {
        chars.add(text[slot]);
      }
    }
    return chars.join();
  }

  String _replaceRegionDigits(
      String originalText,
      List<int> regionSlots,
      String regionDigits,
      ) {
    final chars = _template.split('');

    for (var i = 0; i < chars.length && i < originalText.length; i++) {
      chars[i] = originalText[i];
    }

    for (final slot in regionSlots) {
      chars[slot] = '_';
    }

    for (var i = 0; i < regionDigits.length && i < regionSlots.length; i++) {
      chars[regionSlots[i]] = regionDigits[i];
    }

    return chars.join();
  }

  int _countDigitsBeforeOffsetInRegion(String text, int offset, List<int> regionSlots) {
    var count = 0;
    for (final slot in regionSlots) {
      if (slot >= offset) {
        break;
      }
      if (slot < text.length && _isDigit(text[slot])) {
        count++;
      }
    }
    return count;
  }

  int _previousDigitIndexInRegion(String text, int offset, List<int> regionSlots) {
    for (var i = regionSlots.length - 1; i >= 0; i--) {
      final slot = regionSlots[i];
      if (slot < offset && slot < text.length && _isDigit(text[slot])) {
        return i;
      }
    }
    return -1;
  }

  int _nextDigitIndexInRegion(String text, int offset, List<int> regionSlots) {
    for (var i = 0; i < regionSlots.length; i++) {
      final slot = regionSlots[i];
      if (slot >= offset && slot < text.length && _isDigit(text[slot])) {
        return i;
      }
    }
    return -1;
  }

  int _caretOffsetForRegionDigitIndex(List<int> regionSlots, int digitIndex) {
    if (digitIndex <= 0) {
      return regionSlots.first;
    }
    if (digitIndex >= regionSlots.length) {
      return regionSlots.last + 1;
    }
    return regionSlots[digitIndex];
  }

  String _insertedDigitFromEdit(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      List<int> regionSlots,
      ) {
    for (final slot in regionSlots) {
      final oldChar = slot < oldValue.text.length ? oldValue.text[slot] : '';
      final newChar = slot < newValue.text.length ? newValue.text[slot] : '';
      if (oldChar != newChar && _isDigit(newChar)) {
        return newChar;
      }
    }

    final match = RegExp(r'[0-9]').allMatches(newValue.text);
    if (match.isNotEmpty) {
      return match.last.group(0)!;
    }

    return '';
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final oldText = oldValue.text.isEmpty ? _template : oldValue.text;
    final oldSelection = oldValue.selection;
    final newSelection = newValue.selection;

    final regionSlots = _regionSlotsForOffset(oldSelection.baseOffset);
    var regionDigits = _digitsFromRegion(oldText, regionSlots);
    var caretDigitIndex = _countDigitsBeforeOffsetInRegion(
      oldText,
      oldSelection.baseOffset,
      regionSlots,
    );

    if (newValue.text.length < oldValue.text.length) {
      if (oldSelection.isCollapsed) {
        final deletionLooksLikeBackspace = newSelection.baseOffset < oldSelection.baseOffset;

        if (deletionLooksLikeBackspace) {
          final deleteDigitIndex = _previousDigitIndexInRegion(
            oldText,
            oldSelection.baseOffset,
            regionSlots,
          );
          if (deleteDigitIndex >= 0 && deleteDigitIndex < regionDigits.length) {
            regionDigits = regionDigits.substring(0, deleteDigitIndex) +
                regionDigits.substring(deleteDigitIndex + 1);
            caretDigitIndex = deleteDigitIndex;
          }
        } else {
          final deleteDigitIndex = _nextDigitIndexInRegion(
            oldText,
            oldSelection.baseOffset,
            regionSlots,
          );
          if (deleteDigitIndex >= 0 && deleteDigitIndex < regionDigits.length) {
            regionDigits = regionDigits.substring(0, deleteDigitIndex) +
                regionDigits.substring(deleteDigitIndex + 1);
            caretDigitIndex = _countDigitsBeforeOffsetInRegion(
              oldText,
              oldSelection.baseOffset,
              regionSlots,
            );
          }
        }
      } else {
        final selectionStart = oldSelection.start < oldSelection.end
            ? oldSelection.start
            : oldSelection.end;
        final selectionEnd = oldSelection.start > oldSelection.end
            ? oldSelection.start
            : oldSelection.end;

        final startDigitIndex = _countDigitsBeforeOffsetInRegion(
          oldText,
          selectionStart,
          regionSlots,
        );
        final endDigitIndex = _countDigitsBeforeOffsetInRegion(
          oldText,
          selectionEnd,
          regionSlots,
        );

        if (startDigitIndex < endDigitIndex) {
          regionDigits =
              regionDigits.substring(0, startDigitIndex) + regionDigits.substring(endDigitIndex);
        }
        caretDigitIndex = startDigitIndex;
      }

      final masked = _replaceRegionDigits(oldText, regionSlots, regionDigits);
      final caretOffset = _caretOffsetForRegionDigitIndex(regionSlots, caretDigitIndex);

      return TextEditingValue(
        text: masked,
        selection: TextSelection.collapsed(offset: caretOffset),
      );
    }

    final insertedDigit = _insertedDigitFromEdit(oldValue, newValue, regionSlots);
    if (insertedDigit.isEmpty) {
      return oldValue;
    }

    if (!oldSelection.isCollapsed) {
      final selectionStart = oldSelection.start < oldSelection.end
          ? oldSelection.start
          : oldSelection.end;
      final selectionEnd = oldSelection.start > oldSelection.end
          ? oldSelection.start
          : oldSelection.end;

      final startDigitIndex = _countDigitsBeforeOffsetInRegion(
        oldText,
        selectionStart,
        regionSlots,
      );
      final endDigitIndex = _countDigitsBeforeOffsetInRegion(
        oldText,
        selectionEnd,
        regionSlots,
      );

      regionDigits =
          regionDigits.substring(0, startDigitIndex) + regionDigits.substring(endDigitIndex);
      caretDigitIndex = startDigitIndex;
    }

    if (regionDigits.length >= regionSlots.length) {
      return oldValue;
    }

    regionDigits = regionDigits.substring(0, caretDigitIndex) +
        insertedDigit +
        regionDigits.substring(caretDigitIndex);
    caretDigitIndex++;

    final masked = _replaceRegionDigits(oldText, regionSlots, regionDigits);
    final caretOffset = _caretOffsetForRegionDigitIndex(regionSlots, caretDigitIndex);

    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: caretOffset),
    );
  }
}

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
  _DailyAverageSettings? _loadedSettings;

  void _setCanSubmit(bool v) {
    if (_canSubmit == v) return;
    setState(() => _canSubmit = v);
    widget.onDirtyChanged(_canSubmit);
  }

  void _recomputeCanSubmit() {
    final loaded = _loadedSettings;
    if (loaded == null) {
      _setCanSubmit(false);
      return;
    }

    if (!_hasValidPinnedStartDate()) {
      _setCanSubmit(false);
      return;
    }

    if (!_hasValidPinnedEndDate()) {
      _setCanSubmit(false);
      return;
    }

    final startRaw = _summaryStatisticTextInputBox.text.trim();
    final endRaw = _endDateTextInputBox.text.trim();

    late final int currentDays;

    if (_pinStartDate) {
      final parsedDays = _daysAgoFromTextBoxDate(startRaw);
      if (parsedDays == null) {
        _setCanSubmit(false);
        return;
      }
      currentDays = parsedDays > 99999 ? 99999 : parsedDays;
    } else {
      final parsedDays = int.tryParse(startRaw);
      if (parsedDays == null || parsedDays <= 0) {
        if (_showingDisplayString && _currentAveragingWindowDays != null) {
          currentDays = _currentAveragingWindowDays!;
        } else {
          _setCanSubmit(false);
          return;
        }
      } else {
        currentDays = parsedDays > 99999 ? 99999 : parsedDays;
      }
    }

    final currentStartDate = _pinStartDate ? startRaw : '';
    final currentEndDate = _pinEndDate ? endRaw : '';

    final hasChanges =
        currentDays != loaded.numberOfDaysAgo ||
            currentStartDate != loaded.startDate ||
            currentEndDate != loaded.endDate ||
            _pinStartDate != loaded.pinStartDate ||
            _pinEndDate != loaded.pinEndDate;

    _setCanSubmit(hasChanges);
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
      final settings = await _db.readDailyAverageSettings();
      if (!mounted) return;

      setState(() {
        _loadedSettings = settings;
        _applyLoadedSettingsToUi(settings);
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
      setState(() {
        if (_showingDisplayString) {
          _summaryStatisticTextInputBox.clear();
          _showingDisplayString = false;
        }

        if (_pinStartDate) {
          final raw = _summaryStatisticTextInputBox.text.trim();
          final hasValidDate = _daysAgoFromTextBoxDate(raw) != null;
          if (hasValidDate) {
            _normalizePinnedStartDateForEditing();
          } else if (!_isDateEntryTemplate(raw)) {
            _showStartDateEntryTemplate();
          }
        }
      });
      _recomputeCanSubmit();
      return;
    }

    final raw = _summaryStatisticTextInputBox.text.trim();
    if (raw.isEmpty) {
      setState(() {
        if (_pinStartDate) {
          _showStartDateEntryTemplate();
        } else {
          _showCurrentDisplayString();
        }
      });
    }
    _recomputeCanSubmit();
  }

  void _handleEndDateFocusChanged() {
    if (_endDateFocusNode.hasFocus) {
      setState(() {
        if (_showingEndDateDisplayString) {
          if (_pinEndDate) {
            _showEndDateEntryTemplate();
          } else {
            _endDateTextInputBox.clear();
            _showingEndDateDisplayString = false;
          }
        }

        if (_pinEndDate) {
          final raw = _endDateTextInputBox.text.trim();
          final hasValidDate = _daysAgoFromTextBoxDate(raw) != null;
          if (hasValidDate) {
            _normalizePinnedEndDateForEditing();
          } else if (!_isDateEntryTemplate(raw)) {
            _showEndDateEntryTemplate();
          }
        }
      });
      _recomputeCanSubmit();
      return;
    }

    final raw = _endDateTextInputBox.text.trim();
    if (raw.isEmpty) {
      setState(() {
        if (_pinEndDate) {
          _showEndDateEntryTemplate();
        } else {
          _showEndDateDisplayString();
        }
      });
    }
    _recomputeCanSubmit();
  }

  void discardChanges() {
    FocusScope.of(context).unfocus();
    final loaded = _loadedSettings;
    if (loaded == null) {
      _setCanSubmit(false);
      return;
    }

    setState(() {
      _applyLoadedSettingsToUi(loaded);
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
        if (_pinStartDate) {
          _summaryStatisticTextInputBox.text = _formatDateForTextBox(picked);
        } else {
          _summaryStatisticTextInputBox.text = days.toString();
        }
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
      _pinEndDate = true;
      _forceStartDatePinnedFromCurrentDays();
      _endDateTextInputBox.text = _formatDateForTextBox(picked);
      _showingEndDateDisplayString = false;
    });
    _recomputeCanSubmit();
  }

  String _formatDateForTextBox(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    return '${two(date.month)}/${two(date.day)}/$year';
  }

  DateTime? _parseTextBoxDate(String raw) {
    final parts = raw.trim().split('/');
    if (parts.length != 3) {
      return null;
    }

    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) {
      return null;
    }

    final parsedDate = DateTime(year, month, day);
    if (parsedDate.year != year || parsedDate.month != month || parsedDate.day != day) {
      return null;
    }

    return DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
  }

  String _dateEntryTemplate() {
    return '__/__/____';
  }

  bool _isDateEntryTemplate(String raw) {
    return raw.trim() == _dateEntryTemplate();
  }

  void _showStartDateEntryTemplate() {
    _summaryStatisticTextInputBox.value = TextEditingValue(
      text: _dateEntryTemplate(),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _showingDisplayString = false;
  }

  void _showEndDateEntryTemplate() {
    _endDateTextInputBox.value = TextEditingValue(
      text: _dateEntryTemplate(),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _showingEndDateDisplayString = false;
  }

  int? _daysAgoFromTextBoxDate(String raw) {
    final parsedDate = _parseTextBoxDate(raw);
    if (parsedDate == null) {
      return null;
    }

    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final parsedDateOnly = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

    final diff = todayDateOnly.difference(parsedDateOnly).inDays;
    return diff < 0 ? 0 : diff;
  }

  void _normalizePinnedStartDateForEditing() {
    final oldValue = _summaryStatisticTextInputBox.value;
    final raw = oldValue.text.trim();
    if (raw.isEmpty || _isDateEntryTemplate(raw)) {
      return;
    }

    final parsedDate = _parseTextBoxDate(raw);
    if (parsedDate == null) {
      _showStartDateEntryTemplate();
      return;
    }

    final formatted = _formatDateForTextBox(parsedDate);
    final oldOffset = oldValue.selection.baseOffset;
    final newOffset = oldOffset < 0
        ? formatted.length
        : oldOffset > formatted.length
        ? formatted.length
        : oldOffset;

    _summaryStatisticTextInputBox.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  void _normalizePinnedEndDateForEditing() {
    final oldValue = _endDateTextInputBox.value;
    final raw = oldValue.text.trim();
    if (raw.isEmpty || _isDateEntryTemplate(raw)) {
      return;
    }

    final parsedDate = _parseTextBoxDate(raw);
    if (parsedDate == null) {
      _showEndDateEntryTemplate();
      return;
    }

    final formatted = _formatDateForTextBox(parsedDate);
    final oldOffset = oldValue.selection.baseOffset;
    final newOffset = oldOffset < 0
        ? formatted.length
        : oldOffset > formatted.length
        ? formatted.length
        : oldOffset;

    _endDateTextInputBox.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  bool _hasValidPinnedStartDate() {
    if (!_pinStartDate) {
      return true;
    }

    final raw = _summaryStatisticTextInputBox.text.trim();
    if (raw.isEmpty) {
      return false;
    }

    return _daysAgoFromTextBoxDate(raw) != null;
  }

  bool _hasValidPinnedEndDate() {
    if (!_pinEndDate) {
      return true;
    }

    final raw = _endDateTextInputBox.text.trim();
    if (raw.isEmpty) {
      return false;
    }

    return _parseTextBoxDate(raw) != null;
  }

  void _forceStartDatePinnedFromCurrentDays() {
    _pinStartDate = true;

    if (_currentAveragingWindowDays != null) {
      final startDate = DateTime.now().subtract(
        Duration(days: _currentAveragingWindowDays!),
      );
      _summaryStatisticTextInputBox.text = _formatDateForTextBox(startDate);
      _showingDisplayString = false;
      return;
    }

    _showStartDateEntryTemplate();
  }

  void _applyDaysAgoToStartTextBox(int daysAgo) {
    final clampedDaysAgo = daysAgo > 99999 ? 99999 : daysAgo;

    if (_currentAveragingWindowDays != null && clampedDaysAgo == _currentAveragingWindowDays!) {
      _showCurrentDisplayString();
      return;
    }

    _summaryStatisticTextInputBox.text = clampedDaysAgo.toString();
    _showingDisplayString = false;
  }

  void _applyLoadedSettingsToUi(_DailyAverageSettings settings) {
    _currentAveragingWindowDays = settings.numberOfDaysAgo;
    _pinStartDate = settings.pinStartDate;
    _pinEndDate = settings.pinEndDate;

    if (settings.pinStartDate) {
      if (settings.startDate.trim().isNotEmpty) {
        _summaryStatisticTextInputBox.text = settings.startDate;
        _showingDisplayString = false;
      } else {
        final startDate = DateTime.now().subtract(
          Duration(days: settings.numberOfDaysAgo),
        );
        _summaryStatisticTextInputBox.text = _formatDateForTextBox(startDate);
        _showingDisplayString = false;
      }
    } else {
      _showCurrentDisplayString();
    }

    if (settings.pinEndDate) {
      if (settings.endDate.trim().isNotEmpty) {
        _endDateTextInputBox.text = settings.endDate;
      } else {
        _showEndDateEntryTemplate();
      }
      _showingEndDateDisplayString = false;
    } else {
      _showEndDateDisplayString();
    }
  }

  Future<void> _submit() async {
    final startRaw = _summaryStatisticTextInputBox.text.trim();
    final endRaw = _endDateTextInputBox.text.trim();

    late final int daysToStore;

    if (_pinStartDate) {
      final parsedDays = _daysAgoFromTextBoxDate(startRaw);
      if (parsedDays == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid start date.')),
        );
        return;
      }
      daysToStore = parsedDays > 99999 ? 99999 : parsedDays;
    } else {
      final parsedDays = int.tryParse(startRaw);
      if (parsedDays == null || parsedDays <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a positive number of days.')),
        );
        return;
      }
      daysToStore = parsedDays > 99999 ? 99999 : parsedDays;
    }

    int displayedIntervalDays = daysToStore;
    if (_pinStartDate) {
      final startDate = _parseTextBoxDate(startRaw);
      DateTime? endDate;
      if (_pinEndDate) {
        endDate = _parseTextBoxDate(endRaw);
        if (endDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid end date.')),
          );
          return;
        }
      } else {
        final now = DateTime.now();
        endDate = DateTime(now.year, now.month, now.day);
      }

      if (startDate != null) {
        final rawIntervalDays = endDate.difference(startDate).inDays;
        displayedIntervalDays = rawIntervalDays <= 0 ? 1 : rawIntervalDays;
      }
    }

    final settings = _DailyAverageSettings(
      numberOfDaysAgo: daysToStore,
      startDate: _pinStartDate ? startRaw : '',
      endDate: _pinEndDate ? endRaw : '',
      pinStartDate: _pinStartDate,
      pinEndDate: _pinEndDate,
    );

    await _db.saveDailyAverageSettings(settings);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Averaging window saved: $displayedIntervalDays days.')),
    );

    FocusScope.of(context).unfocus();
    setState(() {
      _loadedSettings = settings;
      _applyLoadedSettingsToUi(settings);
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
                    keyboardType: _pinStartDate
                        ? TextInputType.datetime
                        : TextInputType.number,
                    readOnly: _showingDisplayString,
                    style: _showingDisplayString
                        ? inputStyle?.copyWith(color: Theme.of(context).hintColor)
                        : inputStyle,
                    inputFormatters: _pinStartDate
                        ? <TextInputFormatter>[
                      _MaskedDateTextInputFormatter(),
                    ]
                        : <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    onTap: () {
                      if (_showingDisplayString) {
                        setState(() {
                          _summaryStatisticTextInputBox.clear();
                          _showingDisplayString = false;
                        });
                        _recomputeCanSubmit();
                        return;
                      }

                      if (_pinStartDate) {
                        final raw = _summaryStatisticTextInputBox.text.trim();
                        final hasValidDate = _daysAgoFromTextBoxDate(raw) != null;
                        if (!hasValidDate && !_isDateEntryTemplate(raw)) {
                          setState(() {
                            _showStartDateEntryTemplate();
                          });
                          _recomputeCanSubmit();
                        }
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
                    keyboardType: _pinEndDate
                        ? TextInputType.datetime
                        : TextInputType.text,
                    style: _showingEndDateDisplayString
                        ? inputStyle?.copyWith(color: Theme.of(context).hintColor)
                        : inputStyle,
                    readOnly: _showingEndDateDisplayString,
                    inputFormatters: _pinEndDate
                        ? <TextInputFormatter>[
                      _MaskedDateTextInputFormatter(),
                    ]
                        : const <TextInputFormatter>[],
                    onTap: () {
                      if (_showingEndDateDisplayString) {
                        final today = DateTime.now();
                        setState(() {
                          _pinEndDate = true;
                          _forceStartDatePinnedFromCurrentDays();
                          _endDateTextInputBox.text = _formatDateForTextBox(today);
                          _showingEndDateDisplayString = false;
                        });
                        _recomputeCanSubmit();
                        return;
                      }

                      if (_pinEndDate) {
                        final raw = _endDateTextInputBox.text.trim();
                        final hasValidDate = _parseTextBoxDate(raw) != null;
                        if (!hasValidDate && !_isDateEntryTemplate(raw)) {
                          setState(() {
                            _showEndDateEntryTemplate();
                          });
                          _recomputeCanSubmit();
                        }
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
                      if (!value) {
                        _pinEndDate = false;
                        _showEndDateDisplayString();
                        _applyLoadedSettingsToUi(
                          _loadedSettings ??
                              _DailyAverageSettings(
                                numberOfDaysAgo: _currentAveragingWindowDays ?? 30,
                                startDate: '',
                                endDate: '',
                                pinStartDate: false,
                                pinEndDate: false,
                              ),
                        );
                      } else if (_showingDisplayString && _currentAveragingWindowDays != null) {
                        final startDate = DateTime.now().subtract(
                          Duration(days: _currentAveragingWindowDays!),
                        );
                        _summaryStatisticTextInputBox.text = _formatDateForTextBox(startDate);
                        _showingDisplayString = false;
                      } else {
                        final raw = _summaryStatisticTextInputBox.text.trim();
                        final hasValidDate = _daysAgoFromTextBoxDate(raw) != null;
                        if (!hasValidDate) {
                          _showStartDateEntryTemplate();
                        }
                      }
                    });
                    _recomputeCanSubmit();
                  },
                ),
                const Text('...and end date'),
                const SizedBox(width: 8),
                Switch(
                  value: _pinEndDate,
                  onChanged: (value) {
                    setState(() {
                      _pinEndDate = value;
                      if (value) {
                        _forceStartDatePinnedFromCurrentDays();
                        final raw = _endDateTextInputBox.text.trim();
                        final hasValidDate = _parseTextBoxDate(raw) != null;
                        if (_showingEndDateDisplayString) {
                          final today = DateTime.now();
                          _endDateTextInputBox.text = _formatDateForTextBox(today);
                          _showingEndDateDisplayString = false;
                        } else if (!hasValidDate) {
                          _showEndDateEntryTemplate();
                        } else {
                          _normalizePinnedEndDateForEditing();
                        }
                      } else {
                        _showEndDateDisplayString();
                      }
                    });
                    _recomputeCanSubmit();
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