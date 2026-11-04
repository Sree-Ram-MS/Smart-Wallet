package com.smartwallet.smart_wallet;

/**
 * Pure session-gate decision (Phase 5), mirroring the Flutter router:
 * not logged in -> /login; logged in + biometricEnabled ->
 * /biometric; otherwise -> /dashboard.
 *
 * One deliberate difference from a naive port: the Flutter app keys
 * "logged in" off the presence of a stored user, but the native seed
 * data ships with a demo profile (user_001), so presence alone cannot
 * tell a first run from a signed-in one. The native gate therefore
 * takes an explicit signedIn flag (AppPrefs) ANDed with a stored user
 * by the caller. Biometric only routes to the lock screen when it can
 * actually run (API 28+ framework BiometricPrompt and hardware
 * present + enrolled); otherwise the user goes straight to the
 * dashboard rather than being locked out forever.
 */
public final class SessionGate {

    public enum Route { LOGIN, BIOMETRIC, DASHBOARD }

    private SessionGate() {}

    /**
     * @param signedIn           explicit session flag && a user is stored
     * @param biometricEnabled   user.biometricEnabled
     * @param sdkInt             Build.VERSION.SDK_INT
     * @param biometricAvailable hardware present and enrolled
     *                           (BiometricGate.Status == AVAILABLE)
     */
    public static Route decide(boolean signedIn, boolean biometricEnabled,
                               int sdkInt, boolean biometricAvailable) {
        if (!signedIn) return Route.LOGIN;
        if (biometricEnabled && sdkInt >= 28 && biometricAvailable) {
            return Route.BIOMETRIC;
        }
        return Route.DASHBOARD;
    }
}
