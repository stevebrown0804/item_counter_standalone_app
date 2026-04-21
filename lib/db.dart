// db.dart

part of 'main.dart';

// ── the DB wrapper ──
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
      final opened = await openDatabase(
        full,
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _ensureSchema(db);
        },
      );
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

  String _normalizeSchemaSql(String sql) {
    return sql
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<List<_SchemaObject>> _readSchemaObjectsFromDb(Database db) async {
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

  Future<String> validateImportDatabaseSchema(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return 'settings - Incompatible - selected file does not exist.\n'
          'items - Incompatible - selected file does not exist.\n'
          'item transactions - Incompatible - selected file does not exist.\n'
          'time zones - Incompatible - selected file does not exist.';
    }

    Database? candidateDb;
    try {
      candidateDb = await openDatabase(
        path,
        readOnly: true,
        singleInstance: false,
      );
    } catch (e) {
      return 'settings - Incompatible - could not be opened as a SQLite database: $e\n'
          'items - Incompatible - could not be opened as a SQLite database: $e\n'
          'item transactions - Incompatible - could not be opened as a SQLite database: $e\n'
          'time zones - Incompatible - could not be opened as a SQLite database: $e';
    }

    try {
      final liveSchema = await readSchemaObjects();
      final candidateSchema = await _readSchemaObjectsFromDb(candidateDb);

      final liveByName = <String, _SchemaObject>{};
      for (final obj in liveSchema) {
        if (obj.type == 'table') {
          liveByName[obj.name] = obj;
        }
      }

      final candidateByName = <String, _SchemaObject>{};
      for (final obj in candidateSchema) {
        if (obj.type == 'table') {
          candidateByName[obj.name] = obj;
        }
      }

      String compareTable(String actualName, String friendlyName) {
        final expected = liveByName[actualName];
        final actual = candidateByName[actualName];

        if (expected == null) {
          return '$friendlyName - Incompatible - app database is missing table $actualName';
        }
        if (actual == null) {
          return '$friendlyName - Incompatible - missing table $actualName';
        }
        if (expected.tableName != actual.tableName) {
          return '$friendlyName - Incompatible - tbl_name differs';
        }

        final expectedSql = _normalizeSchemaSql(expected.sql);
        final actualSql = _normalizeSchemaSql(actual.sql);
        if (expectedSql != actualSql) {
          return '$friendlyName - Incompatible - schema differs';
        }

        return '$friendlyName - OK';
      }

      return [
        compareTable('settings', 'settings'),
        compareTable('items', 'items'),
        compareTable('item_transactions', 'item transactions'),
        compareTable('time_zone_aliases', 'time zones'),
      ].join('\n');
    } catch (e) {
      return 'settings - Incompatible - schema check failed: $e\n'
          'items - Incompatible - schema check failed: $e\n'
          'item transactions - Incompatible - schema check failed: $e\n'
          'time zones - Incompatible - schema check failed: $e';
    } finally {
      await candidateDb.close();
    }
  }

  Future<List<_SchemaObject>> readSchemaObjects() async {
    final db = await open();
    return _readSchemaObjectsFromDb(db);
  }

  Future<List<Map<String, Object?>>> rawQuery(
      String sql, [
        List<Object?>? arguments,
      ]) async {
    final db = await open();
    return db.rawQuery(sql, arguments);
  }
}