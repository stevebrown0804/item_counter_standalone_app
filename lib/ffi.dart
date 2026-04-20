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
}