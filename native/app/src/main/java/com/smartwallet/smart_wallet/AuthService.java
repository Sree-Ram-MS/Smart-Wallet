package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;

import com.google.android.gms.auth.GoogleAuthUtil;
import com.google.android.gms.auth.UserRecoverableAuthException;
import com.google.android.gms.auth.api.signin.GoogleSignIn;
import com.google.android.gms.auth.api.signin.GoogleSignInAccount;
import com.google.android.gms.auth.api.signin.GoogleSignInClient;
import com.google.android.gms.auth.api.signin.GoogleSignInOptions;
import com.google.android.gms.common.api.ApiException;
import com.google.android.gms.common.api.Scope;
import com.google.android.gms.tasks.Task;

/**
 * Google Sign-In, Phase 5 — the native counterpart of Flutter's
 * AuthService, built on the vendored play-services-auth SDK (see
 * fetch-libs.sh). Same scopes (email, profile, drive.appdata,
 * drive.file), same profile mapping, same guest user, same sign-out
 * semantics (disconnect + sign out; the caller clears the stored
 * user — wallet data is NOT touched).
 */
public final class AuthService {

    /** Web (type 3) OAuth client of Firebase project smart-wallet-by-ram. */
    public static final String WEB_CLIENT_ID =
            "720304451502-ih61sa67e59lt1040t1c3pl125lj3nj0.apps.googleusercontent.com";

    public static final Scope SCOPE_DRIVE_APPDATA =
            new Scope("https://www.googleapis.com/auth/drive.appdata");
    public static final Scope SCOPE_DRIVE_FILE =
            new Scope("https://www.googleapis.com/auth/drive.file");

    /** oauth2: token string for GoogleAuthUtil (Drive REST calls). */
    public static final String DRIVE_TOKEN_SCOPE =
            "oauth2:https://www.googleapis.com/auth/drive.appdata"
                    + " https://www.googleapis.com/auth/drive.file";

    /** Request code for the sign-in intent. */
    public static final int RC_SIGN_IN = 4101;

    private AuthService() {}

    public static GoogleSignInOptions options() {
        return new GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                .requestEmail()
                .requestProfile()
                .requestScopes(SCOPE_DRIVE_APPDATA, SCOPE_DRIVE_FILE)
                .requestServerAuthCode(WEB_CLIENT_ID, false)
                .build();
    }

    public static GoogleSignInClient client(Context ctx) {
        return GoogleSignIn.getClient(ctx, options());
    }

    public static Intent signInIntent(Activity activity) {
        return client(activity).getSignInIntent();
    }

    /** Parse the sign-in result; throws ApiException on failure/cancel. */
    public static GoogleSignInAccount accountFromIntent(Intent data) throws ApiException {
        Task<GoogleSignInAccount> task = GoogleSignIn.getSignedInAccountFromIntent(data);
        return task.getResult(ApiException.class);
    }

    /** The account a previous sign-in left behind, or null. */
    public static GoogleSignInAccount lastAccount(Context ctx) {
        return GoogleSignIn.getLastSignedInAccount(ctx);
    }

    /**
     * Fresh Google user -> UserProfile, exactly Flutter's mapping:
     * name falls back to the email prefix, photo to '', currency INR,
     * biometric off, dark mode on.
     */
    public static UserProfile userFromAccount(GoogleSignInAccount account) {
        UserProfile u = new UserProfile();
        u.id = account.getId();
        String name = account.getDisplayName();
        String email = account.getEmail() != null ? account.getEmail() : "";
        u.name = name != null && !name.isEmpty() ? name
                : email.contains("@") ? email.substring(0, email.indexOf('@')) : email;
        u.email = email;
        Uri photo = account.getPhotoUrl();
        u.photoUrl = photo != null ? photo.toString() : "";
        u.baseCurrency = "INR";
        u.biometricEnabled = false;
        u.isDarkMode = true;
        return u;
    }

    /**
     * Link Google onto an existing (guest) profile, Flutter-style:
     * only the identity fields change — currency, biometric and theme
     * preferences and ALL wallet data are kept. Photo falls back to
     * the current one when Google returns none.
     */
    public static void applyLinkedAccount(UserProfile current, GoogleSignInAccount account) {
        UserProfile fresh = userFromAccount(account);
        current.id = fresh.id;
        current.name = fresh.name;
        current.email = fresh.email;
        if (!fresh.photoUrl.isEmpty()) current.photoUrl = fresh.photoUrl;
    }

    /** Flutter's guest user, verbatim. */
    public static UserProfile guestUser() {
        UserProfile u = new UserProfile();
        u.id = "guest_001";
        u.name = "Guest User";
        u.email = "guest@smartwallet.app";
        u.photoUrl = "";
        u.baseCurrency = "INR";
        u.biometricEnabled = false;
        u.isDarkMode = true;
        return u;
    }

    /**
     * Flutter signOut(): disconnect() then signOut(), errors ignored,
     * then done — the caller clears the stored user + session flag
     * (data remains, exactly like HiveService.clearUser()).
     */
    public static void signOut(Activity activity, final Runnable done) {
        final GoogleSignInClient c = client(activity);
        c.revokeAccess().addOnCompleteListener(new com.google.android.gms.tasks.OnCompleteListener<Void>() {
            @Override public void onComplete(Task<Void> t) {
                c.signOut().addOnCompleteListener(new com.google.android.gms.tasks.OnCompleteListener<Void>() {
                    @Override public void onComplete(Task<Void> t2) {
                        if (done != null) done.run();
                    }
                });
            }
        });
    }

    /** Token fetch failure; recoveryIntent set when the user can fix it. */
    public static final class AuthException extends Exception {
        public final Intent recoveryIntent;

        public AuthException(String msg, Intent recoveryIntent) {
            super(msg);
            this.recoveryIntent = recoveryIntent;
        }
    }

    /**
     * Blocking Drive access-token fetch — call ONLY from a background
     * thread. This is the same mechanism Flutter's google_sign_in
     * authentication header uses under the hood.
     */
    public static String driveTokenBlocking(Context ctx) throws AuthException {
        GoogleSignInAccount account = lastAccount(ctx);
        if (account == null || account.getAccount() == null) {
            throw new AuthException("Not signed in with Google", null);
        }
        try {
            return GoogleAuthUtil.getToken(ctx, account.getAccount(), DRIVE_TOKEN_SCOPE);
        } catch (UserRecoverableAuthException e) {
            throw new AuthException("Google needs your permission for Drive access",
                    e.getIntent());
        } catch (Exception e) {
            throw new AuthException("Could not get a Google token: " + e.getMessage(), null);
        }
    }

    public static void clearTokenBlocking(Context ctx, String token) {
        try {
            GoogleAuthUtil.clearToken(ctx, token);
        } catch (Exception ignored) {}
    }
}
