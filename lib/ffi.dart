// ffi.dart

part of 'main.dart';

// <editor-fold desc="Native typedefs">
typedef _IcbOpenNative = ffi.Pointer<ffi.Void> Function(
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbOpenDart = ffi.Pointer<ffi.Void> Function(
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbCloseNative = ffi.Void Function(ffi.Pointer<ffi.Void>);
typedef _IcbCloseDart = void Function(ffi.Pointer<ffi.Void>);
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
typedef _IcbSetSkipConfirmNative = ffi.Int32 Function(
    ffi.Pointer<ffi.Void>,
    ffi.Int32,
    );
typedef _IcbSetSkipConfirmDart = int Function(
    ffi.Pointer<ffi.Void>,
    int,
    );
typedef _IcbSetActiveTzNative = ffi.Int32 Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbSetActiveTzDart = int Function(
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
typedef _IcbDeleteTxByIdNative = ffi.Int32 Function(
    ffi.Pointer<ffi.Void>,
    ffi.Int64,
    );
typedef _IcbDeleteTxByIdDart = int Function(
    ffi.Pointer<ffi.Void>,
    int,
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
// </editor-fold>

class _FfiBackend {
  _FfiBackend._internal();
  static final _FfiBackend instance = _FfiBackend._internal();

  bool _initialized = false;
  Future<void>? _initFuture;
  late final ffi.DynamicLibrary _lib;
  late final _IcbOpenDart _icbOpen;
  late final _IcbCloseDart _icbClose;
  late final _IcbSetWindowDaysDart _icbSetWindowDays;
  late final _IcbFreeStringDart _icbFreeString;
  late final _IcbSetSkipConfirmDart _icbSetSkipConfirm;
  late final _IcbSetActiveTzDart _icbSetActiveTzByAlias;
  late final _IcbInsertManyAtUtcDart _icbInsertManyAtUtcJson;
  late final _IcbDeleteTxByIdDart _icbDeleteTxById;
  late final _IcbInsertBatchWithUndoTokenDart _icbInsertBatchWithUndoTokenJson;
  late final _IcbUndoLogicalBatchDart _icbUndoLogicalBatchJson;
  late final _IcbRedoLogicalBatchDart _icbRedoLogicalBatchJson;

  ffi.Pointer<ffi.Void>? _handle;

  bool get isInitialized => _initialized;

  Future<void> init(String dbPath) {
    final sw = Stopwatch()..start();
    debugPrint('[FFI] init() called. _initialized=$_initialized, _initFuture=${_initFuture != null}');

    if (_initialized) {
      debugPrint('[FFI] init() returning immediately because _initialized=true (${sw.elapsedMilliseconds} ms)');
      return Future.value();
    }

    final existing = _initFuture;
    if (existing != null) {
      debugPrint('[FFI] init() returning existing _initFuture (${sw.elapsedMilliseconds} ms)');
      return existing;
    }

    debugPrint('[FFI] init() creating new _doInit future');
    final future = _doInit(dbPath);
    _initFuture = future;
    return future;
  }

  Future<void> _doInit(String dbPath) async {
    final sw = Stopwatch()..start();
    debugPrint('[FFI] _doInit() START dbPath=$dbPath');

    try {
      final swOpenLib = Stopwatch()..start();
      _lib = _openLibrary();
      debugPrint('[FFI] _openLibrary() done in ${swOpenLib.elapsedMilliseconds} ms');

      final swSymbols = Stopwatch()..start();

      _icbOpen = _lib.lookupFunction<_IcbOpenNative, _IcbOpenDart>('icb_open');
      _icbClose = _lib.lookupFunction<_IcbCloseNative, _IcbCloseDart>('icb_close');
      _icbSetWindowDays = _lib.lookupFunction<_IcbSetWindowDaysNative, _IcbSetWindowDaysDart>('icb_set_averaging_window_days');
      _icbFreeString = _lib.lookupFunction<_IcbFreeStringNative, _IcbFreeStringDart>('icb_free_string');
      _icbSetSkipConfirm = _lib.lookupFunction<_IcbSetSkipConfirmNative, _IcbSetSkipConfirmDart>('icb_set_skip_delete_second_confirm');
      _icbSetActiveTzByAlias = _lib.lookupFunction<_IcbSetActiveTzNative, _IcbSetActiveTzDart>('icb_set_active_tz_by_alias');
      _icbInsertManyAtUtcJson = _lib.lookupFunction<_IcbInsertManyAtUtcNative, _IcbInsertManyAtUtcDart>('icb_insert_many_at_utc_json');
      _icbDeleteTxById = _lib.lookupFunction<_IcbDeleteTxByIdNative, _IcbDeleteTxByIdDart>('icb_delete_transaction_by_id');
      _icbInsertBatchWithUndoTokenJson = _lib.lookupFunction<_IcbInsertBatchWithUndoTokenNative, _IcbInsertBatchWithUndoTokenDart>('icb_insert_batch_with_undo_token_json');
      _icbUndoLogicalBatchJson = _lib.lookupFunction<_IcbUndoLogicalBatchNative, _IcbUndoLogicalBatchDart>('icb_undo_logical_batch_json');
      _icbRedoLogicalBatchJson = _lib.lookupFunction<_IcbRedoLogicalBatchNative, _IcbRedoLogicalBatchDart>('icb_redo_logical_batch_json');

      debugPrint('[FFI] symbol lookup done in ${swSymbols.elapsedMilliseconds} ms');

      final cPath = dbPath.toNativeUtf8();
      try {
        final swOpen = Stopwatch()..start();
        debugPrint('[FFI] calling icb_open(...)');
        final h = _icbOpen(cPath);
        debugPrint('[FFI] icb_open(...) returned in ${swOpen.elapsedMilliseconds} ms');

        if (h == ffi.Pointer<ffi.Void>.fromAddress(0)) {
          throw StateError('icb_open returned null (failed to open Rust backend)');
        }

        _handle = h;
      } finally {
        ffi_helpers.malloc.free(cPath);
      }

      _initialized = true;
      debugPrint('[FFI] _doInit() END success in ${sw.elapsedMilliseconds} ms');
    } catch (e, st) {
      debugPrint('[FFI] _doInit() THREW after ${sw.elapsedMilliseconds} ms: $e');
      debugPrint('$st');
      rethrow;
    }
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

  Future<void> setSkipDeleteSecondConfirm(bool skip) async {
    final h = _requireHandle();
    final raw = skip ? 1 : 0;
    final rc = _icbSetSkipConfirm(h, raw);
    if (rc != 0) {
      throw StateError('Rust setSkipDeleteSecondConfirm returned error $rc');
    }
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

  Future<List<int>> insertManyAtUtcReturningIds(List<_Entry> entries, String? utcIso) async {
    if (entries.isEmpty) return const [];

    final h = _requireHandle();
    final len = entries.length;

    final idsPtr = ffi_helpers.malloc<ffi.Int64>(len);
    final qtyPtr = ffi_helpers.malloc<ffi.Int64>(len);

    for (var i = 0; i < len; i++) {
      idsPtr[i] = entries[i].itemId;
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

  Future<void> deleteTransactionById(int id) async {
    final h = _requireHandle();
    final rc = _icbDeleteTxById(h, id);
    if (rc != 0) {
      throw StateError('Rust deleteTransactionById returned error $rc');
    }
  }

  // ── Batch insert / undo / redo ─────────────────────────
  Future<String> insertBatchWithUndoToken(List<_Entry> entries, String? utcIso) async {
    if (entries.isEmpty) {
      throw ArgumentError('entries must not be empty');
    }

    final h = _requireHandle();
    final len = entries.length;

    final idsPtr = ffi_helpers.malloc<ffi.Int64>(len);
    final qtyPtr = ffi_helpers.malloc<ffi.Int64>(len);

    for (var i = 0; i < len; i++) {
      idsPtr[i] = entries[i].itemId;
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