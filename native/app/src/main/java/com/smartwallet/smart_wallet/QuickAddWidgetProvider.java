package com.smartwallet.smart_wallet;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.widget.RemoteViews;

import java.io.File;
import java.io.FileInputStream;

/**
 * Home-screen Quick Add widget (Phase 5) — a framework
 * AppWidgetProvider port of the Flutter/Kotlin widget: net balance
 * on top, and Income / Expense / Split buttons deep-linking
 * smartwallet://quick-add?type=... into MainActivity; tapping the
 * body opens the dashboard (smartwallet://open-dashboard).
 *
 * The balance is computed from the app's own database file in
 * filesDir (same UID), parsed directly so a cold widget process
 * never triggers Store seeding.
 *
 * Refresh: the system calls onUpdate on its schedule
 * (updatePeriodMillis 30 min in the widget info), and Store.save()
 * calls refreshAll() after every data change, the way Flutter's
 * providers refreshed the widget on wallet changes.
 */
public class QuickAddWidgetProvider extends AppWidgetProvider {

    @Override
    public void onUpdate(Context context, AppWidgetManager manager, int[] appWidgetIds) {
        RemoteViews views = buildViews(context);
        for (int id : appWidgetIds) {
            manager.updateAppWidget(id, views);
        }
    }

    /** Push fresh views to every placed widget; no-op when none. */
    public static void refreshAll(Context context) {
        try {
            AppWidgetManager manager = AppWidgetManager.getInstance(context);
            ComponentName name = new ComponentName(context, QuickAddWidgetProvider.class);
            int[] ids = manager.getAppWidgetIds(name);
            if (ids.length == 0) return;
            RemoteViews views = buildViews(context);
            for (int id : ids) manager.updateAppWidget(id, views);
        } catch (Throwable ignored) {
            // A widget refresh must never break a data save.
        }
    }

    static RemoteViews buildViews(Context context) {
        RemoteViews views = new RemoteViews(context.getPackageName(),
                R.layout.quick_add_widget);
        views.setTextViewText(R.id.tv_widget_balance, balanceText(context));
        views.setOnClickPendingIntent(R.id.widget_root, deepLink(context,
                "smartwallet://open-dashboard", 0));
        views.setOnClickPendingIntent(R.id.btn_quick_expense, deepLink(context,
                "smartwallet://quick-add?type=expense", 1));
        views.setOnClickPendingIntent(R.id.btn_quick_income, deepLink(context,
                "smartwallet://quick-add?type=income", 2));
        views.setOnClickPendingIntent(R.id.btn_quick_split, deepLink(context,
                "smartwallet://quick-add?type=split", 3));
        return views;
    }

    private static PendingIntent deepLink(Context context, String uri, int requestCode) {
        Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(uri),
                context, MainActivity.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        return PendingIntent.getActivity(context, requestCode, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    /**
     * Formatted net balance exactly like Flutter's WidgetService:
     * optional '-' + currency symbol + absolute value, 2 decimals,
     * no grouping (e.g. ₹1,500.00 would print as ₹1500.00 — Flutter's
     * toStringAsFixed behaviour, kept for parity).
     */
    static String balanceText(Context context) {
        double net = 0;
        String currency = "INR";
        try {
            File file = new File(context.getFilesDir(), "smartwallet_db.json");
            if (file.exists()) {
                String json = readFile(file);
                WalletDb db = Store.parse(json);
                net = WalletLogic.netWallet(db.accounts);
                if (db.user != null && db.user.baseCurrency != null) {
                    currency = db.user.baseCurrency;
                }
            }
        } catch (Exception ignored) {
            // A broken read shows ₹0.00 rather than crashing the launcher.
        }
        return WidgetFormat.formatBalance(net, currency);
    }

    private static String readFile(File file) throws Exception {
        FileInputStream in = new FileInputStream(file);
        try {
            byte[] buf = new byte[(int) file.length()];
            int off = 0;
            int n;
            while (off < buf.length && (n = in.read(buf, off, buf.length - off)) != -1) {
                off += n;
            }
            return new String(buf, 0, off, "UTF-8");
        } finally {
            in.close();
        }
    }
}
