// db.dart

part of 'main.dart';

DateTime parseDbUtc(String s) {
  final base = s.replaceFirst(' ', 'T');
  final iso = base.endsWith('+00:00') ? base.replaceFirst('+00:00', 'Z') : '${base}Z';

  return DateTime.parse(iso).toUtc();
}

// ── the DB wrapper (sqflite + Rust FFI) ──
class _Db {
  static Database? _sharedDb;
  static Future<Database>? _sharedOpenFuture;

  Future<T> _timed<T>(String label, Future<T> Function() action) async {
    final sw = Stopwatch()..start();
    debugPrint('[DB] START $label');
    try {
      final result = await action();
      debugPrint('[DB] END   $label (${sw.elapsedMilliseconds} ms)');
      return result;
    } catch (e, st) {
      debugPrint('[DB] FAIL  $label after ${sw.elapsedMilliseconds} ms: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  Future<String> _dbPath() async {
    final dbDir = await getDatabasesPath();
    return p.join(dbDir, kDbFileName);
  }

  Future<Database> open() async {
    final existingDb = _sharedDb;
    if (existingDb != null) {
      return existingDb;
    }

    final existingFuture = _sharedOpenFuture;
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _timed('openDatabase()', () async {
      final full = await _dbPath();
      final opened = await openDatabase(full);
      await _ensureSchema(opened);
      _sharedDb = opened;
      return opened;
    });

    _sharedOpenFuture = future;

    try {
      return await future;
    } finally {
      _sharedOpenFuture = null;
    }
  }

  Future<void> _ensureSchema(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');

    await db.execute('''
CREATE TABLE IF NOT EXISTS items (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    display_string  TEXT UNIQUE NOT NULL,
    display_order   INTEGER UNIQUE,
    show_item       INTEGER NOT NULL DEFAULT (1)
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS item_transactions (
    id            INTEGER  PRIMARY KEY,
    item_id       INTEGER  NOT NULL,
    quantity      INTEGER  NOT NULL CHECK (quantity > 0),
    timestamp_utc DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (item_id) REFERENCES items (id)
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS settings (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS time_zone_aliases (
    id           INTEGER PRIMARY KEY,
    alias        TEXT NOT NULL UNIQUE,
    iana_tz_name TEXT NOT NULL
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS logical_batches (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    token      TEXT NOT NULL,
    undone     INTEGER NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
)
''');

    await db.execute('''
CREATE TABLE IF NOT EXISTS logical_batch_items (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_id       INTEGER NOT NULL,
    transaction_id INTEGER NOT NULL,
    item_id        INTEGER NOT NULL,
    quantity       INTEGER NOT NULL,
    timestamp_utc  DATETIME NOT NULL,
    FOREIGN KEY (batch_id) REFERENCES logical_batches(id)
)
''');

    await db.execute('''
CREATE VIEW IF NOT EXISTS logged_days AS
WITH cfg AS (
        SELECT CAST((
                   SELECT value
                     FROM settings
                    WHERE key = 'avg_window_days'
               ) AS INTEGER) AS n
    ),
    global AS (
        SELECT DATE('now') AS today,
               MIN(DATE(timestamp_utc)) AS min_date
          FROM item_transactions
    ),
    window AS (
        SELECT g.today,
               g.min_date,
               c.n,
               DATE(JULIANDAY(g.today) - (c.n - 1)) AS n_start,
               CASE
                   WHEN g.min_date IS NULL THEN 0
                   ELSE CAST(
                       JULIANDAY(g.today) - JULIANDAY(MAX(g.min_date, DATE(JULIANDAY(g.today) - (c.n - 1))))
                       AS INTEGER
                   ) + 1
               END AS days
          FROM global g
          CROSS JOIN cfg c
    )
    SELECT days AS number_of_days
      FROM window
''');

    await _ensureSettingDefault(db, 'avg_window_days', '30');
    await _ensureSettingDefault(db, 'skip_delete_transactions_second_dialog_confirmation', '0');
    await _ensureSettingDefault(db, 'time_zone_id', '0');
    await _ensureSettingDefault(db, 'appbar_title', 'Item Counter');
    await _ensureSettingDefault(db, 'lhs_column_header', 'Item');
    await _ensureSettingDefault(db, 'rhs_column_header', 'Avg. {days} day(s)');
    await _ensureSettingDefault(db, 'last_added_banner_text', '');
    await _ensureSettingDefault(db, 'last_added_banner_dismissed', '0');

    await db.rawInsert(
      'INSERT OR IGNORE INTO time_zone_aliases (alias, iana_tz_name) VALUES (?, ?)',
      ['UTC', 'Etc/UTC'],
    );
    await db.rawInsert(
      'INSERT OR IGNORE INTO time_zone_aliases (alias, iana_tz_name) VALUES (?, ?)',
      ['GMT', 'Etc/UTC'],
    );
    await db.rawInsert(
      'INSERT OR IGNORE INTO time_zone_aliases (alias, iana_tz_name) VALUES (?, ?)',
      ['Z', 'Etc/UTC'],
    );
  }

  Future<void> _ensureSettingDefault(Database db, String key, String value) async {
    final rows = await db.rawQuery(
      'SELECT value FROM settings WHERE key = ?1',
      [key],
    );
    if (rows.isNotEmpty) {
      return;
    }
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  String _normalizeDbLikeTimestamp(String s) {
    final trimmed = s.trim();
    if (trimmed.endsWith('+00:00')) {
      return trimmed.substring(0, trimmed.length - 6).trim();
    }
    if (trimmed.endsWith('Z')) {
      return trimmed.substring(0, trimmed.length - 1).trim();
    }
    return trimmed;
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _formatDbTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = _two(dt.month);
    final d = _two(dt.day);
    final h = _two(dt.hour);
    final min = _two(dt.minute);
    final s = _two(dt.second);
    return '$y-$m-$d $h:$min:$s';
  }

  DateTime _parseNaiveTimestamp(String s) {
    final norm = _normalizeDbLikeTimestamp(s);
    final parsed = DateTime.parse(norm.replaceFirst(' ', 'T'));
    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
    );
  }

  Future<_Tz?> _readActiveTzFromDb(Database db) async {
    final rows = await db.rawQuery(
      '''
SELECT tz.alias, tz.iana_tz_name
FROM settings s
JOIN time_zone_aliases tz ON tz.id = CAST(s.value AS INTEGER)
WHERE s.key = 'time_zone_id'
LIMIT 1
''',
    );
    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    final alias = row['alias']?.toString();
    final tzName = row['iana_tz_name']?.toString();
    if (alias == null || alias.isEmpty || tzName == null || tzName.isEmpty) {
      return null;
    }
    return _Tz(alias, tzName);
  }

  Future<String> _activeTzNameOrUtcFromDb(Database db) async {
    final tzRow = await _readActiveTzFromDb(db);
    if (tzRow == null) {
      return 'Etc/UTC';
    }
    return tzRow.tzName;
  }

  Future<List<_TzAliasGroup>> _listTzAliasGroupsFromDb(Database db) async {
    final rows = await db.rawQuery(
      '''
SELECT alias, iana_tz_name
FROM time_zone_aliases
ORDER BY iana_tz_name, alias
''',
    );

    final groups = <_TzAliasGroup>[];
    String? currentTzName;
    final currentAliases = <String>[];

    void flush() {
      if (currentTzName == null || currentAliases.isEmpty) {
        return;
      }
      groups.add(
        _TzAliasGroup(
          currentTzName,
          currentAliases.join('/'),
          List<String>.from(currentAliases),
        ),
      );
      currentAliases.clear();
    }

    for (final row in rows) {
      final tzName = row['iana_tz_name']?.toString() ?? '';
      final alias = row['alias']?.toString() ?? '';
      if (tzName.isEmpty || alias.isEmpty) {
        continue;
      }

      if (currentTzName == tzName) {
        currentAliases.add(alias);
      } else {
        flush();
        currentTzName = tzName;
        currentAliases.add(alias);
      }
    }

    flush();
    return groups;
  }

  Future<List<_TxRow>> _queryTransactionsUtcRangeDb(
      Database db, {
        String? startUtc,
        String? endUtc,
      }) async {
    final whereClauses = <String>[];
    final args = <Object?>[];

    if (startUtc != null) {
      whereClauses.add('t.timestamp_utc >= ?');
      args.add(startUtc);
    }
    if (endUtc != null) {
      whereClauses.add('t.timestamp_utc < ?');
      args.add(endUtc);
    }

    final whereSql = whereClauses.isEmpty ? '' : 'WHERE ${whereClauses.join(' AND ')}';

    final rows = await db.rawQuery(
      '''
SELECT t.id, t.timestamp_utc, p.display_string AS item_name, t.quantity
FROM item_transactions t
JOIN items p ON p.id = t.item_id
$whereSql
ORDER BY t.timestamp_utc DESC
''',
      args,
    );

    return rows.map((row) {
      final idRaw = row['id'];
      final tsRaw = row['timestamp_utc'];
      final itemRaw = row['item_name'];
      final qtyRaw = row['quantity'];

      final id = (idRaw is num) ? idRaw.toInt() : int.parse(idRaw.toString());
      final qty = (qtyRaw is num) ? qtyRaw.toInt() : int.parse(qtyRaw.toString());
      final utc = parseDbUtc(tsRaw.toString());
      final item = itemRaw?.toString() ?? '';

      return _TxRow(id, utc, item, qty);
    }).toList();
  }

  Future<void> _validateEntriesForBatchInsert(List<_Entry> entries) async {
    if (entries.isEmpty) {
      throw ArgumentError('entries must not be empty');
    }

    for (final entry in entries) {
      if (entry.qty <= 0) {
        throw ArgumentError('quantity must be > 0');
      }
    }
  }

  Future<(int, String)> _createPendingBatch(Transaction txn) async {
    final batchId = await txn.rawInsert(
      "INSERT INTO logical_batches (token, undone) VALUES ('pending', 0)",
    );
    final token = 'batch-$batchId';

    final updated = await txn.rawUpdate(
      'UPDATE logical_batches SET token = ?1 WHERE id = ?2',
      [token, batchId],
    );

    if (updated != 1) {
      throw StateError('Failed to update logical_batches token for batch $batchId');
    }

    return (batchId, token);
  }

  Future<String> _readInsertedTransactionTimestamp(
      Transaction txn,
      int transactionId,
      ) async {
    final rows = await txn.rawQuery(
      'SELECT timestamp_utc FROM item_transactions WHERE id = ?1',
      [transactionId],
    );

    if (rows.isEmpty || rows.first['timestamp_utc'] == null) {
      throw StateError('Inserted transaction $transactionId has no timestamp_utc');
    }

    return rows.first['timestamp_utc'].toString();
  }

  Future<void> _insertLogicalBatchItem(
      Transaction txn,
      int batchId,
      int transactionId,
      int itemId,
      int qty,
      String timestampUtc,
      ) async {
    await txn.rawInsert(
      '''
INSERT INTO logical_batch_items (batch_id, transaction_id, item_id, quantity, timestamp_utc)
VALUES (?1, ?2, ?3, ?4, ?5)
''',
      [batchId, transactionId, itemId, qty, timestampUtc],
    );
  }

  Future<List<int>> _insertBatchItemsWithLiteralTimestamp(
      Transaction txn,
      int batchId,
      List<_Entry> entries,
      String timestampUtc,
      ) async {
    final ids = <int>[];

    for (final entry in entries) {
      final id = await txn.rawInsert(
        'INSERT INTO item_transactions (item_id, quantity, timestamp_utc) VALUES (?1, ?2, ?3)',
        [entry.itemId, entry.qty, timestampUtc],
      );
      ids.add(id);

      final tsStr = await _readInsertedTransactionTimestamp(txn, id);
      await _insertLogicalBatchItem(
        txn,
        batchId,
        id,
        entry.itemId,
        entry.qty,
        tsStr,
      );
    }

    return ids;
  }

  Future<List<int>> _insertBatchItemsWithCurrentTimestamp(
      Transaction txn,
      int batchId,
      List<_Entry> entries,
      ) async {
    final ids = <int>[];

    for (final entry in entries) {
      final id = await txn.rawInsert(
        'INSERT INTO item_transactions (item_id, quantity, timestamp_utc) VALUES (?1, ?2, CURRENT_TIMESTAMP)',
        [entry.itemId, entry.qty],
      );
      ids.add(id);

      final tsStr = await _readInsertedTransactionTimestamp(txn, id);
      await _insertLogicalBatchItem(
        txn,
        batchId,
        id,
        entry.itemId,
        entry.qty,
        tsStr,
      );
    }

    return ids;
  }

  Future<int> _loadBatchIdForUndo(Transaction txn, String token) async {
    final rows = await txn.rawQuery(
      '''
SELECT id, undone
FROM logical_batches
WHERE token = ?1
LIMIT 1
''',
      [token],
    );

    if (rows.isEmpty) {
      throw ArgumentError('batch $token not found');
    }

    final row = rows.first;
    final batchIdRaw = row['id'];
    final undoneRaw = row['undone'];

    if (batchIdRaw == null || undoneRaw == null) {
      throw StateError('logical_batches row for token $token is missing fields');
    }

    final batchId = (batchIdRaw is num)
        ? batchIdRaw.toInt()
        : int.parse(batchIdRaw.toString());
    final undone = (undoneRaw is num)
        ? undoneRaw.toInt()
        : int.parse(undoneRaw.toString());

    if (undone != 0) {
      throw ArgumentError('batch $token is already undone');
    }

    return batchId;
  }

  Future<List<int>> _loadBatchTransactionIds(
      Transaction txn,
      int batchId,
      ) async {
    final rows = await txn.rawQuery(
      '''
SELECT transaction_id
FROM logical_batch_items
WHERE batch_id = ?1
ORDER BY id
''',
      [batchId],
    );

    return rows.map((row) {
      final raw = row['transaction_id'];
      if (raw == null) {
        throw StateError(
          'logical_batch_items row for batch $batchId is missing transaction_id',
        );
      }
      return (raw is num) ? raw.toInt() : int.parse(raw.toString());
    }).toList();
  }

  Future<void> _deleteBatchTransactions(
      Transaction txn,
      String token,
      List<int> txIds,
      ) async {
    for (final txId in txIds) {
      final deleted = await txn.delete(
        'item_transactions',
        where: 'id = ?',
        whereArgs: [txId],
      );

      if (deleted == 0) {
        throw ArgumentError(
          'transaction $txId for batch $token no longer exists; cannot undo cleanly',
        );
      }
    }
  }

  Future<void> _markBatchUndone(Transaction txn, int batchId) async {
    final updated = await txn.rawUpdate(
      'UPDATE logical_batches SET undone = 1 WHERE id = ?1',
      [batchId],
    );

    if (updated != 1) {
      throw StateError('Failed to mark batch $batchId as undone');
    }
  }

  Future<int> _loadBatchIdForRedo(Transaction txn, String token) async {
    final rows = await txn.rawQuery(
      '''
SELECT id, undone
FROM logical_batches
WHERE token = ?1
LIMIT 1
''',
      [token],
    );

    if (rows.isEmpty) {
      throw ArgumentError('batch $token not found');
    }

    final row = rows.first;
    final batchIdRaw = row['id'];
    final undoneRaw = row['undone'];

    if (batchIdRaw == null || undoneRaw == null) {
      throw StateError('logical_batches row for token $token is missing fields');
    }

    final batchId = (batchIdRaw is num)
        ? batchIdRaw.toInt()
        : int.parse(batchIdRaw.toString());
    final undone = (undoneRaw is num)
        ? undoneRaw.toInt()
        : int.parse(undoneRaw.toString());

    if (undone == 0) {
      throw ArgumentError('batch $token is not undone; cannot redo');
    }

    return batchId;
  }

  Future<List<(int, int, int, String)>> _loadBatchRedoItems(
      Transaction txn,
      int batchId,
      ) async {
    final rows = await txn.rawQuery(
      '''
SELECT id, item_id, quantity, timestamp_utc
FROM logical_batch_items
WHERE batch_id = ?1
ORDER BY id
''',
      [batchId],
    );

    return rows.map((row) {
      final batchItemRowIdRaw = row['id'];
      final itemIdRaw = row['item_id'];
      final qtyRaw = row['quantity'];
      final tsRaw = row['timestamp_utc'];

      if (batchItemRowIdRaw == null ||
          itemIdRaw == null ||
          qtyRaw == null ||
          tsRaw == null) {
        throw StateError(
          'logical_batch_items row for batch $batchId is missing fields',
        );
      }

      final batchItemRowId = (batchItemRowIdRaw is num)
          ? batchItemRowIdRaw.toInt()
          : int.parse(batchItemRowIdRaw.toString());
      final itemId = (itemIdRaw is num)
          ? itemIdRaw.toInt()
          : int.parse(itemIdRaw.toString());
      final qty = (qtyRaw is num)
          ? qtyRaw.toInt()
          : int.parse(qtyRaw.toString());
      final ts = tsRaw.toString();

      return (batchItemRowId, itemId, qty, ts);
    }).toList();
  }

  Future<List<int>> _reinsertBatchTransactions(
      Transaction txn,
      String token,
      List<(int, int, int, String)> items,
      ) async {
    final newIds = <int>[];

    for (final item in items) {
      final batchItemRowId = item.$1;
      final itemId = item.$2;
      final qty = item.$3;
      final ts = item.$4;

      if (qty <= 0) {
        throw ArgumentError(
          'logical batch $token has non-positive quantity for item $itemId',
        );
      }

      final newTxId = await txn.rawInsert(
        '''
INSERT INTO item_transactions (item_id, quantity, timestamp_utc)
VALUES (?1, ?2, ?3)
''',
        [itemId, qty, ts],
      );
      newIds.add(newTxId);

      final updated = await txn.rawUpdate(
        'UPDATE logical_batch_items SET transaction_id = ?1 WHERE id = ?2',
        [newTxId, batchItemRowId],
      );

      if (updated != 1) {
        throw StateError(
          'Failed to update logical_batch_items row $batchItemRowId during redo',
        );
      }
    }

    return newIds;
  }

  Future<void> _markBatchRedone(Transaction txn, int batchId) async {
    final updated = await txn.rawUpdate(
      'UPDATE logical_batches SET undone = 0 WHERE id = ?1',
      [batchId],
    );

    if (updated != 1) {
      throw StateError('Failed to mark batch $batchId as redone');
    }
  }

  // ───────────────────────── Items ─────────────────────────

  Future<List<_Item>> listItemsOrdered() async {
    return _timed('listItemsOrdered()', () async {
      final db = await open();
      final rows = await db.rawQuery(
        '''
SELECT id, display_string, display_order, show_item
FROM items
ORDER BY CAST(display_order AS INTEGER), id
''',
      );

      return rows.map((row) {
        final idRaw = row['id'];
        final nameRaw = row['display_string'];
        final displayOrderRaw = row['display_order'];
        final showItemRaw = row['show_item'];

        final id = (idRaw is num) ? idRaw.toInt() : int.parse(idRaw.toString());
        final name = nameRaw?.toString() ?? '';
        final displayOrder = displayOrderRaw == null
            ? null
            : (displayOrderRaw is num)
            ? displayOrderRaw.toInt()
            : int.tryParse(displayOrderRaw.toString());
        final showItem = (showItemRaw is num)
            ? showItemRaw.toInt() != 0
            : showItemRaw?.toString() == '1';

        return _Item(id, name, displayOrder, showItem);
      }).toList();
    });
  }

  // Generic settings helper: read a required string value by key.
  Future<String> readSettingString(String key) async {
    final rows = await rawQuery(
      'SELECT value FROM settings WHERE key = ?1',
      [key],
    );
    if (rows.isEmpty || rows.first['value'] == null) {
      throw StateError('Missing required setting: $key');
    }
    final v = rows.first['value'];
    if (v is String) return v;
    return v.toString();
  }

  Future<String?> tryReadSettingString(String key) async {
    final rows = await rawQuery(
      'SELECT value FROM settings WHERE key = ?1',
      [key],
    );
    if (rows.isEmpty || rows.first['value'] == null) {
      return null;
    }
    final v = rows.first['value'];
    if (v is String) return v;
    return v.toString();
  }

  Future<void> upsertSettingString(String key, String value) async {
    final db = await open();
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ───────────────────────── Settings: averaging window ─────────────────────────

  Future<int> readAveragingWindowDays() async {
    return _timed('readAveragingWindowDays()', () async {
      final db = await open();
      final rows = await db.rawQuery(
        'SELECT number_of_days FROM logged_days LIMIT 1',
      );
      if (rows.isEmpty) {
        return 0;
      }
      final value = rows.first['number_of_days'];
      if (value == null) {
        return 0;
      }
      if (value is num) {
        return value.toInt();
      }
      return int.tryParse(value.toString()) ?? 0;
    });
  }

  Future<void> setAveragingWindowDays(int days) async {
    if (days <= 0) {
      throw ArgumentError('days must be > 0');
    }

    final db = await open();
    final updated = await db.update(
      'settings',
      {'value': days.toString()},
      where: 'key = ?',
      whereArgs: ['avg_window_days'],
    );

    if (updated == 0) {
      throw StateError('settings.avg_window_days not found');
    }
  }

  /// Compute the averaging window (in days) based on a picked local calendar date
  /// string "YYYY-MM-DD" in the active time zone.
  Future<int> computeAveragingWindowDaysFromPickedLocalDate(String localDateYmd) async {
    final db = await open();
    final tzName = await _activeTzNameOrUtcFromDb(db);

    tz.Location loc;
    try {
      loc = tz.getLocation(tzName);
    } catch (_) {
      loc = tz.getLocation('Etc/UTC');
    }

    final parts = localDateYmd.split('-');
    if (parts.length != 3) {
      throw ArgumentError('invalid local date $localDateYmd');
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      throw ArgumentError('invalid local date $localDateYmd');
    }

    final picked = DateTime(year, month, day);
    final nowLocal = tz.TZDateTime.now(loc);
    final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final effectivePicked = picked.isAfter(today) ? today : picked;
    final rawDays = today.difference(effectivePicked).inDays;
    return rawDays <= 0 ? 1 : rawDays;
  }

  /// Oldest transaction date in the active time zone, truncated to a
  /// calendar date (year-month-day). Returns null if there are no transactions.
  Future<DateTime?> readOldestTransactionLocalDate() async {
    final db = await open();

    final rows = await db.rawQuery(
      'SELECT MIN(timestamp_utc) AS timestamp_utc FROM item_transactions',
    );
    if (rows.isEmpty) {
      return null;
    }

    final tsRaw = rows.first['timestamp_utc'];
    if (tsRaw == null) {
      return null;
    }

    final oldestUtc = parseDbUtc(tsRaw.toString());
    final tzInfo = await readActiveTz();
    var tzName = 'Etc/UTC';
    if (tzInfo != null && tzInfo.tzName.isNotEmpty) {
      tzName = tzInfo.tzName;
    }

    tz.Location loc;
    try {
      loc = tz.getLocation(tzName);
    } catch (_) {
      loc = tz.getLocation('Etc/UTC');
    }

    final local = tz.TZDateTime.from(oldestUtc, loc);
    return DateTime(local.year, local.month, local.day);
  }

  // ───────────────────────── Settings: skip second confirmation ─────────────────────────

  Future<bool> readSkipDeleteSecondConfirm() async {
    final db = await open();
    final rows = await db.rawQuery(
      '''
SELECT value
FROM settings
WHERE key = 'skip_delete_transactions_second_dialog_confirmation'
LIMIT 1
''',
    );
    if (rows.isEmpty) {
      return false;
    }
    final raw = rows.first['value']?.toString().trim() ?? '0';
    return raw == '1' || raw.toLowerCase() == 'true';
  }

  Future<void> setSkipDeleteSecondConfirm(bool skip) async {
    final db = await open();
    final value = skip ? '1' : '0';

    final updated = await db.update(
      'settings',
      {'value': value},
      where: 'key = ?',
      whereArgs: ['skip_delete_transactions_second_dialog_confirmation'],
    );

    if (updated == 0) {
      await db.insert(
        'settings',
        {
          'key': 'skip_delete_transactions_second_dialog_confirmation',
          'value': value,
        },
      );
    }
  }

  // ───────────────────────── Transactions: archive/delete ─────────────────────────

  Future<int> deleteTransactionsOlderThanDays(int days) async {
    final db = await open();
    if (days <= 0) {
      return 0;
    }

    return db.rawDelete(
      "DELETE FROM item_transactions WHERE timestamp_utc < datetime('now', ?)",
      ['-$days days'],
    );
  }

  Future<int> countTransactionsOlderThanDays(int days) async {
    final db = await open();
    if (days <= 0) {
      return 0;
    }

    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM item_transactions WHERE timestamp_utc < datetime('now', ?)",
      ['-$days days'],
    );

    if (rows.isEmpty) {
      return 0;
    }

    final value = rows.first['cnt'];
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString()) ?? 0;
  }

  Future<int> deleteOldTransactionsWithPolicy(int days) async {
    if (days <= 0) {
      throw ArgumentError('days must be > 0');
    }

    await readSkipDeleteSecondConfirm();
    return deleteTransactionsOlderThanDays(days);
  }

  // ───────────────────────── Averages ─────────────────────────

  Future<List<_AvgRow>> readDailyAverages() async {
    return _timed('readDailyAverages()', () async {
      final db = await open();
      final effectiveDays = await readAveragingWindowDays();

      if (effectiveDays == 0) {
        final rows = await db.rawQuery(
          '''
SELECT id, display_string
FROM items
WHERE COALESCE(show_item, 1) != 0
ORDER BY CAST(display_order AS INTEGER), id
''',
        );

        return rows.map((row) {
          return _AvgRow(row['display_string']?.toString() ?? '', 0.0);
        }).toList();
      }

      final rows = await db.rawQuery(
        '''
WITH ld AS (SELECT number_of_days FROM logged_days)
SELECT p.id,
       p.display_string AS item_name,
       CAST(p.display_order AS INTEGER) AS display_order,
       1.0 * COALESCE(SUM(CASE
           WHEN t.timestamp_utc >= datetime('now', printf('-%d days', (SELECT number_of_days FROM ld)))
            AND t.timestamp_utc < datetime('now', '+1 day')
           THEN t.quantity
           ELSE 0 END), 0) / (SELECT number_of_days FROM ld) AS daily_avg
FROM items p
LEFT JOIN item_transactions t ON t.item_id = p.id
WHERE COALESCE(p.show_item, 1) != 0
GROUP BY p.id, p.display_string, display_order
ORDER BY display_order, p.id
''',
      );

      return rows.map((row) {
        final name = row['item_name']?.toString() ?? '';
        final rawAvg = row['daily_avg'];
        final avg = (rawAvg is num)
            ? rawAvg.toDouble()
            : double.tryParse(rawAvg?.toString() ?? '0') ?? 0.0;
        return _AvgRow(name, avg);
      }).toList();
    });
  }

  // ───────────────────────── Time zones ─────────────────────────

  /// Returns display strings like "MT/MST/MDT" grouped by tz_name.
  Future<List<String>> listTzAliasStrings() async {
    final db = await open();
    final groups = await _listTzAliasGroupsFromDb(db);
    final out = groups.map((g) => g.display).toList()..sort();
    return out;
  }

  Future<void> setActiveTzByAlias(String alias) async {
    final db = await open();

    final rows = await db.rawQuery(
      'SELECT id FROM time_zone_aliases WHERE UPPER(alias) = UPPER(?) LIMIT 1',
      [alias],
    );

    if (rows.isEmpty || rows.first['id'] == null) {
      throw ArgumentError('Unknown time zone alias: $alias');
    }

    final rawId = rows.first['id'];
    final id = (rawId is num)
        ? rawId.toInt()
        : int.parse(rawId.toString());

    final updated = await db.update(
      'settings',
      {'value': id.toString()},
      where: 'key = ?',
      whereArgs: ['time_zone_id'],
    );

    if (updated == 0) {
      await db.insert(
        'settings',
        {
          'key': 'time_zone_id',
          'value': id.toString(),
        },
      );
    }
  }

  Future<_Tz?> readActiveTz() async {
    return _timed('readActiveTz()', () async {
      final db = await open();
      return _readActiveTzFromDb(db);
    });
  }

  /// Returns the full alias string (e.g., "MT/MST/MDT") for the active time zone.
  /// Falls back to "UTC" if not configured.
  Future<String> readActiveTzAliasString() async {
    final db = await open();
    final active = await _readActiveTzFromDb(db);
    if (active == null) {
      return 'UTC';
    }

    final groups = await _listTzAliasGroupsFromDb(db);
    for (final g in groups) {
      if (g.aliases.contains(active.alias)) {
        return g.display;
      }
    }

    return active.alias;
  }

  Future<String> interpretTzAliasInput(String rawInput) async {
    final db = await open();
    final input = rawInput.trim();
    if (input.isEmpty) {
      throw ArgumentError('empty time zone alias input');
    }

    final groups = await _listTzAliasGroupsFromDb(db);

    if (input.contains('/')) {
      final normalized = input.replaceAll(' ', '').toUpperCase();
      for (final g in groups) {
        final groupNorm = g.display.replaceAll(' ', '').toUpperCase();
        if (groupNorm == normalized) {
          if (g.aliases.isNotEmpty) {
            return g.aliases.first;
          }
          break;
        }
      }
      throw ArgumentError('unknown time zone alias group: $rawInput');
    }

    final target = input.toUpperCase();
    for (final g in groups) {
      for (final alias in g.aliases) {
        if (alias.toUpperCase() == target) {
          if (g.aliases.isEmpty) {
            throw ArgumentError('time zone group for alias $rawInput has no canonical alias');
          }
          return g.aliases.first;
        }
      }
    }

    throw ArgumentError('unknown time zone alias: $rawInput');
  }

  // ───────────────────────── Timestamps ─────────────────────────

  /// Convert a local wall-clock timestamp (in the active time zone)
  /// to a UTC DB timestamp "YYYY-MM-DD HH:MM:SS".
  Future<String> localToUtcDbTimestamp(String localTs) async {
    final db = await open();
    final tzName = await _activeTzNameOrUtcFromDb(db);

    tz.Location loc;
    try {
      loc = tz.getLocation(tzName);
    } catch (_) {
      loc = tz.getLocation('Etc/UTC');
    }

    final naive = _parseNaiveTimestamp(localTs);
    final local = tz.TZDateTime(
      loc,
      naive.year,
      naive.month,
      naive.day,
      naive.hour,
      naive.minute,
      naive.second,
    );

    if (local.year != naive.year ||
        local.month != naive.month ||
        local.day != naive.day ||
        local.hour != naive.hour ||
        local.minute != naive.minute ||
        local.second != naive.second) {
      throw ArgumentError('invalid local timestamp $localTs in zone $tzName');
    }

    return _formatDbTimestamp(local.toUtc());
  }

  /// Convert a UTC DB timestamp "YYYY-MM-DD HH:MM:SS" to local wall-clock
  /// time in the active time zone, also as "YYYY-MM-DD HH:MM:SS".
  Future<String> utcDbToLocalTimestamp(String utcTs) async {
    final db = await open();
    final tzName = await _activeTzNameOrUtcFromDb(db);

    tz.Location loc;
    try {
      loc = tz.getLocation(tzName);
    } catch (_) {
      loc = tz.getLocation('Etc/UTC');
    }

    final utc = parseDbUtc(utcTs);
    final local = tz.TZDateTime.from(utc, loc);
    return _formatDbTimestamp(local);
  }

  // ───────────────────────── Transactions: insert / undo / redo ─────────────────────────

  /// Insert entries (at a given UTC timestamp, or now if null) and return their new row IDs.
  Future<List<int>> insertManyAtUtcReturningIds(
      List<_Entry> entries, String? utcIso) async {
    if (entries.isEmpty) {
      return const [];
    }

    for (final entry in entries) {
      if (entry.qty <= 0) {
        throw ArgumentError('quantity must be > 0');
      }
    }

    final db = await open();

    return db.transaction((txn) async {
      final ids = <int>[];

      if (utcIso != null) {
        for (final entry in entries) {
          final id = await txn.rawInsert(
            'INSERT INTO item_transactions (item_id, quantity, timestamp_utc) VALUES (?, ?, ?)',
            [entry.itemId, entry.qty, utcIso],
          );
          ids.add(id);
        }
      } else {
        for (final entry in entries) {
          final id = await txn.rawInsert(
            'INSERT INTO item_transactions (item_id, quantity, timestamp_utc) VALUES (?, ?, CURRENT_TIMESTAMP)',
            [entry.itemId, entry.qty],
          );
          ids.add(id);
        }
      }

      return ids;
    });
  }

  Future<_TxnSnapshot?> readTransactionById(int id) async {
    final db = await open();
    final rows = await db.rawQuery(
      '''
SELECT item_id, quantity, timestamp_utc
FROM item_transactions
WHERE id = ?1
LIMIT 1
''',
      [id],
    );
    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    final itemIdRaw = row['item_id'];
    final qtyRaw = row['quantity'];
    final tsRaw = row['timestamp_utc'];

    if (itemIdRaw == null || qtyRaw == null || tsRaw == null) {
      return null;
    }

    final itemId = (itemIdRaw is num) ? itemIdRaw.toInt() : int.parse(itemIdRaw.toString());
    final qty = (qtyRaw is num) ? qtyRaw.toInt() : int.parse(qtyRaw.toString());
    final ts = tsRaw.toString();

    return _TxnSnapshot(itemId, qty, ts);
  }

  Future<void> deleteTransactionById(int id) async {
    final db = await open();
    await db.delete(
      'item_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Query transactions by optional UTC range; null bounds are open.
  /// Results ordered by timestamp_utc DESC (implemented in Rust).
  Future<List<_TxRow>> queryTransactionsUtcRange({
    String? startUtc,
    String? endUtc,
  }) async {
    final db = await open();
    return _queryTransactionsUtcRangeDb(
      db,
      startUtc: startUtc,
      endUtc: endUtc,
    );
  }

  Future<List<_TxRow>> queryTransactionsToday() async {
    final db = await open();
    final tzName = await _activeTzNameOrUtcFromDb(db);

    tz.Location loc;
    try {
      loc = tz.getLocation(tzName);
    } catch (_) {
      loc = tz.getLocation('Etc/UTC');
    }

    final nowLocal = tz.TZDateTime.now(loc);
    final startLocal = '${nowLocal.year.toString().padLeft(4, '0')}-${_two(nowLocal.month)}-${_two(nowLocal.day)} 00:00:00';
    final tomorrow = nowLocal.add(const Duration(days: 1));
    final endLocal = '${tomorrow.year.toString().padLeft(4, '0')}-${_two(tomorrow.month)}-${_two(tomorrow.day)} 00:00:00';

    final startUtc = await localToUtcDbTimestamp(startLocal);
    final endUtc = await localToUtcDbTimestamp(endLocal);

    return _queryTransactionsUtcRangeDb(
      db,
      startUtc: startUtc,
      endUtc: endUtc,
    );
  }

  Future<List<_TxRow>> queryTransactionsLastNDays(int days) async {
    final db = await open();
    final safeDays = days <= 0 ? 1 : days;
    final tzName = await _activeTzNameOrUtcFromDb(db);

    tz.Location loc;
    try {
      loc = tz.getLocation(tzName);
    } catch (_) {
      loc = tz.getLocation('Etc/UTC');
    }

    final endLocal = tz.TZDateTime.now(loc);
    final startLocal = endLocal.subtract(Duration(days: safeDays));

    final startUtc = await localToUtcDbTimestamp(_formatDbTimestamp(startLocal));
    final endUtc = await localToUtcDbTimestamp(_formatDbTimestamp(endLocal));

    return _queryTransactionsUtcRangeDb(
      db,
      startUtc: startUtc,
      endUtc: endUtc,
    );
  }

  Future<List<_TxRow>> queryTransactionsRangeLocal({
    String? startLocal,
    String? endLocal,
  }) async {
    final db = await open();

    final startUtc = startLocal == null ? null : await localToUtcDbTimestamp(startLocal);
    final endUtc = endLocal == null ? null : await localToUtcDbTimestamp(endLocal);

    return _queryTransactionsUtcRangeDb(
      db,
      startUtc: startUtc,
      endUtc: endUtc,
    );
  }

  Future<List<_TxRow>> queryTransactionsAll() async {
    final db = await open();
    return _queryTransactionsUtcRangeDb(db);
  }

  // Logical batch insert / undo / redo via backend

  Future<String> insertBatchWithUndoToken(
      List<_Entry> entries, String? utcIso) async {
    await _validateEntriesForBatchInsert(entries);

    final db = await open();

    return db.transaction((txn) async {
      final (batchId, token) = await _createPendingBatch(txn);

      if (utcIso != null) {
        await _insertBatchItemsWithLiteralTimestamp(
          txn,
          batchId,
          entries,
          utcIso,
        );
      } else {
        await _insertBatchItemsWithCurrentTimestamp(
          txn,
          batchId,
          entries,
        );
      }

      return token;
    });
  }

  Future<List<int>> undoLogicalBatch(String token) async {
    final db = await open();

    return db.transaction((txn) async {
      final batchId = await _loadBatchIdForUndo(txn, token);
      final txIds = await _loadBatchTransactionIds(txn, batchId);
      await _deleteBatchTransactions(txn, token, txIds);
      await _markBatchUndone(txn, batchId);
      return txIds;
    });
  }

  Future<List<int>> redoLogicalBatch(String token) async {
    final db = await open();

    return db.transaction((txn) async {
      final batchId = await _loadBatchIdForRedo(txn, token);
      final items = await _loadBatchRedoItems(txn, batchId);
      final newIds = await _reinsertBatchTransactions(txn, token, items);
      await _markBatchRedone(txn, batchId);
      return newIds;
    });
  }

  // ───────────────────────── Schema introspection ─────────────────────────

  Future<List<_SchemaObject>> readSchemaObjects() async {
    final db = await open();
    final rows = await db.rawQuery('''
SELECT
  type,
  name,
  tbl_name,
  sql
FROM sqlite_master
WHERE type IN ('table', 'view')
  AND name NOT LIKE 'sqlite_%'
ORDER BY
  CASE type
    WHEN 'table' THEN 0
    WHEN 'view' THEN 1
    ELSE 2
  END,
  name
''');

    return rows.map((row) {
      final type = row['type']?.toString() ?? '';
      final name = row['name']?.toString() ?? '';
      final tableName = row['tbl_name']?.toString() ?? '';
      final sql = row['sql']?.toString() ?? '';
      return _SchemaObject(type, name, tableName, sql);
    }).toList();
  }

  // ───────────────────────── sqflite escape hatch ─────────────────────────

  // Only kept for cases where we truly do not have an FFI helper yet.
  Future<List<Map<String, Object?>>> rawQuery(
      String sql, [
        List<Object?>? arguments,
      ]) async {
    final db = await open();
    return db.rawQuery(sql, arguments);
  }
} // class _Db

// <editor-fold desc="misc. DTOs">
class _Item {
  final int id;
  final String name;
  final int? displayOrder;
  final bool showItem;

  _Item(this.id, this.name, this.displayOrder, this.showItem);
}

class _AvgRow {
  final String itemName;
  final double avg;
  _AvgRow(this.itemName, this.avg);
}

class _Entry {
  final int itemId;
  final int qty;
  _Entry(this.itemId, this.qty);
}

class _TxRow {
  final int id;        // DB primary key
  final DateTime utc;  // stored in UTC
  final String item;
  final int qty;

  const _TxRow(this.id, this.utc, this.item, this.qty);
}

class _TxnSnapshot {
  final int itemId;
  final int qty;
  final String utcIso; // "YYYY-MM-DD HH:MM:SS" UTC
  _TxnSnapshot(this.itemId, this.qty, this.utcIso);
}

class _SchemaObject {
  final String type;
  final String name;
  final String tableName;
  final String sql;

  _SchemaObject(this.type, this.name, this.tableName, this.sql);
}

class _TzAliasGroup {
  final String tzName;
  final String display;
  final List<String> aliases;

  _TzAliasGroup(this.tzName, this.display, this.aliases);
}

class _Tz {
  final String alias;
  final String tzName; // IANA tz database name, e.g., "America/Denver"
  _Tz(this.alias, this.tzName);
}
// </editor-fold>