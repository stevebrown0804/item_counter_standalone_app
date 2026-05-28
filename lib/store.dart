// store.dart

part of 'main.dart';

class _Store extends ChangeNotifier {
  _Store(this._db);

  static const double _singleDayDisplayThreshold = 1.0;
  static const double _integerDayDisplayThreshold = 7.0;

  final _Db _db;
  final List<_AvgRow> _rows = [];
  UnmodifiableListView<_AvgRow> get rows => UnmodifiableListView(_rows);

  int _days = 0;
  int get days => _days;

  double _averageWindowElapsedDays = 0.0;
  double get averageWindowElapsedDays => _averageWindowElapsedDays;

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

  String get averageWindowDisplayText {
    final days = _averageWindowElapsedDays;

    if (days < _singleDayDisplayThreshold) {
      return '${days.toStringAsFixed(2)} days';
    }

    if (days <= _singleDayDisplayThreshold) {
      return '${days.toStringAsFixed(1)} day';
    }

    if (days < _integerDayDisplayThreshold) {
      return '${days.toStringAsFixed(1)} days';
    }

    return '${days.floor()} days';
  }

  String get averageWindowHeaderText {
    return 'Avg. ($averageWindowDisplayText)';
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
  }

  Future<void> redoLastOperation() async {
    if (_redoTokens.isEmpty) return;
    final token = _redoTokens.removeLast();

    await _db.redoLogicalBatch(token);

    // When we redo a transaction, we'll allow it to be re-undone as well
    _undoTokens.add(token);

    await refreshFromDatabase();
  }

  Future<void> refreshFromDatabase() async {
    //Refresh the values held by Store, from the DB
    _activeTz = await _db.readActiveTz() ?? _Tz('UTC', 'UTC');
    final averageSettings = await _db.readDailyAverageSettings();
    _days = await _db.readAveragingWindowDays();
    _averageWindowElapsedDays = await _db.readAveragingWindowElapsedDays();
    _averageWindowTooltip = _AppDateLogic.buildAverageWindowTooltip(
      averageSettings,
      activeTz.tzName,
    );
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