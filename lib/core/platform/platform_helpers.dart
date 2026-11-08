/// Platform-specific helpers (files, images, sharing, gzip).
///
/// Native builds (Android/iOS/desktop) use `dart:io` through
/// `platform_helpers_io.dart`; web builds use `platform_helpers_web.dart`.
/// Never import `dart:io` directly from shared code: go through this file.
library;

export 'platform_helpers_io.dart'
    if (dart.library.js_interop) 'platform_helpers_web.dart';
