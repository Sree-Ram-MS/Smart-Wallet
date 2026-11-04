package com.smartwallet.smart_wallet;

/**
 * Process-lifetime "already unlocked" flag for the biometric gate:
 * set once the user passes the lock screen, so navigating back into
 * MainActivity within the same app session does not re-prompt. A
 * process restart (app swiped away / device reboot) resets it and
 * the lock screen shows again — the same behaviour as Flutter's
 * router sending a fresh app start through /biometric.
 */
public final class AppLock {
    public static volatile boolean unlockedThisSession = false;

    private AppLock() {}
}
