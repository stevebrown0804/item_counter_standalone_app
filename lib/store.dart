// store.dart

part of 'main.dart';

class _Store extends ChangeNotifier {
  _Store(this._db);
  final _Db _db;
  final List<_AvgRow> _rows = [];
  UnmodifiableListView<_AvgRow> get rows => UnmodifiableListView(_rows);
  int _days = 0;
  int get days => _days;
  String? _averageWindowTooltip;
  String? get averageWindowTooltip => _averageWindowTooltip;
  List<_Item> _items = const [];
  UnmodifiableListView<_Item> get items => UnmodifiableListView(_items);
  _Tz? _activeTz;
  _Tz get activeTz => _activeTz ?? _Tz('UTC', 'UTC');   //UTC is the fallback

  // Undo/redo uses 'batch tokens,' which are provided by the Rust backend
  final List<String> _undoTokens = [];
  bool get canUndo => _undoTokens.isNotEmpty;
  final List<String> _redoTokens = [];
  bool get canRedo => _redoTokens.isNotEmpty;

  DateTime _todayDateOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
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

  String _formatTooltipDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String? _buildAverageWindowTooltip(_DailyAverageSettings settings) {
    if (!settings.pinStartDate) {
      return null;
    }

    final startDate = _parseTextBoxDate(settings.startDate) ??
        _todayDateOnly().subtract(Duration(days: settings.numberOfDaysAgo));

    if (!settings.pinEndDate) {
      return '${_formatTooltipDate(startDate)} to today';
    }

    final endDate = _parseTextBoxDate(settings.endDate) ?? _todayDateOnly();
    return '${_formatTooltipDate(startDate)} to ${_formatTooltipDate(endDate)}';
  }

  void clearUndoRedo() {
    _undoTokens.clear();
    _redoTokens.clear();
    notifyListeners();
  }

  void _breakRedoChain() {
    if (_redoTokens.isNotEmpty) {
      _redoTokens.clear();
    }
  }

  Future<void> undoLastOperation() async {
    if (_undoTokens.isEmpty) return;
    final token = _undoTokens.removeLast();

    await _db.undoLogicalBatch(token);

    // When we undo a transaction, we'll allow it to be re-done as well
    _redoTokens.add(token);

    await refreshFromDatabase();
    notifyListeners();
  }

  Future<void> redoLastOperation() async {
    if (_redoTokens.isEmpty) return;
    final token = _redoTokens.removeLast();

    await _db.redoLogicalBatch(token);

    // When we redo a transaction, we'll allow it to be re-undone as well
    _undoTokens.add(token);

    await refreshFromDatabase();
    notifyListeners();
  }

  Future<void> refreshFromDatabase() async {
    //Refresh the values held by Store, from the DB
    _activeTz = await _db.readActiveTz() ?? _Tz('UTC', 'UTC');
    final averageSettings = await _db.readDailyAverageSettings();
    _days = await _db.readAveragingWindowDays();
    _averageWindowTooltip = _buildAverageWindowTooltip(averageSettings);
    _items = await _db.listItemsOrdered();

    final list = await _db.readDailyAverages();
    _rows
      ..clear()
      ..addAll(list);
    notifyListeners();
  }

  Future<void> addBatchAndTrackUndo(
      Map<int, int> quantities, {
        String? overrideLocalTimestamp,
      }) async {
    //Construct the batch
    final entries = <_Entry>[];
    quantities.forEach((itemId, qty) {
      if (qty > 0) entries.add(_Entry(itemId, qty));
    });
    if (entries.isEmpty) return;

    String? utcIso;
    if (overrideLocalTimestamp != null) {
      // Convert active-TZ local wall-clock time to UTC DB timestamp
      utcIso = await _db.localToUtcDbTimestamp(overrideLocalTimestamp);
    }

    // INSERT that batch and add its undo token to _undoTokens
    final token = await _db.insertBatchWithUndoToken(entries, utcIso);
    _breakRedoChain();
    _undoTokens.add(token);

    await refreshFromDatabase();
  }
}
