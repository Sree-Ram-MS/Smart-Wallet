package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.app.TimePickerDialog;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.CompoundButton;
import android.widget.LinearLayout;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.TimePicker;
import android.widget.Toast;

import java.util.Locale;

/**
 * Phase 3 minimal Settings: profile display + the REMINDERS section
 * (daily reminder toggle/time, planned-payment reminder toggle and
 * days-before stepper) — the fields NotifService schedules from.
 * The full Settings screen (profile editing, currency, theme, backup
 * account) arrives with later phases.
 * Every change saves immediately and re-syncs the alarms, like
 * Flutter's settings handlers do.
 */
public class SettingsActivity extends Activity {

    private Store store;
    private WalletDb db;
    private UserProfile user;

    private TextView dailyTimeLabel;
    private TextView daysBeforeLabel;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = new Store(this);
        db = store.db();
        if (db.user == null) {
            // Store seeds from the starter file, which has a user; this
            // only guards a hand-wiped/very old data file (Flutter
            // creates the same guest defaults on first run).
            user = new UserProfile();
            user.id = "guest_user";
            user.name = "Guest User";
            user.email = "guest@smartwallet.local";
            user.isDarkMode = true;
            db.user = user;
            store.save();
        } else {
            user = db.user;
        }

        LinearLayout root = Ui.page(this, "Settings", null);
        android.widget.ScrollView scroll = Ui.scrollBody(this, root);
        LinearLayout body = (LinearLayout) scroll.getChildAt(0);
        setContentView(root);

        // ---- Profile (display only in this phase) ----
        LinearLayout profile = Ui.card(this, Ui.CARD);
        profile.setLayoutParams(Ui.lpTop(this, 10));
        LinearLayout prow = new LinearLayout(this);
        prow.setOrientation(LinearLayout.HORIZONTAL);
        prow.setGravity(android.view.Gravity.CENTER_VERTICAL);
        TextView avatar = Ui.tv(this, user.name != null && !user.name.isEmpty()
                ? user.name.substring(0, 1).toUpperCase(Locale.ENGLISH) : "G",
                22, Ui.TEXT, true);
        avatar.setGravity(android.view.Gravity.CENTER);
        avatar.setBackground(Ui.circle(Ui.PRIMARY, this));
        avatar.setLayoutParams(new LinearLayout.LayoutParams(
                Ui.dp(this, 52), Ui.dp(this, 52)));
        prow.addView(avatar);
        LinearLayout pcol = new LinearLayout(this);
        pcol.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams plp = new LinearLayout.LayoutParams(
                0, android.view.ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        plp.leftMargin = Ui.dp(this, 12);
        pcol.setLayoutParams(plp);
        pcol.addView(Ui.tv(this, user.name, 16, Ui.TEXT, true));
        pcol.addView(Ui.tv(this, (user.email != null ? user.email : "")
                + (user.baseCurrency != null
                        ? "  •  " + user.baseCurrency + " (₹)" : ""),
                12, Ui.SECONDARY, false));
        prow.addView(pcol);
        profile.addView(prow);
        body.addView(profile);
        TextView note = Ui.tv(this, "Profile editing, sign-in and backup "
                + "arrive in a later phase.", 11, Ui.SECONDARY, false);
        note.setLayoutParams(Ui.lpTop(this, 6));
        body.addView(note);

        // ---- Reminders ----
        TextView heading = Ui.tv(this, "REMINDERS", 12, Ui.SECONDARY, true);
        heading.setLayoutParams(Ui.lpTop(this, 20));
        body.addView(heading);

        LinearLayout remCard = Ui.card(this, Ui.CARD);
        remCard.setLayoutParams(Ui.lpTop(this, 8));

        remCard.addView(switchRow("Daily reminder",
                "A nudge to log today's transactions",
                user.dailyReminderEnabled, new CompoundButton.OnCheckedChangeListener() {
                    @Override public void onCheckedChanged(CompoundButton b, boolean on) {
                        user.dailyReminderEnabled = on;
                        applyChange(on ? "Daily reminder on." : "Daily reminder off.");
                    }
                }));

        LinearLayout timeRow = new LinearLayout(this);
        timeRow.setOrientation(LinearLayout.HORIZONTAL);
        timeRow.setGravity(android.view.Gravity.CENTER_VERTICAL);
        timeRow.setLayoutParams(Ui.lpTop(this, 10));
        LinearLayout tcol = new LinearLayout(this);
        tcol.setOrientation(LinearLayout.VERTICAL);
        tcol.setLayoutParams(new LinearLayout.LayoutParams(
                0, android.view.ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        tcol.addView(Ui.tv(this, "Daily reminder time", 14, Ui.TEXT, false));
        dailyTimeLabel = Ui.tv(this, "", 12, Ui.SECONDARY, false);
        tcol.addView(dailyTimeLabel);
        timeRow.addView(tcol);
        Button pick = new Button(this);
        pick.setText("Change");
        pick.setAllCaps(false);
        pick.setTextColor(Ui.TEXT);
        pick.setBackground(Ui.rounded(Ui.CARD_ALT, 10, this));
        pick.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                new TimePickerDialog(SettingsActivity.this,
                        new TimePickerDialog.OnTimeSetListener() {
                            @Override public void onTimeSet(TimePicker view, int h, int m) {
                                user.dailyReminderHour = h;
                                user.dailyReminderMinute = m;
                                refreshLabels();
                                applyChange("Daily reminder set to "
                                        + formatTime(h, m) + ".");
                            }
                        }, user.dailyReminderHour, user.dailyReminderMinute, false).show();
            }
        });
        timeRow.addView(pick);
        remCard.addView(timeRow);

        View divider = new View(this);
        divider.setBackgroundColor(Ui.CARD_ALT);
        LinearLayout.LayoutParams dlp = new LinearLayout.LayoutParams(
                android.view.ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this, 1));
        dlp.topMargin = Ui.dp(this, 12);
        dlp.bottomMargin = Ui.dp(this, 4);
        divider.setLayoutParams(dlp);
        remCard.addView(divider);

        remCard.addView(switchRow("Planned payment reminders",
                "A heads-up before a planned payment is due",
                user.plannedReminderEnabled, new CompoundButton.OnCheckedChangeListener() {
                    @Override public void onCheckedChanged(CompoundButton b, boolean on) {
                        user.plannedReminderEnabled = on;
                        applyChange(on ? "Planned reminders on." : "Planned reminders off.");
                    }
                }));

        LinearLayout daysRow = new LinearLayout(this);
        daysRow.setOrientation(LinearLayout.HORIZONTAL);
        daysRow.setGravity(android.view.Gravity.CENTER_VERTICAL);
        daysRow.setLayoutParams(Ui.lpTop(this, 10));
        LinearLayout dcol = new LinearLayout(this);
        dcol.setOrientation(LinearLayout.VERTICAL);
        dcol.setLayoutParams(new LinearLayout.LayoutParams(
                0, android.view.ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        dcol.addView(Ui.tv(this, "Remind me before", 14, Ui.TEXT, false));
        daysBeforeLabel = Ui.tv(this, "", 12, Ui.SECONDARY, false);
        dcol.addView(daysBeforeLabel);
        daysRow.addView(dcol);
        daysRow.addView(stepperButton("−", new View.OnClickListener() {
            @Override public void onClick(View v) {
                if (user.plannedReminderDaysBefore > 0) {
                    user.plannedReminderDaysBefore--;
                    refreshLabels();
                    applyChange(null);
                }
            }
        }));
        daysRow.addView(stepperButton("+", new View.OnClickListener() {
            @Override public void onClick(View v) {
                if (user.plannedReminderDaysBefore < 30) {
                    user.plannedReminderDaysBefore++;
                    refreshLabels();
                    applyChange(null);
                }
            }
        }));
        remCard.addView(daysRow);
        body.addView(remCard);

        if (!NotifService.canScheduleExact(this)) {
            TextView exact = Ui.tv(this, "⚠ Exact alarm timing is not granted "
                    + "to the app, so reminders may arrive a little late. "
                    + "For exact timing, allow \"Alarms & reminders\" for "
                    + "Smart Wallet in Android Settings → Apps → Special "
                    + "app access.", 12, Ui.EXPENSE, false);
            exact.setLayoutParams(Ui.lpTop(this, 12));
            body.addView(exact);
        }
        TextView foot = Ui.tv(this, "Reminders are scheduled on this phone "
                + "only — nothing leaves the device.", 11, Ui.SECONDARY, false);
        foot.setLayoutParams(Ui.lpTop(this, 12));
        body.addView(foot);

        refreshLabels();
    }

    private LinearLayout switchRow(String title, String subtitle, boolean checked,
                                   CompoundButton.OnCheckedChangeListener listener) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(android.view.Gravity.CENTER_VERTICAL);
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setLayoutParams(new LinearLayout.LayoutParams(
                0, android.view.ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        col.addView(Ui.tv(this, title, 14, Ui.TEXT, false));
        col.addView(Ui.tv(this, subtitle, 11, Ui.SECONDARY, false));
        row.addView(col);
        Switch sw = new Switch(this);
        sw.setChecked(checked);
        sw.setOnCheckedChangeListener(listener);
        row.addView(sw);
        return row;
    }

    private TextView stepperButton(String sign, View.OnClickListener onClick) {
        TextView b = Ui.tv(this, sign, 18, Ui.TEXT, true);
        b.setGravity(android.view.Gravity.CENTER);
        b.setBackground(Ui.rounded(Ui.CARD_ALT, 10, this));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                Ui.dp(this, 40), Ui.dp(this, 40));
        lp.leftMargin = Ui.dp(this, 8);
        b.setLayoutParams(lp);
        b.setOnClickListener(onClick);
        return b;
    }

    private void refreshLabels() {
        dailyTimeLabel.setText("Fires at " + formatTime(
                user.dailyReminderHour, user.dailyReminderMinute) + " every day");
        int d = user.plannedReminderDaysBefore;
        daysBeforeLabel.setText(d == 0 ? "On the due day, 9:00 AM"
                : d == 1 ? "1 day before, at 9:00 AM"
                : d + " days before, at 9:00 AM");
    }

    private void applyChange(String toastMsg) {
        store.save();
        NotifService.sync(this);
        if (toastMsg != null) {
            Toast.makeText(this, toastMsg, Toast.LENGTH_SHORT).show();
        }
    }

    static String formatTime(int h, int m) {
        int hour12 = h % 12 == 0 ? 12 : h % 12;
        return String.format(Locale.ENGLISH, "%d:%02d %s", hour12, m, h < 12 ? "AM" : "PM");
    }
}
