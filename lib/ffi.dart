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

typedef _IcbFreeStringNative = ffi.Void Function(
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbFreeStringDart = void Function(
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

typedef _IcbInsertBatchWithUndoTokenNative = ffi.Pointer<ffi_helpers.Utf8> Function(
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi.Int64>,
    ffi.Pointer<ffi.Int64>,
    ffi.IntPtr,
    ffi.Pointer<ffi_helpers.Utf8>,
    );
typedef _IcbInsertBatchWithUndoTokenDart = ffi.Pointer<ffi_helpers.Utf8> Function(
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
  late final _IcbFreeStringDart _icbFreeString;
  late final _IcbInsertManyAtUtcDart _icbInsertManyAtUtcJson;
  late final _IcbInsertBatchWithUndoTokenDart _icbInsertBatchWithUndoTokenJson;
  late final _IcbUndoLogicalBatchDart _icbUndoLogicalBatchJson;
  late final _IcbRedoLogicalBatchDart _icbRedoLogicalBatchJson;

  ffi.Pointer<ffi.Void>? _handle;

  bool get isInitialized => _initialized;

  Future<void> init(String dbPath) {
    if (_initialized) {
      return Future.value();
    }

    final existing = _initFuture;
    if (existing != null) {
      return existing;
    }

    final future = _doInit(dbPath);
    _initFuture = future;
    return future;
  }

  Future<void> _doInit(String dbPath) async {
    try {
      _lib = _openLibrary();

      _icbOpen = _lib.lookupFunction<_IcbOpenNative, _IcbOpenDart>('icb_open');
      _icbClose = _lib.lookupFunction<_IcbCloseNative, _IcbCloseDart>('icb_close');
      _icbFreeString = _lib.lookupFunction<_IcbFreeStringNative, _IcbFreeStringDart>('icb_free_string');
      _icbInsertManyAtUtcJson = _lib.lookupFunction<_IcbInsertManyAtUtcNative, _IcbInsertManyAtUtcDart>('icb_insert_many_at_utc_json');
      _icbInsertBatchWithUndoTokenJson = _lib.lookupFunction<_IcbInsertBatchWithUndoTokenNative, _IcbInsertBatchWithUndoTokenDart>('icb_insert_batch_with_undo_token_json');
      _icbUndoLogicalBatchJson = _lib.lookupFunction<_IcbUndoLogicalBatchNative, _IcbUndoLogicalBatchDart>('icb_undo_logical_batch_json');
      _icbRedoLogicalBatchJson = _lib.lookupFunction<_IcbRedoLogicalBatchNative, _IcbRedoLogicalBatchDart>('icb_redo_logical_batch_json');

      final cPath = dbPath.toNativeUtf8();
      try {
        final h = _icbOpen(cPath);
        if (h == ffi.Pointer<ffi.Void>.fromAddress(0)) {
          throw StateError('icb_open returned null');
        }
        _handle = h;
      } finally {
        ffi_helpers.malloc.free(cPath);
      }

      _initialized = true;
    } finally {
      _initFuture = null;
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

    ffi.Pointer<ffi_helpers.Utf8> tsPtr = ffi.Pointer<ffi_helpers.Utf8>.fromAddress(0);
    if (utcIso != null) {
      tsPtr = utcIso.toNativeUtf8();
    }

    try {
      final ptr = _icbInsertManyAtUtcJson(h, idsPtr, qtyPtr, len, tsPtr);
      final jsonStr = _jsonFromPtr(ptr);
      final decoded = _decodeMap(jsonStr);
      if (decoded['ok'] != true) {
        final msg = decoded['error']?.toString() ?? 'unknown error';
        throw StateError('Rust insertManyAtUtc failed: $msg');
      }
      final data = decoded['data'] as Map<String, dynamic>? ?? const {};
      final list = data['ids'] as List<dynamic>? ?? const [];
      return list.map((v) => (v is num) ? v.toInt() : int.parse(v.toString())).toList();
    } finally {
      ffi_helpers.malloc.free(idsPtr);
      ffi_helpers.malloc.free(qtyPtr);
      if (utcIso != null) {
        ffi_helpers.malloc.free(tsPtr);
      }
    }
  }

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

    ffi.Pointer<ffi_helpers.Utf8> tsPtr = ffi.Pointer<ffi_helpers.Utf8>.fromAddress(0);
    if (utcIso != null) {
      tsPtr = utcIso.toNativeUtf8();
    }

    try {
      final ptr = _icbInsertBatchWithUndoTokenJson(h, idsPtr, qtyPtr, len, tsPtr);
      final jsonStr = _jsonFromPtr(ptr);
      final decoded = _decodeMap(jsonStr);
      if (decoded['ok'] != true) {
        final msg = decoded['error']?.toString() ?? 'unknown error';
        throw StateError('Rust insertBatchWithUndoToken failed: $msg');
      }
      final data = decoded['data'] as Map<String, dynamic>? ?? const {};
      final token = data['token']?.toString();
      if (token == null || token.isEmpty) {
        throw StateError('Rust insertBatchWithUndoToken returned empty token');
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
      return list.map((v) => (v is num) ? v.toInt() : int.parse(v.toString())).toList();
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
      return list.map((v) => (v is num) ? v.toInt() : int.parse(v.toString())).toList();
    } finally {
      ffi_helpers.malloc.free(cTok);
    }
  }
}