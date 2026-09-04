import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';
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
      final account = await googleSignIn.signIn();
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
