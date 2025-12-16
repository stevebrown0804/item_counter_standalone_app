part of 'main.dart';

class _Store extends ChangeNotifier {
  _Store(this._db);
  final _Db _db;
  final List<_AvgRow> _rows = [];
  UnmodifiableListView<_AvgRow> get rows => UnmodifiableListView(_rows);
  int _days = 0;
  int get days => _days;
  List<_Item> _items = const [];
  UnmodifiableListView<_Item> get items => UnmodifiableListView(_items);
  _Tz? _activeTz;
  _Tz get activeTz => _activeTz ?? _Tz('UTC', 'UTC');   //UTC is the fallback

  // Undo/redo uses 'batch tokens,' which are provided by the Rust backend
  final List<String> _undoTokens = [];
  bool get canUndo => _undoTokens.isNotEmpty;
  final List<String> _redoTokens = [];
  bool get canRedo => _redoTokens.isNotEmpty;


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
    _days = await _db.readAveragingWindowDays();
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
