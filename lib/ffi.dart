part of 'main.dart';

// <editor-fold desc="FFI">
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
typedef _IcbListTzAliasGroupsNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    );
typedef _IcbListTzAliasGroupsDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    );
typedef _IcbReadActiveTzDisplayNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    );
typedef _IcbReadActiveTzDisplayDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    );
typedef _IcbInterpretTzAliasInputNative
= ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbInterpretTzAliasInputDart
= ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi_helpers.Utf8>,
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
typedef _IcbDeleteOldWithPolicyNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Int64,
    );
typedef _IcbDeleteOldWithPolicyDart = ffi.Pointer<ffi_helpers.Utf8> Function(
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
typedef _IcbInsertBatchWithUndoTokenNative
= ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi.Int64>,
    ffi.Pointer<ffi.Int64>,
    ffi.IntPtr,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbInsertBatchWithUndoTokenDart
= ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi.Int64>,
    ffi.Pointer<ffi.Int64>,
    int,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbUndoLogicalBatchNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbUndoLogicalBatchDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbRedoLogicalBatchNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbRedoLogicalBatchDart = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbComputeWindowFromPickedDateNative
= ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbComputeWindowFromPickedDateDart
= ffi.Pointer<ffi_helpers.Utf8> Function(
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
///   - icb_insert_batch_with_undo_token_json
///   - icb_undo_logical_batch_json
///   - icb_redo_logical_batch_json
///   - icb_compute_averaging_window_days_from_picked_date_json
///   - icb_delete_old_transactions_with_policy_json
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
  late final _IcbListPillsDart _icbListPillsJson;
  late final _IcbReadSkipConfirmDart _icbReadSkipConfirmJson;
  late final _IcbSetSkipConfirmDart _icbSetSkipConfirm;
  late final _IcbListTimezonesDart _icbListTimezonesJson;
  late final _IcbSetActiveTzDart _icbSetActiveTzByAlias;
  late final _IcbReadActiveTzDart _icbReadActiveTzJson;
  late final _IcbListTzAliasGroupsDart _icbListTzAliasGroupsJson;
  late final _IcbReadActiveTzDisplayDart _icbReadActiveTzDisplayJson;
  late final _IcbInterpretTzAliasInputDart _icbInterpretTzAliasInputJson;
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
  late final _IcbDeleteOldWithPolicyDart _icbDeleteOldWithPolicyJson;
  late final _IcbLocalToUtcDart _icbLocalToUtcJson;
  late final _IcbUtcToLocalDart _icbUtcToLocalJson;
  late final _IcbInsertBatchWithUndoTokenDart
  _icbInsertBatchWithUndoTokenJson;
  late final _IcbUndoLogicalBatchDart _icbUndoLogicalBatchJson;
  late final _IcbRedoLogicalBatchDart _icbRedoLogicalBatchJson;

  // New: compute averaging window from picked local date (TODO 3)
  late final _IcbComputeWindowFromPickedDateDart
  _icbComputeWindowFromPickedDateJson;

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

    _icbListTzAliasGroupsJson =
        _lib.lookupFunction<_IcbListTzAliasGroupsNative,
            _IcbListTzAliasGroupsDart>('icb_list_tz_alias_groups_json');

    _icbReadActiveTzDisplayJson =
        _lib.lookupFunction<_IcbReadActiveTzDisplayNative,
            _IcbReadActiveTzDisplayDart>('icb_read_active_tz_display_json');

    _icbInterpretTzAliasInputJson =
        _lib.lookupFunction<_IcbInterpretTzAliasInputNative,
            _IcbInterpretTzAliasInputDart>(
          'icb_interpret_tz_alias_input_json',
        );

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

    _icbDeleteOldWithPolicyJson =
        _lib.lookupFunction<_IcbDeleteOldWithPolicyNative,
            _IcbDeleteOldWithPolicyDart>(
            'icb_delete_old_transactions_with_policy_json');

    _icbLocalToUtcJson = _lib.lookupFunction<_IcbLocalToUtcNative,
        _IcbLocalToUtcDart>('icb_local_to_utc_db_timestamp_json');

    _icbUtcToLocalJson = _lib.lookupFunction<_IcbUtcToLocalNative,
        _IcbUtcToLocalDart>('icb_utc_db_to_local_timestamp_json');

    _icbInsertBatchWithUndoTokenJson =
        _lib.lookupFunction<_IcbInsertBatchWithUndoTokenNative,
            _IcbInsertBatchWithUndoTokenDart>(
            'icb_insert_batch_with_undo_token_json');

    _icbUndoLogicalBatchJson =
        _lib.lookupFunction<_IcbUndoLogicalBatchNative,
            _IcbUndoLogicalBatchDart>('icb_undo_logical_batch_json');

    _icbRedoLogicalBatchJson =
        _lib.lookupFunction<_IcbRedoLogicalBatchNative,
            _IcbRedoLogicalBatchDart>('icb_redo_logical_batch_json');

    // New: compute averaging window from picked local date (TODO 3)
    _icbComputeWindowFromPickedDateJson =
        _lib.lookupFunction<_IcbComputeWindowFromPickedDateNative,
            _IcbComputeWindowFromPickedDateDart>(
            'icb_compute_averaging_window_days_from_picked_date_json');

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

  // New: compute averaging window from picked local date (TODO 3)

  Future<int> computeAveragingWindowDaysFromPickedLocalDate(
      String localDateYmd) async {
    final h = _requireHandle();
    final cDate = localDateYmd.toNativeUtf8();
    try {
      final ptr = _icbComputeWindowFromPickedDateJson(h, cDate);
      final jsonStr = _jsonFromPtr(ptr);
      final decoded = _decodeMap(jsonStr);
      if (decoded['ok'] != true) {
        final msg = decoded['error']?.toString() ?? 'unknown error';
        throw StateError(
            'Rust computeAveragingWindowDaysFromPickedLocalDate failed: $msg');
      }
      final data = decoded['data'] as Map<String, dynamic>? ?? const {};
      final v = data['days'];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '0') ?? 0;
    } finally {
      ffi_helpers.malloc.free(cDate);
    }
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

  // ── Settings: skip second confirmation ─────────────────────────

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

  // ── Time zones ─────────────────────────

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


  Future<List<Map<String, dynamic>>> _listTimezonesRaw() async {
    final jsonStr = _jsonFromNoArg(_icbListTimezonesJson);
    final decoded = _decodeMap(jsonStr);
    if (decoded['ok'] != true) {
      final msg = decoded['error']?.toString() ?? 'unknown error';
      throw StateError('Rust list_timezones failed: $msg');
    }
    final data = decoded['data'];
    if (data is! List) return const <Map<String, dynamic>>[];
    return data
        .whereType<Map>()
        .map<Map<String, dynamic>>(
            (m) => m.map((k, v) => MapEntry(k.toString(), v)))
        .toList();
  }

  /// Returns display strings like "MT/MST/MDT" for the UI.
  Future<List<String>> listTzAliasStrings() async {
    final jsonStr = _jsonFromNoArg(_icbListTzAliasGroupsJson);
    final decoded = _decodeMap(jsonStr);
    if (decoded['ok'] != true) {
      final msg = decoded['error']?.toString() ?? 'unknown error';
      throw StateError('Rust list_tz_alias_groups failed: $msg');
    }
    final data = decoded['data'];
    if (data is! List) return const <String>[];
    final out = <String>[];
    for (final item in data) {
      if (item is! Map) continue;
      final display = item['display']?.toString().trim() ?? '';
      if (display.isNotEmpty) {
        out.add(display);
      }
    }
    out.sort();
    return out;
  }

  Future<_Tz?> readActiveTz() async {
    final jsonStr = _jsonFromNoArg(_icbReadActiveTzJson);
    final decoded = _decodeMap(jsonStr);
    if (decoded['ok'] != true) {
      return null;
    }
    final data = decoded['data'] as Map<String, dynamic>? ?? const {};
    final alias = data['alias']?.toString();
    final tzName = data['tz_name']?.toString() ?? 'UTC';
    if (alias == null || alias.isEmpty) return null;
    return _Tz(alias, tzName);
  }

  Future<String> readActiveTzAliasString() async {
    final jsonStr = _jsonFromNoArg(_icbReadActiveTzDisplayJson);
    final decoded = _decodeMap(jsonStr);
    if (decoded['ok'] != true) {
      final msg = decoded['error']?.toString() ?? 'unknown error';
      throw StateError('Rust read_active_tz_display failed: $msg');
    }
    final data = decoded['data'] as Map<String, dynamic>? ?? const {};
    final display = data['display']?.toString().trim() ?? '';
    if (display.isEmpty) return 'UTC';
    return display;
  }

  Future<String> interpretTzAliasInput(String rawInput) async {
    final h = _requireHandle();
    final cInput = rawInput.toNativeUtf8();
    try {
      final ptr = _icbInterpretTzAliasInputJson(h, cInput);
      final jsonStr = _jsonFromPtr(ptr);
      final decoded = _decodeMap(jsonStr);
      if (decoded['ok'] != true) {
        final msg = decoded['error']?.toString() ?? 'unknown error';
        throw StateError('Rust interpret_tz_alias_input failed: $msg');
      }
      final data = decoded['data'] as Map<String, dynamic>? ?? const {};
      final alias = data['alias']?.toString().trim() ?? '';
      if (alias.isEmpty) {
        throw StateError('Rust interpret_tz_alias_input returned empty alias');
      }
      return alias;
    } finally {
      ffi_helpers.malloc.free(cInput);
    }
  }


  // ── Timestamps: local <-> UTC (DB format) ─────────────────────────

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

  // ── Transactions ─────────────────────────

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

  Future<int> deleteOldTransactionsWithPolicy(int days) async {
    if (days <= 0) return 0;
    final h = _requireHandle();
    final ptr = _icbDeleteOldWithPolicyJson(h, days);
    final jsonStr = _jsonFromPtr(ptr);
    final decoded = _decodeMap(jsonStr);
    if (decoded['ok'] != true) {
      final msg = decoded['error']?.toString() ?? 'unknown error';
      throw StateError('Rust deleteOldTransactionsWithPolicy failed: $msg');
    }
    final data = decoded['data'] as Map<String, dynamic>? ?? const {};
    final v = data['deleted'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '0') ?? 0;
  }

  // ── Logical batch insert / undo / redo ─────────────────────────

  Future<String> insertBatchWithUndoToken(
      List<_Entry> entries, String? utcIso) async {
    if (entries.isEmpty) {
      throw ArgumentError('entries must not be empty');
    }

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
      _icbInsertBatchWithUndoTokenJson(h, idsPtr, qtyPtr, len, tsPtr);
      final jsonStr = _jsonFromPtr(ptr);
      final decoded = _decodeMap(jsonStr);
      if (decoded['ok'] != true) {
        final msg = decoded['error']?.toString() ?? 'unknown error';
        throw StateError('Rust insertBatchWithUndoToken failed: $msg');
      }
      final data = decoded['data'] as Map<String, dynamic>? ?? const {};
      final token = data['token']?.toString();
      if (token == null || token.isEmpty) {
        throw StateError(
            'Rust insertBatchWithUndoToken returned empty token');
      }
      return token;
    } finally {
      ffi_helpers.malloc.free(idsPtr);
      ffi_helpers.malloc.free(qtyPtr);
      if (utcIso != null) {
        ffi_helpers.malloc.free(tsPtr);
      }
    }
  }

  Future<List<int>> undoLogicalBatch(String token) async {
    final h = _requireHandle();
    final cTok = token.toNativeUtf8();
    try {
      final ptr = _icbUndoLogicalBatchJson(h, cTok);
      final jsonStr = _jsonFromPtr(ptr);
      final decoded = _decodeMap(jsonStr);
      if (decoded['ok'] != true) {
        final msg = decoded['error']?.toString() ?? 'unknown error';
        throw StateError('Rust undoLogicalBatch failed: $msg');
      }
      final data = decoded['data'] as Map<String, dynamic>? ?? const {};
      final list = data['ids'] as List<dynamic>? ?? const [];
      return list
          .map((v) => (v is num) ? v.toInt() : int.parse(v.toString()))
          .toList();
    } finally {
      ffi_helpers.malloc.free(cTok);
    }
  }

  Future<List<int>> redoLogicalBatch(String token) async {
    final h = _requireHandle();
    final cTok = token.toNativeUtf8();
    try {
      final ptr = _icbRedoLogicalBatchJson(h, cTok);
      final jsonStr = _jsonFromPtr(ptr);
      final decoded = _decodeMap(jsonStr);
      if (decoded['ok'] != true) {
        final msg = decoded['error']?.toString() ?? 'unknown error';
        throw StateError('Rust redoLogicalBatch failed: $msg');
      }
      final data = decoded['data'] as Map<String, dynamic>? ?? const {};
      final list = data['ids'] as List<dynamic>? ?? const [];
      return list
          .map((v) => (v is num) ? v.toInt() : int.parse(v.toString()))
          .toList();
    } finally {
      ffi_helpers.malloc.free(cTok);
    }
  }
}

// </editor-fold>
