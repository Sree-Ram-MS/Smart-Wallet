/// Web-only Google Identity Services sign-in button.
/// On non-web platforms [buildGoogleWebButton] returns an empty box.
library;

export 'google_web_button_stub.dart'
    if (dart.library.js_interop) 'google_web_button_web.dart';
