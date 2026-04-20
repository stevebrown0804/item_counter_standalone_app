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
      _icbFreeString = _lib.lookupFunction<_IcbFreeStringNative, _IcbFreeStringDart>('icb_free_string');
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