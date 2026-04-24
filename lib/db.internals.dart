// db.internals.dart

part of 'main.dart';

extension _DbInternals on _Db {
  Future<void> _ensureSchema(Database db) async {
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

    await _ensureSettingDefault(db, 'avg_window_days', '30');
    await _ensureSettingDefault(db, 'daily_average.number_of_days_ago', '30');
    await _ensureSettingDefault(db, 'daily_average.start_date', '');
    await _ensureSettingDefault(db, 'daily_average.end_date', '');
    await _ensureSettingDefault(db, 'daily_average.pin_start_date', '0');
    await _ensureSettingDefault(db, 'daily_average.pin_end_date', '0');
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

  Future<void> _ensurePostOpenDefaults(Database db) async {
    await _ensureSettingDefault(db, 'avg_window_days', '30');

    final avgWindowRows = await db.rawQuery(
      '''
SELECT value
FROM settings
WHERE key = 'avg_window_days'
LIMIT 1
''',
    );

    String inheritedAvgWindowDays = '30';
    if (avgWindowRows.isNotEmpty) {
      final raw = avgWindowRows.first['value'];
      final parsed = raw?.toString().trim();
      if (parsed != null && parsed.isNotEmpty) {
        inheritedAvgWindowDays = parsed;
      }
    }

    final dailyAverageRows = await db.rawQuery(
      '''
SELECT value
FROM settings
WHERE key = 'daily_average.number_of_days_ago'
LIMIT 1
''',
    );

    if (dailyAverageRows.isEmpty) {
      await db.insert(
        'settings',
        {
          'key': 'daily_average.number_of_days_ago',
          'value': inheritedAvgWindowDays,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } else {
      final existingRaw = dailyAverageRows.first['value']?.toString().trim() ?? '';
      if (existingRaw == '30' && inheritedAvgWindowDays != '30') {
        await db.update(
          'settings',
          {'value': inheritedAvgWindowDays},
          where: 'key = ?',
          whereArgs: ['daily_average.number_of_days_ago'],
        );
      }
    }

    await _ensureSettingDefault(db, 'daily_average.start_date', '');
    await _ensureSettingDefault(db, 'daily_average.end_date', '');
    await _ensureSettingDefault(db, 'daily_average.pin_start_date', '0');
    await _ensureSettingDefault(db, 'daily_average.pin_end_date', '0');
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

  Future<int> _computeEffectiveAveragingWindowDaysFromDb(Database db) async {
    final cfgRows = await db.rawQuery(
      '''
SELECT value
FROM settings
WHERE key = 'avg_window_days'
LIMIT 1
''',
    );

    int configuredDays = 0;
    if (cfgRows.isNotEmpty) {
      final raw = cfgRows.first['value'];
      if (raw is num) {
        configuredDays = raw.toInt();
      } else {
        configuredDays = int.tryParse(raw?.toString() ?? '0') ?? 0;
      }
    }

    if (configuredDays <= 0) {
      return 0;
    }

    final globalRows = await db.rawQuery(
      '''
SELECT DATE('now') AS today,
       MIN(DATE(timestamp_utc)) AS min_date
FROM item_transactions
''',
    );

    if (globalRows.isEmpty) {
      return 0;
    }

    final todayRaw = globalRows.first['today']?.toString();
    final minDateRaw = globalRows.first['min_date']?.toString();

    if (todayRaw == null || todayRaw.isEmpty || minDateRaw == null || minDateRaw.isEmpty) {
      return 0;
    }

    final today = DateTime.parse(todayRaw);
    final minDate = DateTime.parse(minDateRaw);
    final configuredStart = today.subtract(Duration(days: configuredDays - 1));
    final effectiveStart = minDate.isAfter(configuredStart) ? minDate : configuredStart;
    final effectiveDays = today.difference(effectiveStart).inDays + 1;

    return effectiveDays <= 0 ? 0 : effectiveDays;
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
}