part of 'main.dart';

// <editor-fold desc="DB and data-related classes/fns">
// ───────────────────────── DB wrapper (sqflite + Rust FFI) ─────────────────────────

class _Db {
  Database? _db;

  Future<Database> open() async {
    if (_db != null) return _db!;
    final dbDir = await getDatabasesPath();
    final full = p.join(dbDir, kDbFileName);

    // Ensure Rust backend is also opened on the same DB file.
    await _FfiBackend.instance.init(full);

    // We still open via sqflite for schema compatibility and export logic.
    _db = await openDatabase(full);
    return _db!;
  }

  // ───────────────────────── Pills ─────────────────────────

  Future<List<_Pill>> listPillsOrdered() async {
    await open(); // ensures FFI is initialized
    return _FfiBackend.instance.listPills();
  }

  // ───────────────────────── Settings: averaging window ─────────────────────────

  Future<int> readAveragingWindowDays() async {
    await open();
    return _FfiBackend.instance.readAveragingWindowDays();
  }

  Future<void> setAveragingWindowDays(int days) async {
    await open();
    await _FfiBackend.instance.setAveragingWindowDays(days);
  }

  /// Compute the averaging window (in days) based on a picked local calendar date
  /// string "YYYY-MM-DD" in the active time zone. (TODO 3 wired to backend.)
  Future<int> computeAveragingWindowDaysFromPickedLocalDate(
      String localDateYmd) async {
    await open();
    return _FfiBackend.instance
        .computeAveragingWindowDaysFromPickedLocalDate(localDateYmd);
  }

  // ───────────────────────── Settings: skip second confirmation ─────────────────────────

  Future<bool> readSkipDeleteSecondConfirm() async {
    await open();
    return _FfiBackend.instance.readSkipDeleteSecondConfirm();
  }

  Future<void> setSkipDeleteSecondConfirm(bool skip) async {
    await open();
    await _FfiBackend.instance.setSkipDeleteSecondConfirm(skip);
  }

  // ───────────────────────── Transactions: archive/delete ─────────────────────────

  Future<int> deleteTransactionsOlderThanDays(int days) async {
    await open();
    return _FfiBackend.instance.deleteTransactionsOlderThanDays(days);
  }

  Future<int> countTransactionsOlderThanDays(int days) async {
    await open();
    return _FfiBackend.instance.countTransactionsOlderThanDays(days);
  }

  // ───────────────────────── Averages ─────────────────────────

  Future<List<_AvgRow>> readDailyAverages() async {
    await open();
    return _FfiBackend.instance.readDailyAverages();
  }

  // ───────────────────────── Time zones ─────────────────────────

  /// Returns display strings like "MT/MST/MDT" grouped by tz_name.
  Future<List<String>> listTzAliasStrings() async {
    await open();
    return _FfiBackend.instance.listTzAliasStrings();
  }

  Future<void> setActiveTzByAlias(String alias) async {
    await open();
    await _FfiBackend.instance.setActiveTzByAlias(alias);
  }

  Future<_Tz?> readActiveTz() async {
    await open();
    return _FfiBackend.instance.readActiveTz();
  }

  /// Returns the full alias string (e.g., "MT/MST/MDT") for the active time zone.
  /// Falls back to "UTC" if not configured.
  Future<String> readActiveTzAliasString() async {
    await open();
    return _FfiBackend.instance.readActiveTzAliasString();
  }

  // ───────────────────────── Timestamps ─────────────────────────

  /// Convert a local wall-clock timestamp (in the active time zone)
  /// to a UTC DB timestamp "YYYY-MM-DD HH:MM:SS".
  Future<String> localToUtcDbTimestamp(String localTs) async {
    await open();
    return _FfiBackend.instance.localToUtcDbTimestamp(localTs);
  }

  /// Convert a UTC DB timestamp "YYYY-MM-DD HH:MM:SS" to local wall-clock
  /// time in the active time zone, also as "YYYY-MM-DD HH:MM:SS".
  Future<String> utcDbToLocalTimestamp(String utcTs) async {
    await open();
    return _FfiBackend.instance.utcDbToLocalTimestamp(utcTs);
  }

  // ───────────────────────── Transactions: insert / undo / redo ─────────────────────────

  /// Insert entries (at a given UTC timestamp, or now if null) and return their new row IDs.
  Future<List<int>> insertManyAtUtcReturningIds(
      List<_Entry> entries, String? utcIso) async {
    await open();
    return _FfiBackend.instance.insertManyAtUtcReturningIds(entries, utcIso);
  }

  Future<_TxnSnapshot?> readTransactionById(int id) async {
    await open();
    return _FfiBackend.instance.readTransactionById(id);
  }

  Future<void> deleteTransactionById(int id) async {
    await open();
    await _FfiBackend.instance.deleteTransactionById(id);
  }

  /// Query transactions by optional UTC range; null bounds are open.
  /// Results ordered by timestamp_utc DESC (implemented in Rust).
  Future<List<_TxRow>> queryTransactionsUtcRange({
    String? startUtc,
    String? endUtc,
  }) async {
    await open();
    return _FfiBackend.instance.queryTransactionsUtcRange(
      startUtc: startUtc,
      endUtc: endUtc,
    );
  }

  Future<List<_TxRow>> queryTransactionsToday() async {
    await open();
    return _FfiBackend.instance.queryTransactionsToday();
  }

  Future<List<_TxRow>> queryTransactionsLastNDays(int days) async {
    await open();
    return _FfiBackend.instance.queryTransactionsLastNDays(days);
  }

  Future<List<_TxRow>> queryTransactionsRangeLocal({
    String? startLocal,
    String? endLocal,
  }) async {
    await open();
    return _FfiBackend.instance.queryTransactionsRangeLocal(
      startLocal: startLocal,
      endLocal: endLocal,
    );
  }

  Future<List<_TxRow>> queryTransactionsAll() async {
    await open();
    return _FfiBackend.instance.queryTransactionsAll();
  }

  // Logical batch insert / undo / redo via backend

  Future<String> insertBatchWithUndoToken(
      List<_Entry> entries, String? utcIso) async {
    await open();
    return _FfiBackend.instance.insertBatchWithUndoToken(entries, utcIso);
  }

  Future<List<int>> undoLogicalBatch(String token) async {
    await open();
    return _FfiBackend.instance.undoLogicalBatch(token);
  }

  Future<List<int>> redoLogicalBatch(String token) async {
    await open();
    return _FfiBackend.instance.redoLogicalBatch(token);
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

class _Pill {
  final int id;
  final String name;
  _Pill(this.id, this.name);
}

class _AvgRow {
  final String pillName;
  final double avg;
  _AvgRow(this.pillName, this.avg);
}

class _Entry {
  final int pillId;
  final int qty;
  _Entry(this.pillId, this.qty);
}

class _TxnSnapshot {
  final int pillId;
  final int qty;
  final String utcIso; // "YYYY-MM-DD HH:MM:SS" UTC
  _TxnSnapshot(this.pillId, this.qty, this.utcIso);
}

class _Tz {
  final String alias;
  final String tzName; // IANA tz database name, e.g., "America/Denver"
  _Tz(this.alias, this.tzName);
}

DateTime parseDbUtc(String s) {
  final base = s.replaceFirst(' ', 'T');
  final iso =
  base.endsWith('+00:00') ? base.replaceFirst('+00:00', 'Z') : '${base}Z';
  return DateTime.parse(iso).toUtc();
}

// </editor-fold>
