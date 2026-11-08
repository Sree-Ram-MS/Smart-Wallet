import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi;

/// Renders the official "Sign in with Google" button (GIS). The result is
/// delivered through `GoogleSignIn.onCurrentUserChanged`.
Widget buildGoogleWebButton() => gsi.renderButton(
      configuration: gsi.GSIButtonConfiguration(
        theme: gsi.GSIButtonTheme.outline,
        size: gsi.GSIButtonSize.large,
        text: gsi.GSIButtonText.continueWith,
        shape: gsi.GSIButtonShape.pill,
        minimumWidth: 300,
      ),
    );
