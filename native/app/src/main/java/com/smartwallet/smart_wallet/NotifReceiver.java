package com.smartwallet.smart_wallet;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Posts the notifications that NotifService scheduled with AlarmManager. */
public class NotifReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context ctx, Intent intent) {
        int id = intent.getIntExtra(NotifService.EXTRA_ID, 0);
        String title = intent.getStringExtra(NotifService.EXTRA_TITLE);
        String body = intent.getStringExtra(NotifService.EXTRA_BODY);
        if (id == 0 || title == null) return;

        NotifService.ensureChannel(ctx);
        NotificationManager nm = (NotificationManager)
                ctx.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null) return;

        Intent open = new Intent(ctx, MainActivity.class);
        open.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent contentPi = PendingIntent.getActivity(ctx, id, open,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        Notification n = new Notification.Builder(ctx, NotifService.CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(new Notification.BigTextStyle().bigText(body))
                .setContentIntent(contentPi)
                .setAutoCancel(true)
                .build();
        try {
            nm.notify(id, n);
        } catch (SecurityException ignored) {
            // POST_NOTIFICATIONS not granted — nothing to do.
        }

        // The daily alarm is one-shot: chain tomorrow's by re-syncing.
        if (id == NotifService.DAILY_ID) {
            NotifService.sync(ctx);
        }
    }
}
