part of 'main.dart';

// <editor-fold desc="_Store, which holds everything not specific to the FFI, DB or UI">
class _Store extends ChangeNotifier {
  _Store(this._db);
  final _Db _db;
  final List<_AvgRow> _rows = [];
  UnmodifiableListView<_AvgRow> get rows => UnmodifiableListView(_rows);
  int _days = 0;
  int get days => _days;
  List<_Pill> _pills = const [];
  UnmodifiableListView<_Pill> get pills => UnmodifiableListView(_pills);
  _Tz? _activeTz;
  _Tz get activeTz => _activeTz ?? _Tz('UTC', 'UTC');

  // Undo/redo now track opaque batch tokens provided by Rust backend.
  final List<String> _undoTokens = [];
  bool get canUndo => _undoTokens.isNotEmpty;
  final List<String> _redoTokens = [];
  bool get canRedo => _redoTokens.isNotEmpty;

  void _breakRedoChain() {
    if (_redoTokens.isNotEmpty) {
      _redoTokens.clear();
    }
  }

  Future<void> undoLast() async {
    if (_undoTokens.isEmpty) return;
    final token = _undoTokens.removeLast();

    // Backend will delete/recreate pill_transactions based on the batch.
    await _db.undoLogicalBatch(token);

    // Keep token so we can redo the same logical batch.
    _redoTokens.add(token);

    await load();
    notifyListeners();
  }

  Future<void> redoLast() async {
    if (_redoTokens.isEmpty) return;
    final token = _redoTokens.removeLast();

    await _db.redoLogicalBatch(token);

    // Redo resets the redo chain and adds token to undo history.
    _breakRedoChain();
    _undoTokens.add(token);

    await load();
    notifyListeners();
  }

  Future<void> load() async {
    _activeTz = await _db.readActiveTz() ?? _Tz('UTC', 'UTC');
    _days = await _db.readAveragingWindowDays();
    _pills = await _db.listPillsOrdered();

    final list = await _db.readDailyAverages();
    _rows
      ..clear()
      ..addAll(list);
    notifyListeners();
  }

  Future<void> addBatch(Map<int, int> quantities) async {
    final entries = <_Entry>[];
    quantities.forEach((pillId, qty) {
      if (qty > 0) entries.add(_Entry(pillId, qty));
    });
    if (entries.isEmpty) return;

    // Insert as a single logical batch and record the opaque undo token.
    final token = await _db.insertBatchWithUndoToken(entries, null);
    _breakRedoChain();
    _undoTokens.add(token);

    await load();
  }
}

// </editor-fold>
