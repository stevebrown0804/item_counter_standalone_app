//REMINDER: Path (Medium Phone API 36.0):
// Full path: /data/data/com.example.daily_pill_counter
// Pastable piece: com.example.daily_pill_counter

// <editor-fold desc="Imports, consts, main, etc.">
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart' as ffi_helpers;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:media_store_plus/media_store_plus.dart';
import 'package:flutter/services.dart'; // for FilteringTextInputFormatter
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Filenames / view names must match your existing DB.
const String kDbFileName = 'daily-pill-tracking.db';
const String kViewName = 'daily_avg_by_pill_UTC';

/// Column names expected from the daily-avg view.
const List<String> kShowColumns = ['pill_name', 'daily_avg'];

// --- Transaction viewer types (top-level) ---
enum _TxMode { today, lastNDays, range, all }

// </editor-fold>

// <editor-fold desc="Some fn; the _TxRow, PillApp and _DB classes">

Future<DateTime?> _pickLocalDateTime(
    BuildContext context, {
      required tz.Location loc,
      DateTime? initialLocal,
    }) async {
  final nowL = tz.TZDateTime.now(loc);
  final initial = initialLocal ?? nowL;

  final d = await showDatePicker(
    context: context,
    initialDate: DateTime(initial.year, initial.month, initial.day),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  if (d == null) return null;

  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );

  if (t == null) return null;

  return tz.TZDateTime(loc, d.year, d.month, d.day, t.hour, t.minute);
}

class _TxRow {
  final DateTime utc; // stored in UTC
  final String pill;
  final int qty;
  const _TxRow(this.utc, this.pill, this.qty);
}

class PillApp extends StatelessWidget {
  const PillApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pill tracker',
      home: const _ViewScreen(),
    );
  }
}

// ───────────────────────── Rust FFI bridge ─────────────────────────

// Native typedefs
typedef _IcbOpenNative = ffi.Pointer<ffi.Void> Function(
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbOpenDart = ffi.Pointer<ffi.Void> Function(
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbCloseNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef _IcbCloseDart = void Function(ffi.Pointer<ffi.Void>);
typedef _IcbJsonNoArgsNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    );
typedef _IcbJsonNoArgsDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    );
typedef _IcbSetWindowDaysNative = ffi.Int32 Function(
    ffi.Pointer<ffi.Void>,
    ffi.Int64,
    );
typedef _IcbSetWindowDaysDart = int Function(
    ffi.Pointer<ffi.Void>,
    int,
    );
typedef _IcbFreeStringNative = ffi.Void Function(
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbFreeStringDart = void Function(
    ffi.Pointer<ffi_helpers.Utf8>,
    );

// New FFI typedefs
typedef _IcbListPillsNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    );
typedef _IcbListPillsDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    );
typedef _IcbReadSkipConfirmNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    );
typedef _IcbReadSkipConfirmDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    );
typedef _IcbSetSkipConfirmNative = ffi.Int32 Function(
    ffi.Pointer<ffi.Void>,
    ffi.Int32,
    );
typedef _IcbSetSkipConfirmDart = int Function(
    ffi.Pointer<ffi.Void>,
    int,
    );
typedef _IcbListTimezonesNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    );
typedef _IcbListTimezonesDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    );
typedef _IcbSetActiveTzNative = ffi.Int32 Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbSetActiveTzDart = int Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbReadActiveTzNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    );
typedef _IcbReadActiveTzDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    );
typedef _IcbInsertManyAtUtcNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi.Int64>,
    ffi.Pointer<ffi.Int64>,
    ffi.IntPtr,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbInsertManyAtUtcDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi.Int64>,
    ffi.Pointer<ffi.Int64>,
    int,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbQueryTxTodayNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    );
typedef _IcbQueryTxTodayDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    );
typedef _IcbQueryTxLastNDaysNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Int64,
    );
typedef _IcbQueryTxLastNDaysDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    int,
    );
typedef _IcbQueryTxRangeLocalNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi_helpers.Utf8>,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbQueryTxRangeLocalDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi_helpers.Utf8>,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbQueryTxAllNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    );
typedef _IcbQueryTxAllDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    );
typedef _IcbQueryTxRangeNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi_helpers.Utf8>,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbQueryTxRangeDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi_helpers.Utf8>,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbDeleteTxByIdNative = ffi.Int32 Function(
    ffi.Pointer<ffi.Void>,
    ffi.Int64,
    );
typedef _IcbDeleteTxByIdDart = int Function(
    ffi.Pointer<ffi.Void>,
    int,
    );
typedef _IcbReadTxByIdNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Int64,
    );
typedef _IcbReadTxByIdDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    int,
    );
typedef _IcbCountOlderNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Int64,
    );
typedef _IcbCountOlderDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    int,
    );
typedef _IcbDeleteOlderNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Int64,
    );
typedef _IcbDeleteOlderDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    int,
    );
typedef _IcbLocalToUtcNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbLocalToUtcDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbUtcToLocalNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbUtcToLocalDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi_helpers.Utf8>,
    );

/// Thin wrapper over the Rust item-counter-ffi library.
///
/// Rust side exports:
///   - icb_open / icb_close
///   - icb_read_daily_averages_json
///   - icb_read_averaging_window_days_json
///   - icb_set_averaging_window_days
///   - icb_list_pills_json
///   - icb_read_skip_delete_second_confirm_json
///   - icb_set_skip_delete_second_confirm
///   - icb_list_timezones_json
///   - icb_set_active_tz_by_alias
///   - icb_read_active_tz_json
///   - icb_local_to_utc_db_timestamp_json
///   - icb_utc_db_to_local_timestamp_json
///   - icb_insert_many_at_utc_json
///   - icb_query_transactions_today_json
///   - icb_query_transactions_last_n_days_json
///   - icb_query_transactions_range_local_json
///   - icb_query_transactions_all_json
///   - icb_query_transactions_utc_range_json
///   - icb_delete_transaction_by_id
///   - icb_read_transaction_by_id_json
///   - icb_count_transactions_older_than_days_json
///   - icb_delete_transactions_older_than_days_json
///   - icb_free_string
class _FfiBackend {
  _FfiBackend._internal();
  static final _FfiBackend instance = _FfiBackend._internal();

  bool _initialized = false;
  late final ffi.DynamicLibrary _lib;

  late final _IcbOpenDart _icbOpen;
  late final _IcbCloseDart _icbClose;
  late final _IcbJsonNoArgsDart _icbReadDailyAveragesJson;
  late final _IcbJsonNoArgsDart _icbReadWindowDaysJson;
  late final _IcbSetWindowDaysDart _icbSetWindowDays;
  late final _IcbFreeStringDart _icbFreeString;

  // New symbols
  late final _IcbListPillsDart _icbListPillsJson;
  late final _IcbReadSkipConfirmDart _icbReadSkipConfirmJson;
  late final _IcbSetSkipConfirmDart _icbSetSkipConfirm;
  late final _IcbListTimezonesDart _icbListTimezonesJson;
  late final _IcbSetActiveTzDart _icbSetActiveTzByAlias;
  late final _IcbReadActiveTzDart _icbReadActiveTzJson;
  late final _IcbInsertManyAtUtcDart _icbInsertManyAtUtcJson;
  late final _IcbQueryTxTodayDart _icbQueryTxTodayJson;
  late final _IcbQueryTxLastNDaysDart _icbQueryTxLastNDaysJson;
  late final _IcbQueryTxRangeLocalDart _icbQueryTxRangeLocalJson;
  late final _IcbQueryTxAllDart _icbQueryTxAllJson;
  late final _IcbQueryTxRangeDart _icbQueryTxRangeJson;
  late final _IcbDeleteTxByIdDart _icbDeleteTxById;
  late final _IcbReadTxByIdDart _icbReadTxByIdJson;
  late final _IcbCountOlderDart _icbCountOlderJson;
  late final _IcbDeleteOlderDart _icbDeleteOlderJson;
  late final _IcbLocalToUtcDart _icbLocalToUtcJson;
  late final _IcbUtcToLocalDart _icbUtcToLocalJson;

  ffi.Pointer<ffi.Void>? _handle;

  bool get isInitialized => _initialized;

  Future<void> init(String dbPath) async {
    if (_initialized) return;

    _lib = _openLibrary();

    _icbOpen = _lib.lookupFunction<_IcbOpenNative, _IcbOpenDart>('icb_open');
    _icbClose =
        _lib.lookupFunction<_IcbCloseNative, _IcbCloseDart>('icb_close');

    _icbReadDailyAveragesJson = _lib.lookupFunction<_IcbJsonNoArgsNative,
        _IcbJsonNoArgsDart>('icb_read_daily_averages_json');

    _icbReadWindowDaysJson = _lib.lookupFunction<_IcbJsonNoArgsNative,
        _IcbJsonNoArgsDart>('icb_read_averaging_window_days_json');

    _icbSetWindowDays = _lib.lookupFunction<_IcbSetWindowDaysNative,
        _IcbSetWindowDaysDart>('icb_set_averaging_window_days');

    _icbFreeString = _lib.lookupFunction<_IcbFreeStringNative,
        _IcbFreeStringDart>('icb_free_string');

    // New lookups
    _icbListPillsJson = _lib.lookupFunction<_IcbListPillsNative,
        _IcbListPillsDart>('icb_list_pills_json');

    _icbReadSkipConfirmJson = _lib.lookupFunction<_IcbReadSkipConfirmNative,
        _IcbReadSkipConfirmDart>(
      'icb_read_skip_delete_second_confirm_json',
    );

    _icbSetSkipConfirm = _lib.lookupFunction<_IcbSetSkipConfirmNative,
        _IcbSetSkipConfirmDart>('icb_set_skip_delete_second_confirm');

    _icbListTimezonesJson = _lib.lookupFunction<_IcbListTimezonesNative,
        _IcbListTimezonesDart>('icb_list_timezones_json');

    _icbSetActiveTzByAlias = _lib.lookupFunction<_IcbSetActiveTzNative,
        _IcbSetActiveTzDart>('icb_set_active_tz_by_alias');

    _icbReadActiveTzJson = _lib.lookupFunction<_IcbReadActiveTzNative,
        _IcbReadActiveTzDart>('icb_read_active_tz_json');

    _icbInsertManyAtUtcJson = _lib.lookupFunction<_IcbInsertManyAtUtcNative,
        _IcbInsertManyAtUtcDart>('icb_insert_many_at_utc_json');

    _icbQueryTxTodayJson = _lib.lookupFunction<_IcbQueryTxTodayNative,
        _IcbQueryTxTodayDart>('icb_query_transactions_today_json');

    _icbQueryTxLastNDaysJson =
        _lib.lookupFunction<_IcbQueryTxLastNDaysNative,
            _IcbQueryTxLastNDaysDart>(
            'icb_query_transactions_last_n_days_json');

    _icbQueryTxRangeLocalJson =
        _lib.lookupFunction<_IcbQueryTxRangeLocalNative,
            _IcbQueryTxRangeLocalDart>(
            'icb_query_transactions_range_local_json');

    _icbQueryTxAllJson = _lib.lookupFunction<_IcbQueryTxAllNative,
        _IcbQueryTxAllDart>('icb_query_transactions_all_json');

    _icbQueryTxRangeJson = _lib.lookupFunction<_IcbQueryTxRangeNative,
        _IcbQueryTxRangeDart>('icb_query_transactions_utc_range_json');

    _icbDeleteTxById = _lib.lookupFunction<_IcbDeleteTxByIdNative,
        _IcbDeleteTxByIdDart>('icb_delete_transaction_by_id');

    _icbReadTxByIdJson = _lib.lookupFunction<_IcbReadTxByIdNative,
        _IcbReadTxByIdDart>('icb_read_transaction_by_id_json');

    _icbCountOlderJson = _lib.lookupFunction<_IcbCountOlderNative,
        _IcbCountOlderDart>('icb_count_transactions_older_than_days_json');

    _icbDeleteOlderJson = _lib.lookupFunction<_IcbDeleteOlderNative,
        _IcbDeleteOlderDart>('icb_delete_transactions_older_than_days_json');

    _icbLocalToUtcJson = _lib.lookupFunction<_IcbLocalToUtcNative,
        _IcbLocalToUtcDart>('icb_local_to_utc_db_timestamp_json');

    _icbUtcToLocalJson = _lib.lookupFunction<_IcbUtcToLocalNative,
        _IcbUtcToLocalDart>('icb_utc_db_to_local_timestamp_json');

    final cPath = dbPath.toNativeUtf8();
    try {
      final h = _icbOpen(cPath);
      if (h == ffi.Pointer<ffi.Void>.fromAddress(0)) {
        throw StateError('icb_open returned null (failed to open Rust backend)');
      }
      _handle = h;
    } finally {
      ffi_helpers.malloc.free(cPath);
    }

    _initialized = true;
  }

  ffi.DynamicLibrary _openLibrary() {
    if (Platform.isAndroid || Platform.isLinux) {
      return ffi.DynamicLibrary.open('libitem_counter_ffi.so');
    } else if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('item_counter_ffi.dll');
    } else if (Platform.isMacOS || Platform.isIOS) {
      return ffi.DynamicLibrary.open('libitem_counter_ffi.dylib');
    } else {
      throw UnsupportedError('Unsupported platform for Rust FFI backend');
    }
  }

  void dispose() {
    final h = _handle;
    if (h != null && h != ffi.Pointer<ffi.Void>.fromAddress(0)) {
      _icbClose(h);
    }
    _handle = null;
    _initialized = false;
  }

  ffi.Pointer<ffi.Void> _requireHandle() {
    final h = _handle;
    if (h == null || h == ffi.Pointer<ffi.Void>.fromAddress(0)) {
      throw StateError('Rust backend handle not initialized');
    }
    return h;
  }

  String _jsonFromNoArg(_IcbJsonNoArgsDart f) {
    final h = _requireHandle();
    final ptr = f(h);
    if (ptr == ffi.Pointer<ffi_helpers.Utf8>.fromAddress(0)) {
      throw StateError('Rust FFI returned null JSON pointer');
    }
    try {
      return ptr.toDartString();
    } finally {
      _icbFreeString(ptr);
    }
  }

  String _jsonFromPtr(ffi.Pointer<ffi_helpers.Utf8> ptr) {
    if (ptr == ffi.Pointer<ffi_helpers.Utf8>.fromAddress(0)) {
      throw StateError('Rust FFI returned null JSON pointer');
    }
    try {
      return ptr.toDartString();
    } finally {
      _icbFreeString(ptr);
    }
  }

  Map<String, dynamic> _decodeMap(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Rust FFI JSON is not an object');
    }
    return decoded;
  }

  List<dynamic> _decodeList(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Rust FFI JSON root is not an object');
    }
    if (decoded['ok'] != true) {
      final msg = decoded['error']?.toString() ?? 'unknown error';
      throw StateError('Rust call failed: $msg');
    }
    final data = decoded['data'];
    if (data == null) return const [];
    if (data is! List) {
      throw StateError('Rust FFI "data" is not an array');
    }
    return data;
  }

  Map<String, dynamic>? _decodeNullableMap(String jsonStr) {
    final decoded = _decodeMap(jsonStr);
    if (decoded['ok'] != true) {
      final msg = decoded['error']?.toString() ?? 'unknown error';
      throw StateError('Rust call failed: $msg');
    }
    final data = decoded['data'];
    if (data == null) return null;
    if (data is! Map<String, dynamic>) {
      throw StateError('Rust FFI "data" is not an object');
    }
    return data;
  }

  // ── Window days / averages ──

  Future<int> readAveragingWindowDays() async {
    final jsonStr = _jsonFromNoArg(_icbReadWindowDaysJson);
    final decoded = _decodeMap(jsonStr);
    if (decoded['ok'] != true) {
      final msg = decoded['error']?.toString() ?? 'unknown error';
      throw StateError('Rust readAveragingWindowDays failed: $msg');
    }
    final data = decoded['data'] as Map<String, dynamic>? ?? const {};
    final v = data['days'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  Future<void> setAveragingWindowDays(int days) async {
    if (days <= 0) {
      throw ArgumentError('days must be > 0');
    }
    final h = _requireHandle();
    final rc = _icbSetWindowDays(h, days);
    if (rc != 0) {
      throw StateError('Rust setAveragingWindowDays returned error code $rc');
    }
  }

  Future<List<_AvgRow>> readDailyAverages() async {
    final jsonStr = _jsonFromNoArg(_icbReadDailyAveragesJson);
    final decoded = _decodeMap(jsonStr);
    if (decoded['ok'] != true) {
      final msg = decoded['error']?.toString() ?? 'unknown error';
      throw StateError('Rust readDailyAverages failed: $msg');
    }
    final data = decoded['data'] as List<dynamic>? ?? const [];
    return data.map((e) {
      final m = e as Map<String, dynamic>;
      final name = m['pill_name']?.toString() ?? '';
      final rawAvg = m['daily_avg'];
      final avg = (rawAvg is num)
          ? rawAvg.toDouble()
          : double.tryParse(rawAvg?.toString() ?? '0') ?? 0.0;
      return _AvgRow(name, avg);
    }).toList();
  }

  // ── Pills ──

  Future<List<_Pill>> listPills() async {
    final jsonStr = _jsonFromNoArg(_icbListPillsJson);
    final decoded = _decodeMap(jsonStr);
    if (decoded['ok'] != true) {
      final msg = decoded['error']?.toString() ?? 'unknown error';
      throw StateError('Rust listPills failed: $msg');
    }
    final data = decoded['data'] as List<dynamic>? ?? const [];
    return data.map((e) {
      final m = e as Map<String, dynamic>;
      final id = (m['id'] as num).toInt();
      final name = m['name']?.toString() ?? '';
      final displayOrder = m['display_order'];
      // Rust side may send null; we do not use display_order on Dart side.
      return _Pill(id, name);
    }).toList();
  }

  // ── Settings: skip second confirmation ──

  Future<bool> readSkipDeleteSecondConfirm() async {
    final jsonStr = _jsonFromNoArg(_icbReadSkipConfirmJson);
    final decoded = _decodeMap(jsonStr);
    if (decoded['ok'] != true) {
      final msg = decoded['error']?.toString() ?? 'unknown error';
      throw StateError('Rust readSkipDeleteSecondConfirm failed: $msg');
    }
    final data = decoded['data'] as Map<String, dynamic>? ?? const {};
    final v = data['skip'];
    if (v is bool) return v;
    if (v is num) return v != 0;
    return v?.toString().toLowerCase() == 'true';
  }

  Future<void> setSkipDeleteSecondConfirm(bool skip) async {
    final h = _requireHandle();
    final raw = skip ? 1 : 0;
    final rc = _icbSetSkipConfirm(h, raw);
    if (rc != 0) {
      throw StateError('Rust setSkipDeleteSecondConfirm returned error $rc');
    }
  }

  // ── Time zones ──

  Future<List<Map<String, dynamic>>> _listTimezonesRaw() async {
    final jsonStr = _jsonFromNoArg(_icbListTimezonesJson);
    final decoded = _decodeMap(jsonStr);
    if (decoded['ok'] != true) {
      final msg = decoded['error']?.toString() ?? 'unknown error';
      throw StateError('Rust listTimezones failed: $msg');
    }
    final data = decoded['data'] as List<dynamic>? ?? const [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<String>> listTzAliasStrings() async {
    final rows = await _listTimezonesRaw();
    final Map<String, List<String>> byName = {};
    for (final r in rows) {
      final alias = (r['alias'] ?? '').toString();
      final name = (r['tz_name'] ?? '').toString();
      if (alias.isEmpty || name.isEmpty) continue;
      byName.putIfAbsent(name, () => []).add(alias);
    }
    final out = <String>[];
    byName.forEach((_, aliases) {
      aliases.sort();
      out.add(aliases.join('/'));
    });
    out.sort();
    return out;
  }

  Future<void> setActiveTzByAlias(String alias) async {
    final h = _requireHandle();
    final cAlias = alias.toNativeUtf8();
    try {
      final rc = _icbSetActiveTzByAlias(h, cAlias);
      if (rc != 0) {
        throw StateError('Rust setActiveTzByAlias returned error $rc');
      }
    } finally {
      ffi_helpers.malloc.free(cAlias);
    }
  }

  Future<_Tz?> readActiveTz() async {
    final jsonStr = _jsonFromNoArg(_icbReadActiveTzJson);
    final data = _decodeNullableMap(jsonStr);
    if (data == null) return null;
    final alias = (data['alias'] ?? 'UTC').toString();
    final tzName = (data['tz_name'] ?? 'UTC').toString();
    return _Tz(alias, tzName);
  }

  Future<String> readActiveTzAliasString() async {
    final rows = await _listTimezonesRaw();
    final active = await readActiveTz();
    final tzName = active?.tzName ?? 'UTC';

    final aliases = rows
        .where((r) => (r['tz_name'] ?? '').toString() == tzName)
        .map((r) => (r['alias'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();
    if (aliases.isEmpty) return 'UTC';
    aliases.sort();
    return aliases.join('/');
  }

  // ── Timestamps: local <-> UTC (DB format) ──

  Future<String> localToUtcDbTimestamp(String localTs) async {
    final h = _requireHandle();
    final cLocal = localTs.toNativeUtf8();
    try {
      final ptr = _icbLocalToUtcJson(h, cLocal);
      final jsonStr = _jsonFromPtr(ptr);
      final decoded = _decodeMap(jsonStr);
      if (decoded['ok'] != true) {
        final msg = decoded['error']?.toString() ?? 'unknown error';
        throw StateError('Rust localToUtcDbTimestamp failed: $msg');
      }
      final data = decoded['data'] as Map<String, dynamic>? ?? const {};
      final ts = data['timestamp']?.toString();
      if (ts == null || ts.isEmpty) {
        throw StateError('Rust localToUtcDbTimestamp returned empty timestamp');
      }
      return ts;
    } finally {
      ffi_helpers.malloc.free(cLocal);
    }
  }

  Future<String> utcDbToLocalTimestamp(String utcTs) async {
    final h = _requireHandle();
    final cUtc = utcTs.toNativeUtf8();
    try {
      final ptr = _icbUtcToLocalJson(h, cUtc);
      final jsonStr = _jsonFromPtr(ptr);
      final decoded = _decodeMap(jsonStr);
      if (decoded['ok'] != true) {
        final msg = decoded['error']?.toString() ?? 'unknown error';
        throw StateError('Rust utcDbToLocalTimestamp failed: $msg');
      }
      final data = decoded['data'] as Map<String, dynamic>? ?? const {};
      final ts = data['timestamp']?.toString();
      if (ts == null || ts.isEmpty) {
        throw StateError('Rust utcDbToLocalTimestamp returned empty timestamp');
      }
      return ts;
    } finally {
      ffi_helpers.malloc.free(cUtc);
    }
  }

  // ── Transactions ──

  List<_TxRow> _decodeTxRows(String jsonStr) {
    final list = _decodeList(jsonStr);
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      final tsStr = (m['timestamp_utc'] ?? '').toString();
      final pillName = (m['pill_name'] ?? '').toString();
      final qtyRaw = m['quantity'];
      final qty = (qtyRaw is num)
          ? qtyRaw.toInt()
          : int.tryParse(qtyRaw?.toString() ?? '0') ?? 0;
      final dt = parseDbUtc(tsStr);
      return _TxRow(dt, pillName, qty);
    }).toList();
  }

  Future<List<int>> insertManyAtUtcReturningIds(
      List<_Entry> entries, String? utcIso) async {
    if (entries.isEmpty) return const [];

    final h = _requireHandle();
    final len = entries.length;

    final idsPtr = ffi_helpers.malloc<ffi.Int64>(len);
    final qtyPtr = ffi_helpers.malloc<ffi.Int64>(len);

    for (var i = 0; i < len; i++) {
      idsPtr[i] = entries[i].pillId;
      qtyPtr[i] = entries[i].qty;
    }

    ffi.Pointer<ffi_helpers.Utf8> tsPtr =
    ffi.Pointer<ffi_helpers.Utf8>.fromAddress(0);
    if (utcIso != null) {
      tsPtr = utcIso.toNativeUtf8();
    }

    try {
      final ptr =
      _icbInsertManyAtUtcJson(h, idsPtr, qtyPtr, len, tsPtr);
      final jsonStr = _jsonFromPtr(ptr);
      final decoded = _decodeMap(jsonStr);
      if (decoded['ok'] != true) {
        final msg = decoded['error']?.toString() ?? 'unknown error';
        throw StateError('Rust insertManyAtUtc failed: $msg');
      }
      final data = decoded['data'] as Map<String, dynamic>? ?? const {};
      final list = data['ids'] as List<dynamic>? ?? const [];
      return list
          .map((v) => (v is num) ? v.toInt() : int.parse(v.toString()))
          .toList();
    } finally {
      ffi_helpers.malloc.free(idsPtr);
      ffi_helpers.malloc.free(qtyPtr);
      if (utcIso != null) {
        ffi_helpers.malloc.free(tsPtr);
      }
    }
  }

  Future<List<_TxRow>> queryTransactionsUtcRange({
    String? startUtc,
    String? endUtc,
  }) async {
    final h = _requireHandle();

    final startPtr = startUtc == null
        ? ffi.Pointer<ffi_helpers.Utf8>.fromAddress(0)
        : startUtc.toNativeUtf8();
    final endPtr = endUtc == null
        ? ffi.Pointer<ffi_helpers.Utf8>.fromAddress(0)
        : endUtc.toNativeUtf8();

    try {
      final ptr = _icbQueryTxRangeJson(h, startPtr, endPtr);
      final jsonStr = _jsonFromPtr(ptr);
      return _decodeTxRows(jsonStr);
    } finally {
      if (startUtc != null) ffi_helpers.malloc.free(startPtr);
      if (endUtc != null) ffi_helpers.malloc.free(endPtr);
    }
  }

  Future<List<_TxRow>> queryTransactionsToday() async {
    final h = _requireHandle();
    final ptr = _icbQueryTxTodayJson(h);
    final jsonStr = _jsonFromPtr(ptr);
    return _decodeTxRows(jsonStr);
  }

  Future<List<_TxRow>> queryTransactionsLastNDays(int days) async {
    if (days <= 0) {
      throw ArgumentError('days must be > 0');
    }
    final h = _requireHandle();
    final ptr = _icbQueryTxLastNDaysJson(h, days);
    final jsonStr = _jsonFromPtr(ptr);
    return _decodeTxRows(jsonStr);
  }

  Future<List<_TxRow>> queryTransactionsRangeLocal({
    String? startLocal,
    String? endLocal,
  }) async {
    final h = _requireHandle();

    final startPtr = startLocal == null
        ? ffi.Pointer<ffi_helpers.Utf8>.fromAddress(0)
        : startLocal.toNativeUtf8();
    final endPtr = endLocal == null
        ? ffi.Pointer<ffi_helpers.Utf8>.fromAddress(0)
        : endLocal.toNativeUtf8();

    try {
      final ptr = _icbQueryTxRangeLocalJson(h, startPtr, endPtr);
      final jsonStr = _jsonFromPtr(ptr);
      return _decodeTxRows(jsonStr);
    } finally {
      if (startLocal != null) ffi_helpers.malloc.free(startPtr);
      if (endLocal != null) ffi_helpers.malloc.free(endPtr);
    }
  }

  Future<List<_TxRow>> queryTransactionsAll() async {
    final h = _requireHandle();
    final ptr = _icbQueryTxAllJson(h);
    final jsonStr = _jsonFromPtr(ptr);
    return _decodeTxRows(jsonStr);
  }

  Future<void> deleteTransactionById(int id) async {
    final h = _requireHandle();
    final rc = _icbDeleteTxById(h, id);
    if (rc != 0) {
      throw StateError('Rust deleteTransactionById returned error $rc');
    }
  }

  Future<_TxnSnapshot?> readTransactionById(int id) async {
    final h = _requireHandle();
    final ptr = _icbReadTxByIdJson(h, id);
    final jsonStr = _jsonFromPtr(ptr);
    final decoded = _decodeMap(jsonStr);
    if (decoded['ok'] != true) {
      final msg = decoded['error']?.toString() ?? 'unknown error';
      throw StateError('Rust readTransactionById failed: $msg');
    }
    final data = decoded['data'];
    if (data == null) return null;
    if (data is! Map<String, dynamic>) {
      throw StateError('Rust FFI readTransactionById "data" is not object');
    }
    final pillId = (data['pill_id'] as num).toInt();
    final qty = (data['quantity'] as num).toInt();
    final ts = (data['timestamp_utc'] ?? '').toString();
    if (ts.isEmpty) return null;
    return _TxnSnapshot(pillId, qty, ts);
  }

  Future<int> countTransactionsOlderThanDays(int days) async {
    if (days <= 0) return 0;
    final h = _requireHandle();
    final ptr = _icbCountOlderJson(h, days);
    final jsonStr = _jsonFromPtr(ptr);
    final decoded = _decodeMap(jsonStr);
    if (decoded['ok'] != true) {
      final msg = decoded['error']?.toString() ?? 'unknown error';
      throw StateError('Rust countTransactionsOlderThanDays failed: $msg');
    }
    final data = decoded['data'] as Map<String, dynamic>? ?? const {};
    final v = data['count'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  Future<int> deleteTransactionsOlderThanDays(int days) async {
    if (days <= 0) return 0;
    final h = _requireHandle();
    final ptr = _icbDeleteOlderJson(h, days);
    final jsonStr = _jsonFromPtr(ptr);
    final decoded = _decodeMap(jsonStr);
    if (decoded['ok'] != true) {
      final msg = decoded['error']?.toString() ?? 'unknown error';
      throw StateError('Rust deleteTransactionsOlderThanDays failed: $msg');
    }
    final data = decoded['data'] as Map<String, dynamic>? ?? const {};
    final v = data['deleted'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }
}

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

// </editor-fold>

// <editor-fold desc="Data-related classes/fns">
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

// <editor-fold desc="_Store? *shrug*">
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
  final List<List<int>> _undoStack = [];
  bool get canUndo => _undoStack.isNotEmpty;
  final List<List<_TxnSnapshot>> _redoStack = [];
  bool get canRedo => _redoStack.isNotEmpty;

  void _breakRedoChain() {
    if (_redoStack.isNotEmpty) {
      _redoStack.clear();
    }
  }

  Future<void> undoLast() async {
    if (_undoStack.isEmpty) return;
    final ids = _undoStack.removeLast();

    final snaps = <_TxnSnapshot>[];
    for (final id in ids) {
      final snap = await _db.readTransactionById(id);
      await _db.deleteTransactionById(id);
      if (snap != null) snaps.add(snap);
    }
    if (snaps.isNotEmpty) _redoStack.add(snaps);

    await load();
    notifyListeners();
  }

  Future<void> redoLast() async {
    if (_redoStack.isEmpty) return;
    final snaps = _redoStack.removeLast();

    final entries = snaps.map((s) => _Entry(s.pillId, s.qty)).toList();
    final ts = snaps.isNotEmpty ? snaps.first.utcIso : null;
    final ids = await _db.insertManyAtUtcReturningIds(entries, ts);
    _breakRedoChain();
    _undoStack.add(ids);

    await load();
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

    final ids = await _db.insertManyAtUtcReturningIds(entries, null);
    _breakRedoChain();
    _undoStack.add(ids);
    _redoStack.clear();

    await load();
  }
}

// </editor-fold>

// <editor-fold desc="The UI">
class _SkipSecondConfirmSetting extends StatefulWidget {
  const _SkipSecondConfirmSetting();

  @override
  State<_SkipSecondConfirmSetting> createState() =>
      _SkipSecondConfirmSettingState();
}

class _SkipSecondConfirmSettingState
    extends State<_SkipSecondConfirmSetting> {
  final _db = _Db();
  bool? _initial;
  bool _current = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await _db.readSkipDeleteSecondConfirm();
    if (!mounted) return;
    setState(() {
      _initial = v;
      _current = v;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _db.setSkipDeleteSecondConfirm(_current);
      if (!mounted) return;
      setState(() => _initial = _current);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preference saved.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initial == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: SizedBox(height: 56),
      );
    }

    final changed = _initial != _current;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          CheckboxListTile(
            value: _current,
            onChanged: (v) => setState(() => _current = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
                'Skip second confirmation when deleting transactions'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: (!changed || _saving) ? null : _save,
              child: _saving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Save'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _exportDatabase(BuildContext context) async {
    try {
      final s = _ViewScreenState._lastMounted;
      final active = s?._store.activeTz;
      final tzName = active?.tzName ?? 'Etc/UTC';
      final alias = active?.alias ?? DateTime.now().timeZoneName;

      var loc = tz.getLocation('Etc/UTC');
      try {
        loc = tz.getLocation(tzName);
      } catch (_) {}
      final now = tz.TZDateTime.now(loc);

      String two(int n) => n.toString().padLeft(2, '0');
      final ts = '${now.year}-${two(now.month)}-${two(now.day)}_'
          '${two(now.hour)}-${two(now.minute)}-${two(now.second)}';

      final fileName = 'daily-pill-tracking-DB-${ts}_($alias).db';

      final dbDir = await getDatabasesPath();
      final liveDb = File(p.join(dbDir, kDbFileName));
      if (!await liveDb.exists()) {
        throw FileSystemException('Database not found', liveDb.path);
      }

      final tmpDir = p.normalize(p.join(dbDir, '..', 'files'));
      await Directory(tmpDir).create(recursive: true);
      final tmpPath = p.join(tmpDir, fileName);

      final tmpFile = File(tmpPath);
      if (await tmpFile.exists()) {
        try {
          if (tmpFile.path != liveDb.path) {
            try {
              await tmpFile.delete();
            } catch (_) {}
          }
        } catch (_) {}
      }
      await liveDb.copy(tmpPath);

      final mediaStore = MediaStore();
      await mediaStore.saveFile(
        tempFilePath: tmpFile.path,
        dirType: DirType.download,
        dirName: DirName.download,
        relativePath: '',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database exported to: Downloads/$fileName'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        debugPrint('Export failed: $e');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  Future<void> _showDeleteOldTxDialog(BuildContext context) async {
    final db = _Db();

    final days = await db.readAveragingWindowDays();
    final count = await db.countTransactionsOlderThanDays(days);

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete older transactions?'),
        content: Text(
          'This will permanently delete $count transactions older than $days days. '
              'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _handleDeleteOldTx(context, days);
            },
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteOldTx(BuildContext context, int days) async {
    final db = _Db();
    final skip = await db.readSkipDeleteSecondConfirm();

    if (skip) {
      final deleted = await db.deleteTransactionsOlderThanDays(days);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
            Text('Deleted $deleted transactions older than $days days.')),
      );
      return;
    }

    bool skipNext = false;

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            backgroundColor: Colors.red,
            title: const Text(
              'Really delete transactions?',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Abort!'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.transparent,
                        ),
                        onPressed: () async {
                          if (skipNext) {
                            await db.setSkipDeleteSecondConfirm(true);
                          }
                          final deleted =
                          await db.deleteTransactionsOlderThanDays(days);
                          if (!context.mounted) return;
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Deleted $deleted transactions older than $days days.')),
                          );
                        },
                        child: const Text('Proceed'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: skipNext,
                  onChanged: (v) => setState(() => skipNext = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Colors.white,
                  checkColor: Colors.red,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Skip this step next time.\n(This can be undone in Settings.)',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _TzRow(),
          const Divider(),
          const _WindowRow(),
          const Divider(),
          const SizedBox(height: 0),
          SizedBox(
            child: Align(
              alignment: Alignment.center,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.list_alt),
                label: const Text('View transactions'),
                onPressed: () {
                  Navigator.of(context).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final s = _ViewScreenState._lastMounted;
                    if (s != null) {
                      s._openTransactionViewer(s.context);
                    }
                  });
                },
              ),
            ),
          ),
          const Divider(),
          SizedBox(
            child: Align(
              alignment: Alignment.center,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Export database'),
                onPressed: () {
                  Navigator.of(context).pop();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _exportDatabase(context);
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            child: Text(
              'Danger Zone',
              style: TextStyle(
                color: Colors.red,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
              ),
              onPressed: () => _showDeleteOldTxDialog(context),
              child: const Text('Delete outdated transactions'),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          const _SkipSecondConfirmSetting(),
          const Divider(),
        ],
      ),
    );
  }
}

class _WindowRow extends StatefulWidget {
  const _WindowRow();
  @override
  State<_WindowRow> createState() => _WindowRowState();
}

class _WindowRowState extends State<_WindowRow> {
  final _db = _Db();
  final TextEditingController _ctrl = TextEditingController();
  bool _canSubmit = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Choose the initial date of transaction',
    );
    if (picked == null) return;

    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(picked.year, picked.month, picked.day);
    final rawDays = today.difference(date).inDays;

    final days = (rawDays <= 0) ? 1 : rawDays;

    setState(() {
      _ctrl.text = days.toString();
      _canSubmit = true;
    });
  }

  Future<void> _submit() async {
    final raw = _ctrl.text.trim();
    final days = int.tryParse(raw);
    if (days == null || days <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a positive number of days.')),
      );
      return;
    }

    await _db.setAveragingWindowDays(days);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Averaging window set to: $days days')),
    );

    FocusScope.of(context).unfocus();
    setState(() {
      _ctrl.clear();
      _canSubmit = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Averaging window, in days',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    TextField(
                      controller: _ctrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      onChanged: (v) =>
                          setState(() => _canSubmit = v.trim().isNotEmpty),
                      decoration: const InputDecoration(
                        hintText: 'e.g., 30',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range, size: 18),
                      label: const Text('Pick start date'),
                      onPressed: _pickDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _canSubmit ? _submit : null,
                child: const Text('Submit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TzRow extends StatefulWidget {
  const _TzRow();
  @override
  State<_TzRow> createState() => _TzRowState();
}

class _TzRowState extends State<_TzRow> {
  final _db = _Db();
  final _ctrl = TextEditingController();
  String _query = '';
  List<String> _options = const [];
  bool _loading = true;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final opts = await _db.listTzAliasStrings();
      if (!mounted) return;
      setState(() {
        _options = opts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load time zones: $e')),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _ctrl.text.trim();
    if (raw.isEmpty) return;

    String displayString = raw;
    String aliasToSave;

    if (raw.contains('/')) {
      aliasToSave = raw.split('/').first.trim();
    } else {
      final rawUpper = raw.toUpperCase();
      final match = _options.firstWhere(
            (opt) => opt.split('/').any((a) => a.toUpperCase() == rawUpper),
        orElse: () => raw,
      );
      displayString = match;
      aliasToSave = match.contains('/') ? match.split('/').first.trim() : raw;
      _ctrl.text = displayString;
    }

    await _db.setActiveTzByAlias(aliasToSave);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Time zone: ($displayString) saved')),
    );

    FocusScope.of(context).unfocus();

    _ctrl.clear();
    setState(() => _canSubmit = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ListTile(
        title: Text('Time Zone'),
        subtitle: Text('Loading…'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text(
            'Time Zone:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Autocomplete<String>(
              optionsBuilder: (TextEditingValue tev) {
                final q = tev.text.trim().toLowerCase();
                if (q.isEmpty) return _options;
                return _options.where((s) => s.toLowerCase().contains(q));
              },
              onSelected: (value) {
                _ctrl.text = value;
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                controller.text = _ctrl.text;
                controller.addListener(() {
                  _ctrl.text = controller.text;
                  final next = controller.text.trim();
                  final changed = next != _query;
                  final canSubmitNow = next.isNotEmpty;
                  if (changed || canSubmitNow != _canSubmit) {
                    setState(() {
                      _query = next;
                      _canSubmit = canSubmitNow;
                    });
                  }
                });

                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    hintText: 'e.g., MT/MST/MDT or MT',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                final q = _query.trim().toLowerCase();
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: options.map((opt) {
                          final aliases = opt.split('/');
                          final match = q.isNotEmpty &&
                              aliases.any((a) => a.toLowerCase() == q);

                          final title = Text.rich(
                            TextSpan(
                              children: [
                                for (int i = 0; i < aliases.length; i++) ...[
                                  TextSpan(
                                    text: aliases[i],
                                    style: TextStyle(
                                      fontWeight: (q.isNotEmpty &&
                                          aliases[i].toLowerCase() == q)
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  if (i < aliases.length - 1)
                                    const TextSpan(text: '/'),
                                ]
                              ],
                            ),
                          );

                          return ListTile(
                            dense: true,
                            selected: match,
                            title: title,
                            onTap: () => onSelected(opt),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _canSubmit ? _submit : null,
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class _ViewScreen extends StatefulWidget {
  const _ViewScreen();

  @override
  State<_ViewScreen> createState() => _ViewScreenState();
}

class _ViewScreenState extends State<_ViewScreen> {
  static _ViewScreenState? _lastMounted;

  final _store = _Store(_Db());
  final _ctrl = TextEditingController();
  bool _loading = true;
  String? _error;
  final _db = _Db();
  String? _tzDisplay;
  String? _lastAdded;

  Future<void> _loadActiveTzDisplay() async {
    final s = await _db.readActiveTzAliasString();
    if (!mounted) return;
    setState(() => _tzDisplay = s);
  }

  @override
  void initState() {
    super.initState();
    _lastMounted = this;
    _loadActiveTzDisplay();
    unawaited(_init());
  }

  Future<void> _init() async {
    try {
      await _store.load();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _lastMounted = null;
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _openAddSheet() async {
    final pills = _store.pills;
    if (pills.isEmpty) return;

    final qty = List<int>.filled(pills.length, 0);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 12,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Log pills',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: pills.length,
                        separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final p = pills[i];
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon:
                                const Icon(Icons.keyboard_arrow_down),
                                onPressed: () => setState(() {
                                  if (qty[i] > 0) qty[i]--;
                                }),
                              ),
                              SizedBox(
                                width: 48,
                                child: TextField(
                                  key: ValueKey('qty_$i'),
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding:
                                    EdgeInsets.symmetric(vertical: 6),
                                    border: OutlineInputBorder(),
                                  ),
                                  controller: TextEditingController(
                                      text: qty[i].toString()),
                                  onChanged: (s) {
                                    final v = int.tryParse(s) ?? 0;
                                    setState(() =>
                                    qty[i] = v.clamp(0, 1000000));
                                  },
                                ),
                              ),
                              IconButton(
                                icon:
                                const Icon(Icons.keyboard_arrow_up),
                                onPressed: () =>
                                    setState(() => qty[i] = qty[i] + 1),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final map = <int, int>{};
                            final parts = <String>[];
                            for (var i = 0; i < pills.length; i++) {
                              final q = qty[i];
                              if (q > 0) {
                                map[pills[i].id] = q;
                                parts.add(
                                    '${pills[i].name} x $q');
                              }
                            }
                            if (map.isEmpty) {
                              if (!mounted) return;
                              Navigator.of(context).pop();
                              return;
                            }
                            await _store.addBatch(map);

                            if (!mounted) return;

                            final message =
                                'Added: ${parts.join(', ')}';

                            if (mounted) {
                              setState(() {
                                _lastAdded = message;
                              });
                            }

                            Navigator.of(context).pop();
                          },
                          child: const Text('Submit'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openTransactionViewer(BuildContext context) async {
    final tzName = _store.activeTz.tzName;
    tz.Location loc;
    try {
      loc = tz.getLocation(tzName);
    } catch (_) {
      loc = tz.getLocation('Etc/UTC');
    }

    _TxMode mode = _TxMode.today;
    final lastDaysCtrl = TextEditingController(text: '7');
    DateTime? startLocal;
    DateTime? endLocal;

    List<_TxRow> items = [];
    bool busy = false;
    String? error;

    Future<void> runQuery() async {
      setState(() {
        busy = true;
        error = null;
      });

      String formatLocal(DateTime dt) {
        String two(int n) => n.toString().padLeft(2, '0');
        return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
            '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
      }

      try {
        switch (mode) {
          case _TxMode.today:
            items = await _db.queryTransactionsToday();
            break;

          case _TxMode.lastNDays:
            final n = int.tryParse(lastDaysCtrl.text.trim());
            final days = (n == null || n <= 0) ? 1 : n;
            items = await _db.queryTransactionsLastNDays(days);
            break;

          case _TxMode.range:
            String? startStr;
            String? endStr;
            if (startLocal != null) {
              startStr = formatLocal(startLocal!);
            }
            if (endLocal != null) {
              endStr = formatLocal(endLocal!);
            }
            items = await _db.queryTransactionsRangeLocal(
              startLocal: startStr,
              endLocal: endStr,
            );
            break;

          case _TxMode.all:
            items = await _db.queryTransactionsAll();
            break;
        }
      } catch (ex) {
        error = ex.toString();
      } finally {
        setState(() {
          busy = false;
        });
      }
    }

    await runQuery();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void ss(VoidCallback f) {
              if (mounted) setSheetState(f);
            }

            String fmtLocal(DateTime? d) {
              if (d == null) return '';
              String two(int n) => n < 10 ? '0$n' : '$n';
              return '${d.year}-${two(d.month)}-${two(d.day)} '
                  '${two(d.hour)}:${two(d.minute)}';
            }

            Widget radioRow(_TxMode m, Widget trailing) => Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Radio<_TxMode>(
                  value: m,
                  groupValue: mode,
                  onChanged: (v) => ss(() {
                    mode = v!;
                  }),
                ),
                const SizedBox(width: 4),
                Expanded(child: trailing),
              ],
            );

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 8,
                  bottom:
                  MediaQuery.of(ctx).viewInsets.bottom + 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                        const SizedBox(width: 4),
                        const Text('Transaction Viewer',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Refresh',
                          icon: const Icon(Icons.refresh),
                          onPressed: busy
                              ? null
                              : () async {
                            await runQuery();
                            ss(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    radioRow(_TxMode.today, const Text('Today')),
                    const Divider(),
                    radioRow(
                        _TxMode.lastNDays,
                        Row(
                          children: [
                            const Text('Last'),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 72,
                              child: TextField(
                                controller: lastDaysCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    isDense: true,
                                    border:
                                    OutlineInputBorder()),
                                onTap: () => ss(() {
                                  mode = _TxMode.lastNDays;
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('days'),
                          ],
                        )),
                    const Divider(),
                    radioRow(
                        _TxMode.range,
                        Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('From'),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    readOnly: true,
                                    controller: TextEditingController(
                                        text: fmtLocal(startLocal)),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border:
                                      const OutlineInputBorder(),
                                      hintText: fmtLocal(startLocal)
                                          .isEmpty
                                          ? '— select date —'
                                          : null,
                                      hintStyle: const TextStyle(
                                          color: Colors.grey),
                                    ),
                                    onTap: () => ss(() {
                                      mode = _TxMode.range;
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () async {
                                    ss(() {
                                      mode = _TxMode.range;
                                    });
                                    final picked =
                                    await _pickLocalDateTime(
                                        context,
                                        loc: loc,
                                        initialLocal:
                                        startLocal);
                                    ss(() {
                                      startLocal = picked;
                                    });
                                  },
                                  child:
                                  const Text('Pick start date'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    const Text('to'),
                                    const SizedBox(width: 26),
                                    Expanded(
                                      child: Stack(
                                        alignment:
                                        Alignment.center,
                                        children: [
                                          TextField(
                                            readOnly: true,
                                            controller:
                                            TextEditingController(
                                                text: fmtLocal(
                                                    endLocal)),
                                            decoration:
                                            InputDecoration(
                                              isDense: true,
                                              border:
                                              const OutlineInputBorder(),
                                              hintText: fmtLocal(
                                                  startLocal)
                                                  .isEmpty
                                                  ? '— select date —'
                                                  : null,
                                              hintStyle:
                                              const TextStyle(
                                                  color: Colors
                                                      .grey),
                                            ),
                                            onTap: () => ss(() {
                                              mode =
                                                  _TxMode.range;
                                            }),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      onPressed: () async {
                                        ss(() {
                                          mode = _TxMode.range;
                                        });
                                        final picked =
                                        await _pickLocalDateTime(
                                            context,
                                            loc: loc,
                                            initialLocal:
                                            endLocal);
                                        ss(() {
                                          endLocal = picked;
                                        });
                                      },
                                      child:
                                      const Text('Pick end date'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],
                            ),
                          ],
                        )),
                    const Divider(),
                    radioRow(_TxMode.all, const Text('All')),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.search),
                        label: const Text('Apply'),
                        onPressed: busy
                            ? null
                            : () async {
                          FocusManager
                              .instance.primaryFocus
                              ?.unfocus();
                          await runQuery();
                          ss(() {});
                        },
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          error!,
                          style: TextStyle(
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .error),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius:
                          BorderRadius.circular(16),
                          border: Border.all(
                              color: Theme.of(ctx)
                                  .dividerColor),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8),
                              child: Row(
                                children: const [
                                  Expanded(
                                      flex: 44,
                                      child: Text('Timestamp')),
                                  Expanded(
                                      flex: 44,
                                      child: Text('Pill name')),
                                  Expanded(
                                      flex: 12,
                                      child: Text('Qty.',
                                          textAlign:
                                          TextAlign.right)),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: busy
                                  ? const Center(
                                  child:
                                  CircularProgressIndicator())
                                  : ListView.builder(
                                itemCount: items.length,
                                itemBuilder: (c, i) {
                                  final it = items[i];
                                  final local =
                                  tz.TZDateTime.from(
                                      it.utc, loc);
                                  String two(int n) =>
                                      n < 10
                                          ? '0$n'
                                          : '$n';
                                  final tsStr =
                                      '${local.year}-${two(local.month)}-${two(local.day)} '
                                      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';

                                  return Padding(
                                    padding:
                                    const EdgeInsets
                                        .symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                      children: [
                                        Expanded(
                                            flex: 44,
                                            child:
                                            Text(tsStr)),
                                        const SizedBox(
                                            width: 8),
                                        Expanded(
                                            flex: 44,
                                            child: Text(
                                                it.pill,
                                                softWrap:
                                                true)),
                                        const SizedBox(
                                            width: 8),
                                        Expanded(
                                          flex: 12,
                                          child: Text(
                                            it.qty
                                                .toString(),
                                            textAlign:
                                            TextAlign
                                                .right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleDays = _store.days;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pill tracker'),
            const SizedBox(height: 3),
            if (_tzDisplay != null)
              Text(
                'Time zone: $_tzDisplay',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const SettingsScreen()),
              );
              if (!mounted) return;
              await _store.load();
              await _loadActiveTzDisplay();
              if (!mounted) return;
              setState(() {});
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Padding(
        padding: const EdgeInsets.all(16),
        child: Text(_error!,
            style: const TextStyle(color: Colors.red)),
      )
          : AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          return Column(
            children: [
              const SizedBox.shrink(),
              const SizedBox(height: 4),
              if (_lastAdded != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12),
                  child: Card(
                    elevation: 0,
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    child: Padding(
                      padding:
                      const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12),
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(
                                top: 2),
                            child: Icon(Icons.history),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                MediaQuery.of(
                                    context)
                                    .size
                                    .height *
                                    0.35,
                              ),
                              child:
                              SingleChildScrollView(
                                padding:
                                const EdgeInsets
                                    .only(
                                    right: 8),
                                child: SelectionArea(
                                  child: Text(
                                    _lastAdded!,
                                    softWrap: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Clear',
                            icon:
                            const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _lastAdded = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pill',
                        style: TextStyle(
                            fontWeight:
                            FontWeight.bold),
                      ),
                    ),
                    Text(
                      'Avg. ($titleDays day(s))',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _store.rows.length,
                  itemExtent: 28.0,
                  itemBuilder: (context, i) {
                    final r = _store.rows[i];
                    return Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets
                              .symmetric(
                              horizontal: 12,
                              vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.pillName,
                                  maxLines: 1,
                                  overflow:
                                  TextOverflow
                                      .ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.0),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                r.avg
                                    .toStringAsFixed(
                                    2),
                                style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.0),
                                textAlign:
                                TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment
                                .bottomCenter,
                            child: Container(
                              height: 1,
                              color:
                              Colors.grey.shade300,
                              margin: const EdgeInsets
                                  .symmetric(
                                  horizontal: 8),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _store,
            builder: (context, _) {
              final enabled = _store.canUndo;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Opacity(
                  opacity: enabled ? 1.0 : 0.38,
                  child: IgnorePointer(
                    ignoring: !enabled,
                    child: FloatingActionButton(
                      heroTag: 'undo_fab',
                      onPressed: enabled
                          ? () async => await _store.undoLast()
                          : null,
                      mini: true,
                      tooltip: 'Undo last',
                      child: const Icon(Icons.undo),
                    ),
                  ),
                ),
              );
            },
          ),
          FloatingActionButton.extended(
            heroTag: 'add_fab',
            onPressed: _openAddSheet,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
          AnimatedBuilder(
            animation: _store,
            builder: (context, _) {
              final enabled = _store.canRedo;
              return Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Opacity(
                  opacity: enabled ? 1.0 : 0.38,
                  child: IgnorePointer(
                    ignoring: !enabled,
                    child: FloatingActionButton(
                      heroTag: 'redo_fab',
                      onPressed: enabled
                          ? () async => await _store.redoLast()
                          : null,
                      mini: true,
                      tooltip: 'Redo last',
                      child: const Icon(Icons.redo),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// </editor-fold>

// <editor-fold desc="main()">
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'daily_pill_tracking';
  }
  tzdata.initializeTimeZones();
  runApp(const PillApp());
}
// </editor-fold>
