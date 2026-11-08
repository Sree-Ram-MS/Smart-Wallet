import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';
import 'cloud_sync_service.dart';
import 'hive_service.dart';

class AuthService {
  static final GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/drive.appdata',
      'https://www.googleapis.com/auth/drive.file',
    ],
  );

  /// Builds the local profile for a Google account.
  static UserProfile profileFromAccount(GoogleSignInAccount account) {
    return UserProfile(
      id: account.id,
      name: account.displayName ?? account.email.split('@').first,
      email: account.email,
      photoUrl: account.photoUrl ?? '',
      baseCurrency: 'INR',
      biometricEnabled: false,
      isDarkMode: true,
    );
  }

  /// Web: the Google Identity Services button (renderButton) and One Tap
  /// report the signed-in user through [GoogleSignIn.onCurrentUserChanged].
  /// Also tries a silent sign-in (One Tap) on startup, since GIS keeps no
  /// session across page loads.
  static void initWeb() {
    if (!kIsWeb) return;
    googleSignIn.signInSilently().catchError((Object e) {
      debugPrint('[GoogleSignIn] Silent sign-in failed: $e');
      return null;
    });
  }

  /// Web: save the profile for an account that signed in via renderButton /
  /// One Tap. Keeps the existing local profile (settings, currency…) when it
  /// is the same Google user.
  static Future<UserProfile> saveWebAccount(GoogleSignInAccount account) async {
    final current = HiveService.getUser();
    final UserProfile user;
    if (current != null && current.id == account.id) {
      user = current.copyWith(
        name: account.displayName ?? current.name,
        email: account.email,
        photoUrl: (current.photoUrl.isEmpty) ? (account.photoUrl ?? '') : current.photoUrl,
      );
    } else {
      user = profileFromAccount(account);
    }
    await HiveService.saveUser(user);
    return user;
  }

  static Future<UserProfile?> signInWithGoogle() async {
    try {
      final account = await googleSignIn.signIn();
      if (account == null) {
        debugPrint('[GoogleSignIn] User cancelled or Google Play Services returned null.');
        return null;
      }

      final user = UserProfile(
        id: account.id,
        name: account.displayName ?? account.email.split('@').first,
        email: account.email,
        photoUrl: account.photoUrl ?? '',
        baseCurrency: 'INR',
        biometricEnabled: false,
        isDarkMode: true,
      );
      await HiveService.saveUser(user);
      return user;
    } catch (e, st) {
      debugPrint('[GoogleSignIn Error] $e\n$st');
      return null;
    }
  }

  static Future<void> signOut() async {
    await CloudSyncService.instance.stop(clearMetadata: true);
    try {
      await googleSignIn.disconnect();
    } catch (_) {}
    try {
      await googleSignIn.signOut();
    } catch (_) {}
    await HiveService.clearUser();
  }

  /// Link Google Account for an existing guest user while keeping local data
  static Future<UserProfile?> linkGoogleAccount(UserProfile current) async {
    try {
      // On the web, prefer an account already authenticated via the GIS
      // button / One Tap; signIn() there needs the People API enabled.
      final account = (kIsWeb ? googleSignIn.currentUser : null) ?? await googleSignIn.signIn();
      if (account == null) {
        debugPrint('[GoogleSignIn] Link cancelled or returned null.');
        return null;
      }

      final updated = current.copyWith(
        id: account.id,
        name: account.displayName ?? account.email.split('@').first,
        email: account.email,
        photoUrl: account.photoUrl ?? current.photoUrl,
      );
      await HiveService.saveUser(updated);
      return updated;
    } catch (e, st) {
      debugPrint('[GoogleSignIn Link Error] $e\n$st');
      return null;
    }
  }

  /// Guest sign-in for testing without Firebase credentials
  static Future<UserProfile> signInAsGuest() async {
    final user = UserProfile(
      id: 'guest_001',
      name: 'Guest User',
      email: 'guest@smartwallet.app',
      photoUrl: '',
      baseCurrency: 'INR',
      biometricEnabled: false,
      isDarkMode: true,
    );
    await HiveService.saveUser(user);
    return user;
  }

  static bool get isLoggedIn => HiveService.getUser() != null;
}
