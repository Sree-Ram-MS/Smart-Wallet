package com.smartwallet.smart_wallet;

import android.content.Context;
import android.content.SharedPreferences;

/**
 * Small app-level preferences kept OUTSIDE the wallet database file —
 * the same split Flutter uses (its settings box is not part of the
 * backup snapshot either): the explicit session flag the gate needs
 * (see SessionGate) and the last_cloud_backup_time stamp the Flutter
 * Drive service writes after a successful upload.
 */
public final class AppPrefs {

    private static final String FILE = "smartwallet_prefs";
    private static final String KEY_SIGNED_IN = "signed_in";
    private static final String KEY_LAST_CLOUD_BACKUP = "last_cloud_backup_time";

    private AppPrefs() {}

    private static SharedPreferences prefs(Context ctx) {
        return ctx.getSharedPreferences(FILE, Context.MODE_PRIVATE);
    }

    public static boolean signedIn(Context ctx) {
        return prefs(ctx).getBoolean(KEY_SIGNED_IN, false);
    }

    public static void setSignedIn(Context ctx, boolean value) {
        prefs(ctx).edit().putBoolean(KEY_SIGNED_IN, value).apply();
    }

    /** ISO timestamp of the last successful Drive upload, or null. */
    public static String lastCloudBackup(Context ctx) {
        return prefs(ctx).getString(KEY_LAST_CLOUD_BACKUP, null);
    }

    public static void setLastCloudBackup(Context ctx, String iso) {
        prefs(ctx).edit().putString(KEY_LAST_CLOUD_BACKUP, iso).apply();
    }
}
