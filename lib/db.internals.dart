part of 'main.dart';

extension _DbInternals on _Db {
  Future<void> _ensureSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS items (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    display_string  TEXT UNIQUE NOT NULL,
    display_order   INTEGER UNIQUE,
    show_item       INTEGER NOT NULL DEFAULT (1),
    is_header       INTEGER NOT NULL DEFAULT (0)
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

    final defaultPinnedStartDate = _AppDateLogic.formatDashDate(DateTime.now());

    await _ensureSettingDefault(db, 'avg_window_days', '30');
    await _ensureSettingDefault(db, 'daily_average.number_of_days_ago', '30');
    await _ensureSettingDefault(db, 'daily_average.start_date', defaultPinnedStartDate);
    await _ensureSettingDefault(db, 'daily_average.end_date', '');
    await _ensureSettingDefault(db, 'daily_average.pin_start_date', '1');
    await _ensureSettingDefault(db, 'daily_average.pin_end_date', '0');
    await _ensureSettingDefault(db, 'skip_delete_transactions_second_dialog_confirmation', '0');
    await _ensureSettingDefault(db, 'settings.return_home_after_interaction', '0');
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
    await _ensureSettingDefault(db, 'settings.return_home_after_interaction', '0');
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

  //DB migration functions

  Future<void> _migrateExistingDatabaseSchema(Database db) async {
    final migrationNeeded = await _currentSchemaTextMigrationNeeded(db);
    if (!migrationNeeded) {
      return;
    }

    final itemsTableHasIsHeader = await _itemsTableHasIsHeaderColumn(db);

    await _assertItemsDisplayOrderCanBecomeUnique(db);

    await db.execute('PRAGMA foreign_keys = OFF');

    try {
      await db.transaction((txn) async {
        await _dropLegacyDerivedViewsForSchemaMigration(txn);
        await _dropSchemaMigrationBackupTables(txn);

        if (itemsTableHasIsHeader) {
          await txn.execute('''
CREATE TABLE items__schema_migration_backup AS
SELECT id, display_string, display_order, show_item, is_header
FROM items
''');
        } else {
          await txn.execute('''
CREATE TABLE items__schema_migration_backup AS
SELECT id, display_string, display_order, show_item, 0 AS is_header
FROM items
''');
        }

        await txn.execute('''
CREATE TABLE item_transactions__schema_migration_backup AS
SELECT id, item_id, quantity, timestamp_utc
FROM item_transactions
''');

        await txn.execute('''
CREATE TABLE time_zone_aliases__schema_migration_backup AS
SELECT id, alias, iana_tz_name
FROM time_zone_aliases
''');

        await txn.execute('''
CREATE TABLE logical_batch_items__schema_migration_backup AS
SELECT id, batch_id, transaction_id, item_id, quantity, timestamp_utc
FROM logical_batch_items
''');

        await txn.execute('DROP TABLE logical_batch_items');
        await txn.execute('DROP TABLE item_transactions');
        await txn.execute('DROP TABLE time_zone_aliases');
        await txn.execute('DROP TABLE items');

        await txn.execute('''
CREATE TABLE items (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    display_string  TEXT UNIQUE NOT NULL,
    display_order   INTEGER UNIQUE,
    show_item       INTEGER NOT NULL DEFAULT (1),
    is_header       INTEGER NOT NULL DEFAULT (0)
)
''');

        await txn.execute('''
CREATE TABLE item_transactions (
    id            INTEGER  PRIMARY KEY,
    item_id       INTEGER  NOT NULL,
    quantity      INTEGER  NOT NULL CHECK (quantity > 0),
    timestamp_utc DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (item_id) REFERENCES items (id)
)
''');

        await txn.execute('''
CREATE TABLE time_zone_aliases (
    id           INTEGER PRIMARY KEY,
    alias        TEXT NOT NULL UNIQUE,
    iana_tz_name TEXT NOT NULL
)
''');

        await txn.execute('''
CREATE TABLE logical_batch_items (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_id       INTEGER NOT NULL,
    transaction_id INTEGER NOT NULL,
    item_id        INTEGER NOT NULL,
    quantity       INTEGER NOT NULL,
    timestamp_utc  DATETIME NOT NULL,
    FOREIGN KEY (batch_id) REFERENCES logical_batches(id)
)
''');

        await txn.execute('''
INSERT INTO items (id, display_string, display_order, show_item, is_header)
SELECT id, display_string, display_order, show_item, is_header
FROM items__schema_migration_backup
ORDER BY id
''');

        await txn.execute('''
INSERT INTO item_transactions (id, item_id, quantity, timestamp_utc)
SELECT id, item_id, quantity, timestamp_utc
FROM item_transactions__schema_migration_backup
ORDER BY id
''');

        await txn.execute('''
INSERT INTO time_zone_aliases (id, alias, iana_tz_name)
SELECT id, alias, iana_tz_name
FROM time_zone_aliases__schema_migration_backup
ORDER BY id
''');

        await txn.execute('''
INSERT INTO logical_batch_items (id, batch_id, transaction_id, item_id, quantity, timestamp_utc)
SELECT id, batch_id, transaction_id, item_id, quantity, timestamp_utc
FROM logical_batch_items__schema_migration_backup
ORDER BY id
''');

        await _dropSchemaMigrationBackupTables(txn);
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }

    final foreignKeyProblems = await db.rawQuery('PRAGMA foreign_key_check');
    if (foreignKeyProblems.isNotEmpty) {
      throw StateError(
        'Foreign key check failed after schema migration: $foreignKeyProblems',
      );
    }
  }

  Future<bool> _currentSchemaTextMigrationNeeded(Database db) async {
    final expectedSqlByTableName = <String, String>{
      'items': '''
CREATE TABLE items (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    display_string  TEXT UNIQUE NOT NULL,
    display_order   INTEGER UNIQUE,
    show_item       INTEGER NOT NULL DEFAULT (1),
    is_header       INTEGER NOT NULL DEFAULT (0)
)
''',
      'item_transactions': '''
CREATE TABLE item_transactions (
    id            INTEGER  PRIMARY KEY,
    item_id       INTEGER  NOT NULL,
    quantity      INTEGER  NOT NULL CHECK (quantity > 0),
    timestamp_utc DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (item_id) REFERENCES items (id)
)
''',
      'time_zone_aliases': '''
CREATE TABLE time_zone_aliases (
    id           INTEGER PRIMARY KEY,
    alias        TEXT NOT NULL UNIQUE,
    iana_tz_name TEXT NOT NULL
)
''',
      'logical_batch_items': '''
CREATE TABLE logical_batch_items (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    batch_id       INTEGER NOT NULL,
    transaction_id INTEGER NOT NULL,
    item_id        INTEGER NOT NULL,
    quantity       INTEGER NOT NULL,
    timestamp_utc  DATETIME NOT NULL,
    FOREIGN KEY (batch_id) REFERENCES logical_batches(id)
)
''',
    };

    for (final entry in expectedSqlByTableName.entries) {
      final rows = await db.rawQuery(
        '''
SELECT sql
FROM sqlite_master
WHERE type = 'table'
  AND name = ?1
LIMIT 1
''',
        [entry.key],
      );

      if (rows.isEmpty || rows.first['sql'] == null) {
        throw StateError('Required table ${entry.key} is missing.');
      }

      final actualSql = rows.first['sql'].toString();
      final expectedSql = entry.value;

      if (_normalizeSchemaSql(actualSql) != _normalizeSchemaSql(expectedSql)) {
        return true;
      }
    }

    return false;
  }

  Future<void> _assertItemsDisplayOrderCanBecomeUnique(Database db) async {
    final duplicateRows = await db.rawQuery(
      '''
SELECT display_order, COUNT(*) AS duplicate_count
FROM items
WHERE display_order IS NOT NULL
GROUP BY display_order
HAVING COUNT(*) > 1
LIMIT 1
''',
    );

    if (duplicateRows.isNotEmpty) {
      throw StateError(
        'Cannot migrate items.display_order to UNIQUE because duplicate display_order values exist: $duplicateRows',
      );
    }
  }

  Future<void> _dropLegacyDerivedViewsForSchemaMigration(DatabaseExecutor db) async {
    await db.execute('DROP VIEW IF EXISTS "Transactions_(Mtn Time)"');
    await db.execute('DROP VIEW IF EXISTS daily_avg_by_pill_UTC');
    await db.execute('DROP VIEW IF EXISTS logged_days');
  }

  Future<void> _dropSchemaMigrationBackupTables(DatabaseExecutor db) async {
    await db.execute('DROP TABLE IF EXISTS logical_batch_items__schema_migration_backup');
    await db.execute('DROP TABLE IF EXISTS time_zone_aliases__schema_migration_backup');
    await db.execute('DROP TABLE IF EXISTS item_transactions__schema_migration_backup');
    await db.execute('DROP TABLE IF EXISTS items__schema_migration_backup');
  }

  //end DB migration functions

  Future<int> _computeEffectiveAveragingWindowDaysFromDb(Database db) async {
    final range = await _computeEffectiveAveragingWindowRangeFromDb(db);
    return range.days;
  }

  Future<({int days, double averageDenominatorDays, String startUtc, String endUtc})> _computeEffectiveAveragingWindowRangeFromDb(Database db) async {
    const secondsPerDay = Duration.secondsPerDay;
    const minimumElapsedSeconds = 1;
    const currentMomentInclusivePadding = Duration(seconds: 1);

    final settings = await _readDailyAverageSettingsFromDb(db);
    final tzName = await _activeTzNameOrUtcFromDb(db);
    final loc = _AppDateLogic.locationOrUtc(tzName);
    final today = _AppDateLogic.todayDateOnly(tzName);
    final nowLocal = tz.TZDateTime.now(loc);

    late final DateTime startDate;
    late final tz.TZDateTime startLocal;

    if (settings.pinStartDate) {
      final storedStart = _AppDateLogic.parseStoredDateOrTimestamp(settings.startDate);
      if (storedStart == null) {
        startDate = _AppDateLogic.startDateFromDaysAgo(
          daysAgo: settings.numberOfDaysAgo,
          tzName: tzName,
        );
      } else {
        startDate = _AppDateLogic.dateOnly(storedStart);
      }
    } else {
      startDate = _AppDateLogic.startDateFromDaysAgo(
        daysAgo: settings.numberOfDaysAgo,
        tzName: tzName,
      );
    }

    startLocal = tz.TZDateTime(
      loc,
      startDate.year,
      startDate.month,
      startDate.day,
    );

    DateTime endDate;
    if (settings.pinEndDate) {
      final storedEnd = _AppDateLogic.parseStoredDateOrTimestamp(settings.endDate);
      endDate = storedEnd == null ? today : _AppDateLogic.dateOnly(storedEnd);
    } else {
      endDate = today;
    }

    if (endDate.isBefore(startDate)) {
      endDate = startDate;
    }

    final days = _AppDateLogic.positiveElapsedDays(
      startDate: startDate,
      endDate: endDate,
    );

    late final tz.TZDateTime rangeEndLocalExclusive;
    late final tz.TZDateTime averageDenominatorEndLocal;

    if (endDate.isBefore(today)) {
      final endExclusiveDate = endDate.add(const Duration(days: 1));
      rangeEndLocalExclusive = tz.TZDateTime(
        loc,
        endExclusiveDate.year,
        endExclusiveDate.month,
        endExclusiveDate.day,
      );
      averageDenominatorEndLocal = rangeEndLocalExclusive;
    } else {
      rangeEndLocalExclusive = nowLocal.add(currentMomentInclusivePadding);
      averageDenominatorEndLocal = nowLocal;
    }

    final elapsedSeconds =
        averageDenominatorEndLocal.difference(startLocal).inSeconds;
    final safeElapsedSeconds =
    elapsedSeconds < minimumElapsedSeconds ? minimumElapsedSeconds : elapsedSeconds;
    final averageDenominatorDays = safeElapsedSeconds / secondsPerDay;

    debugPrint(
      '[AVG-RANGE] tzName=$tzName, '
          'today=${_AppDateLogic.formatSlashDate(today)}, '
          'startDate=${_AppDateLogic.formatSlashDate(startDate)}, '
          'endDate=${_AppDateLogic.formatSlashDate(endDate)}, '
          'pinStartDate=${settings.pinStartDate}, '
          'pinEndDate=${settings.pinEndDate}, '
          'storedNumberOfDaysAgo=${settings.numberOfDaysAgo}, '
          'displayDays=$days, '
          'averageDenominatorDays=$averageDenominatorDays',
    );

    debugPrint(
      '[AVG-RANGE] startUtc=${_formatDbTimestamp(startLocal.toUtc())}, '
          'endUtc=${_formatDbTimestamp(rangeEndLocalExclusive.toUtc())}',
    );

    return (
    days: days,
    averageDenominatorDays: averageDenominatorDays,
    startUtc: _formatDbTimestamp(startLocal.toUtc()),
    endUtc: _formatDbTimestamp(rangeEndLocalExclusive.toUtc()),
    );
  }

  Future<_DailyAverageSettings> _readDailyAverageSettingsFromDb(Database db) async {
    final rows = await db.rawQuery(
      '''
SELECT key, value
FROM settings
WHERE key IN (
  'avg_window_days',
  'daily_average.number_of_days_ago',
  'daily_average.start_date',
  'daily_average.end_date',
  'daily_average.pin_start_date',
  'daily_average.pin_end_date'
)
''',
    );

    final values = <String, String>{};
    for (final row in rows) {
      final key = row['key']?.toString();
      if (key == null || key.isEmpty) {
        continue;
      }

      values[key] = row['value']?.toString() ?? '';
    }

    int parsePositiveInt(String? raw, int fallback) {
      final parsed = int.tryParse(raw?.trim() ?? '');
      if (parsed == null || parsed <= 0) {
        return fallback;
      }

      return parsed;
    }

    bool parseStoredBool(String? raw) {
      final trimmed = raw?.trim().toLowerCase() ?? '';
      return trimmed == '1' || trimmed == 'true';
    }

    final legacyDays = parsePositiveInt(values['avg_window_days'], 30);
    final configuredDays = parsePositiveInt(
      values['daily_average.number_of_days_ago'],
      legacyDays,
    );

    return _DailyAverageSettings(
      numberOfDaysAgo: configuredDays,
      startDate: values['daily_average.start_date'] ?? '',
      endDate: values['daily_average.end_date'] ?? '',
      pinStartDate: parseStoredBool(values['daily_average.pin_start_date']),
      pinEndDate: parseStoredBool(values['daily_average.pin_end_date']),
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

  String _formatDbTimestamp(DateTime dt) {
    return _AppDateLogic.formatDbTimestamp(dt);
  }

  DateTime _parseNaiveTimestamp(String s) {
    return _AppDateLogic.parseNaiveTimestamp(s);
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

      if (idRaw == null) {
        throw StateError('Transaction query row is missing id: $row');
      }
      if (tsRaw == null) {
        throw StateError('Transaction query row is missing timestamp_utc: $row');
      }
      if (itemRaw == null) {
        throw StateError('Transaction query row is missing item_name: $row');
      }
      if (qtyRaw == null) {
        throw StateError('Transaction query row is missing quantity: $row');
      }

      final id = (idRaw is num) ? idRaw.toInt() : int.parse(idRaw.toString());
      final qty = (qtyRaw is num) ? qtyRaw.toInt() : int.parse(qtyRaw.toString());
      final utc = parseDbUtc(tsRaw.toString());
      final item = itemRaw.toString();

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

  Future<bool> _itemsTableHasIsHeaderColumn(Database db) async {
    final rows = await db.rawQuery('PRAGMA table_info(items)');
    return rows.any((row) => row['name']?.toString() == 'is_header');
  }
}
