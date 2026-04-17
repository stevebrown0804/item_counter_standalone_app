// db.dart

part of 'main.dart';

DateTime parseDbUtc(String s) {
  final base = s.replaceFirst(' ', 'T');
  final iso = base.endsWith('+00:00') ? base.replaceFirst('+00:00', 'Z') : '${base}Z';

  return DateTime.parse(iso).toUtc();
}

// ── the DB wrapper (sqflite + Rust FFI) ──
class _Db {
  Database? _db;
  Future<Database>? _openFuture;

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

  Future<void> _ensureFfiReady() async {
    await open();
  }

  Future<Database> open() async {
    if (_db != null) return _db!;

    final existing = _openFuture;
    if (existing != null) {
      return existing;
    }

    final future = _timed('openDatabase()', () async {
      final full = await _dbPath();
      final opened = await openDatabase(full);
      await _ensureSchema(opened);
      await _FfiBackend.instance.init(full);
      _db = opened;
      return opened;
    });

    _openFuture = future;

    try {
      return await future;
    } finally {
      _openFuture = null;
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

  // ───────────────────────── Items ─────────────────────────

  Future<List<_Item>> listItemsOrdered() async {
    return _timed('listItemsOrdered()', () async {
      await _ensureFfiReady();
      return _FfiBackend.instance.listItems();
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
      await _ensureFfiReady();
      return _FfiBackend.instance.readAveragingWindowDays();
    });
  }

  Future<void> setAveragingWindowDays(int days) async {
    await _ensureFfiReady();
    await _FfiBackend.instance.setAveragingWindowDays(days);
  }

  /// Compute the averaging window (in days) based on a picked local calendar date
  /// string "YYYY-MM-DD" in the active time zone.
  Future<int> computeAveragingWindowDaysFromPickedLocalDate(
      String localDateYmd) async {
    await _ensureFfiReady();
    return _FfiBackend.instance
        .computeAveragingWindowDaysFromPickedLocalDate(localDateYmd);
  }

  /// Oldest transaction date in the active time zone, truncated to a
  /// calendar date (year-month-day). Returns null if there are no transactions.
  Future<DateTime?> readOldestTransactionLocalDate() async {
    await _ensureFfiReady();

    // Oldest transaction in UTC from the Rust backend.
    final oldestUtc = await _FfiBackend.instance.readOldestTransactionUtc();
    if (oldestUtc == null) {
      return null;
    }

    // Determine active time zone; default to Etc/UTC if unset or invalid.
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
    // Truncate to calendar date.
    return DateTime(local.year, local.month, local.day);
  }

  // ───────────────────────── Settings: skip second confirmation ─────────────────────────

  Future<bool> readSkipDeleteSecondConfirm() async {
    await _ensureFfiReady();
    return _FfiBackend.instance.readSkipDeleteSecondConfirm();
  }

  Future<void> setSkipDeleteSecondConfirm(bool skip) async {
    await _ensureFfiReady();
    await _FfiBackend.instance.setSkipDeleteSecondConfirm(skip);
  }

  // ───────────────────────── Transactions: archive/delete ─────────────────────────

  Future<int> deleteTransactionsOlderThanDays(int days) async {
    await _ensureFfiReady();
    return _FfiBackend.instance.deleteTransactionsOlderThanDays(days);
  }

  Future<int> countTransactionsOlderThanDays(int days) async {
    await _ensureFfiReady();
    return _FfiBackend.instance.countTransactionsOlderThanDays(days);
  }

  Future<int> deleteOldTransactionsWithPolicy(int days) async {
    await _ensureFfiReady();
    return _FfiBackend.instance.deleteOldTransactionsWithPolicy(days);
  }

  // ───────────────────────── Averages ─────────────────────────

  Future<List<_AvgRow>> readDailyAverages() async {
    return _timed('readDailyAverages()', () async {
      await _ensureFfiReady();
      return _FfiBackend.instance.readDailyAverages();
    });
  }

  // ───────────────────────── Time zones ─────────────────────────

  /// Returns display strings like "MT/MST/MDT" grouped by tz_name.
  Future<List<String>> listTzAliasStrings() async {
    await _ensureFfiReady();
    return _FfiBackend.instance.listTzAliasStrings();
  }

  Future<void> setActiveTzByAlias(String alias) async {
    await _ensureFfiReady();
    await _FfiBackend.instance.setActiveTzByAlias(alias);
  }

  Future<_Tz?> readActiveTz() async {
    return _timed('readActiveTz()', () async {
      await _ensureFfiReady();
      return _FfiBackend.instance.readActiveTz();
    });
  }

  /// Returns the full alias string (e.g., "MT/MST/MDT") for the active time zone.
  /// Falls back to "UTC" if not configured.
  Future<String> readActiveTzAliasString() async {
    await _ensureFfiReady();
    return _FfiBackend.instance.readActiveTzAliasString();
  }

  Future<String> interpretTzAliasInput(String rawInput) async {
    await _ensureFfiReady();
    return _FfiBackend.instance.interpretTzAliasInput(rawInput);
  }

  // ───────────────────────── Timestamps ─────────────────────────

  /// Convert a local wall-clock timestamp (in the active time zone)
  /// to a UTC DB timestamp "YYYY-MM-DD HH:MM:SS".
  Future<String> localToUtcDbTimestamp(String localTs) async {
    await _ensureFfiReady();
    return _FfiBackend.instance.localToUtcDbTimestamp(localTs);
  }

  /// Convert a UTC DB timestamp "YYYY-MM-DD HH:MM:SS" to local wall-clock
  /// time in the active time zone, also as "YYYY-MM-DD HH:MM:SS".
  Future<String> utcDbToLocalTimestamp(String utcTs) async {
    await _ensureFfiReady();
    return _FfiBackend.instance.utcDbToLocalTimestamp(utcTs);
  }

  // ───────────────────────── Transactions: insert / undo / redo ─────────────────────────

  /// Insert entries (at a given UTC timestamp, or now if null) and return their new row IDs.
  Future<List<int>> insertManyAtUtcReturningIds(
      List<_Entry> entries, String? utcIso) async {
    await _ensureFfiReady();
    return _FfiBackend.instance.insertManyAtUtcReturningIds(entries, utcIso);
  }

  Future<_TxnSnapshot?> readTransactionById(int id) async {
    await _ensureFfiReady();
    return _FfiBackend.instance.readTransactionById(id);
  }

  Future<void> deleteTransactionById(int id) async {
    await _ensureFfiReady();
    await _FfiBackend.instance.deleteTransactionById(id);
  }

  /// Query transactions by optional UTC range; null bounds are open.
  /// Results ordered by timestamp_utc DESC (implemented in Rust).
  Future<List<_TxRow>> queryTransactionsUtcRange({
    String? startUtc,
    String? endUtc,
  }) async {
    await _ensureFfiReady();
    return _FfiBackend.instance.queryTransactionsUtcRange(
      startUtc: startUtc,
      endUtc: endUtc,
    );
  }

  Future<List<_TxRow>> queryTransactionsToday() async {
    await _ensureFfiReady();
    return _FfiBackend.instance.queryTransactionsToday();
  }

  Future<List<_TxRow>> queryTransactionsLastNDays(int days) async {
    await _ensureFfiReady();
    return _FfiBackend.instance.queryTransactionsLastNDays(days);
  }

  Future<List<_TxRow>> queryTransactionsRangeLocal({
    String? startLocal,
    String? endLocal,
  }) async {
    await _ensureFfiReady();
    return _FfiBackend.instance.queryTransactionsRangeLocal(
      startLocal: startLocal,
      endLocal: endLocal,
    );
  }

  Future<List<_TxRow>> queryTransactionsAll() async {
    await _ensureFfiReady();
    return _FfiBackend.instance.queryTransactionsAll();
  }

  // Logical batch insert / undo / redo via backend

  Future<String> insertBatchWithUndoToken(
      List<_Entry> entries, String? utcIso) async {
    await _ensureFfiReady();
    return _FfiBackend.instance.insertBatchWithUndoToken(entries, utcIso);
  }

  Future<List<int>> undoLogicalBatch(String token) async {
    await _ensureFfiReady();
    return _FfiBackend.instance.undoLogicalBatch(token);
  }

  Future<List<int>> redoLogicalBatch(String token) async {
    await _ensureFfiReady();
    return _FfiBackend.instance.redoLogicalBatch(token);
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

class _Tz {
  final String alias;
  final String tzName; // IANA tz database name, e.g., "America/Denver"
  _Tz(this.alias, this.tzName);
}
// </editor-fold>