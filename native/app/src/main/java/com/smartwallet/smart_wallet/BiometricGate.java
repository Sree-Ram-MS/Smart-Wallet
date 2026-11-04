package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.app.KeyguardManager;
import android.content.Context;
import android.content.DialogInterface;
import android.hardware.biometrics.BiometricManager;
import android.hardware.biometrics.BiometricPrompt;
import android.os.Build;
import android.os.CancellationSignal;

import java.util.concurrent.Executor;

/**
 * Framework-only biometric gate (Phase 5) — android.hardware.
 * biometrics.BiometricPrompt, no androidx.biometric. API 28+ only;
 * API 26–27 report UNSUPPORTED_SDK and the app treats the lock as
 * unavailable (the user is let in, never locked out).
 *
 * Mirrors Flutter's local_auth setup: biometricOnly false, so on
 * API 30+ the system prompt also offers the device PIN/password via
 * DEVICE_CREDENTIAL; on API 28–29 the prompt gets a Cancel button
 * and the lock screen offers the credential intent separately.
 */
public final class BiometricGate {

    public enum Status { AVAILABLE, NO_HARDWARE, NOT_ENROLLED, UNSUPPORTED_SDK }

    public static final String REASON = "Authenticate to access Smart Wallet";

    private BiometricGate() {}

    public static Status status(Context ctx) {
        if (Build.VERSION.SDK_INT < 28) return Status.UNSUPPORTED_SDK;
        if (Build.VERSION.SDK_INT >= 29) {
            BiometricManager bm = ctx.getSystemService(BiometricManager.class);
            if (bm == null) return Status.NO_HARDWARE;
            switch (bm.canAuthenticate()) {
                case BiometricManager.BIOMETRIC_SUCCESS:
                    return Status.AVAILABLE;
                case BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED:
                    return Status.NOT_ENROLLED;
                default:
                    return Status.NO_HARDWARE;
            }
        }
        // API 28: BiometricManager does not exist yet; the deprecated
        // FingerprintManager is the only availability probe.
        @SuppressWarnings("deprecation")
        android.hardware.fingerprint.FingerprintManager fm =
                ctx.getSystemService(android.hardware.fingerprint.FingerprintManager.class);
        if (fm == null || !fm.isHardwareDetected()) return Status.NO_HARDWARE;
        if (!fm.hasEnrolledFingerprints()) return Status.NOT_ENROLLED;
        return Status.AVAILABLE;
    }

    public static boolean available(Context ctx) {
        return status(ctx) == Status.AVAILABLE;
    }

    public interface Listener {
        void onSuccess();
        /** Prompt dismissed/errored (cancel, lockout, no biometric…). */
        void onError(int errorCode, String message);
        /** A presented finger/face was not recognised; prompt stays up. */
        void onFailed();
    }

    /**
     * Shows the system prompt over the given activity. Must be called
     * on the main thread with the activity in the foreground.
     */
    public static void prompt(Activity activity, final Listener listener) {
        Executor executor = activity.getMainExecutor();
        BiometricPrompt.Builder builder = new BiometricPrompt.Builder(activity)
                .setTitle("Smart Wallet")
                .setSubtitle(REASON);
        if (Build.VERSION.SDK_INT >= 30) {
            builder.setAllowedAuthenticators(
                    BiometricManager.Authenticators.BIOMETRIC_WEAK
                            | BiometricManager.Authenticators.DEVICE_CREDENTIAL);
        } else {
            builder.setNegativeButton("Cancel", executor,
                    new DialogInterface.OnClickListener() {
                        @Override public void onClick(DialogInterface d, int which) {
                            listener.onError(
                                    BiometricPrompt.BIOMETRIC_ERROR_USER_CANCELED,
                                    "Cancelled");
                        }
                    });
        }
        BiometricPrompt prompt = builder.build();
        prompt.authenticate(new CancellationSignal(), executor,
                new BiometricPrompt.AuthenticationCallback() {
                    @Override public void onAuthenticationSucceeded(
                            BiometricPrompt.AuthenticationResult result) {
                        listener.onSuccess();
                    }

                    @Override public void onAuthenticationError(int errorCode,
                                                                CharSequence errString) {
                        listener.onError(errorCode,
                                errString != null ? errString.toString() : "Error");
                    }

                    @Override public void onAuthenticationFailed() {
                        listener.onFailed();
                    }
                });
    }

    /** Device PIN/password prompt (API 28–29 fallback path). */
    public static android.content.Intent deviceCredentialIntent(Activity activity) {
        KeyguardManager km = activity.getSystemService(KeyguardManager.class);
        if (km == null) return null;
        return km.createConfirmDeviceCredentialIntent("Smart Wallet", REASON);
    }
}
