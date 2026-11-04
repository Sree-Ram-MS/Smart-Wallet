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
    private Switch bioSwitch;
    private boolean suppressBioListener;

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
            user.id = "guest_001";
            user.name = "Guest User";
            user.email = "guest@smartwallet.app";
            user.photoUrl = "";
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

        // ---- Account (Phase 5) ----
        TextView accHeading = Ui.tv(this, "ACCOUNT", 12, Ui.SECONDARY, true);
        accHeading.setLayoutParams(Ui.lpTop(this, 20));
        body.addView(accHeading);
        LinearLayout accCard = Ui.card(this, Ui.CARD);
        accCard.setLayoutParams(Ui.lpTop(this, 8));
        if (user.isGuest()) {
            accCard.addView(Ui.tv(this, "You are using a guest account. "
                    + "Link Google to back up to Drive — all your data stays.",
                    12, Ui.SECONDARY, false));
            Button link = Ui.primaryButton(this, "Link Google Account", Ui.PRIMARY);
            link.setLayoutParams(Ui.lpTop(this, 10));
            link.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) {
                    startActivityForResult(AuthService.signInIntent(SettingsActivity.this),
                            AuthService.RC_SIGN_IN);
                }
            });
            accCard.addView(link);
        } else {
            accCard.addView(Ui.tv(this, "✓ Signed in with Google", 13, Ui.ACCENT, false));
            accCard.addView(Ui.tv(this, "Drive backup is available in "
                    + "Import/Export.", 12, Ui.SECONDARY, false));
        }
        Button signOut = Ui.primaryButton(this, "Sign Out", Ui.CARD_ALT);
        signOut.setLayoutParams(Ui.lpTop(this, 10));
        signOut.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                new android.app.AlertDialog.Builder(SettingsActivity.this)
                        .setTitle("Sign out?")
                        .setMessage("Your wallet data stays on this phone. "
                                + "You will go back to the sign-in screen.")
                        .setNegativeButton("Cancel", null)
                        .setPositiveButton("Sign Out",
                                new android.content.DialogInterface.OnClickListener() {
                                    @Override public void onClick(
                                            android.content.DialogInterface d, int w) {
                                        doSignOut();
                                    }
                                })
                        .show();
            }
        });
        accCard.addView(signOut);
        body.addView(accCard);

        // ---- Security (Phase 5): biometric lock ----
        TextView secHeading = Ui.tv(this, "SECURITY", 12, Ui.SECONDARY, true);
        secHeading.setLayoutParams(Ui.lpTop(this, 20));
        body.addView(secHeading);
        LinearLayout secCard = Ui.card(this, Ui.CARD);
        secCard.setLayoutParams(Ui.lpTop(this, 8));
        BiometricGate.Status bioStatus = BiometricGate.status(this);
        LinearLayout bioRow = new LinearLayout(this);
        bioRow.setOrientation(LinearLayout.HORIZONTAL);
        bioRow.setGravity(android.view.Gravity.CENTER_VERTICAL);
        LinearLayout bioCol = new LinearLayout(this);
        bioCol.setOrientation(LinearLayout.VERTICAL);
        bioCol.setLayoutParams(new LinearLayout.LayoutParams(
                0, android.view.ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        bioCol.addView(Ui.tv(this, "Biometric lock", 14, Ui.TEXT, false));
        bioCol.addView(Ui.tv(this, bioStatusText(bioStatus), 11, Ui.SECONDARY, false));
        bioRow.addView(bioCol);
        bioSwitch = new Switch(this);
        bioSwitch.setChecked(user.biometricEnabled);
        bioSwitch.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override public void onCheckedChanged(CompoundButton b, boolean on) {
                if (suppressBioListener) return;
                if (!on) {
                    user.biometricEnabled = false;
                    applyChange("Biometric lock off.");
                    return;
                }
                // Enabling requires a successful prompt first.
                if (BiometricGate.status(SettingsActivity.this)
                        != BiometricGate.Status.AVAILABLE) {
                    Toast.makeText(SettingsActivity.this,
                            "No biometric available on this device",
                            Toast.LENGTH_LONG).show();
                    setBioSwitch(false);
                    return;
                }
                BiometricGate.prompt(SettingsActivity.this, new BiometricGate.Listener() {
                    @Override public void onSuccess() {
                        user.biometricEnabled = true;
                        applyChange("Biometric lock on.");
                    }
                    @Override public void onError(int code, String msg) {
                        setBioSwitch(false);
                        Toast.makeText(SettingsActivity.this,
                                "Biometric not enabled: " + msg,
                                Toast.LENGTH_SHORT).show();
                    }
                    @Override public void onFailed() {
                        Toast.makeText(SettingsActivity.this,
                                "Authentication failed. Try again.",
                                Toast.LENGTH_SHORT).show();
                    }
                });
            }
        });
        bioRow.addView(bioSwitch);
        secCard.addView(bioRow);
        body.addView(secCard);

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

    // ------------------------------------------------ Phase 5 helpers

    private String bioStatusText(BiometricGate.Status status) {
        switch (status) {
            case AVAILABLE:
                return "Ask for fingerprint / face at app start";
            case NOT_ENROLLED:
                return "No fingerprint or face enrolled on this device";
            case UNSUPPORTED_SDK:
                return "Needs Android 9 (API 28) or newer";
            default:
                return "No biometric hardware on this device";
        }
    }

    private void setBioSwitch(boolean on) {
        suppressBioListener = true;
        bioSwitch.setChecked(on);
        suppressBioListener = false;
    }

    private void doSignOut() {
        AuthService.signOut(this, new Runnable() {
            @Override public void run() {
                db.user = null; // Flutter clearUser(): data remains
                store.save();
                AppPrefs.setSignedIn(SettingsActivity.this, false);
                AppLock.unlockedThisSession = false;
                android.content.Intent i = new android.content.Intent(
                        SettingsActivity.this, LoginActivity.class);
                i.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                        | android.content.Intent.FLAG_ACTIVITY_CLEAR_TASK);
                startActivity(i);
                finish();
            }
        });
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode,
                                    android.content.Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != AuthService.RC_SIGN_IN) return;
        try {
            com.google.android.gms.auth.api.signin.GoogleSignInAccount account =
                    AuthService.accountFromIntent(data);
            if (account == null) return;
            // Link: identity fields only — data and preferences stay.
            AuthService.applyLinkedAccount(user, account);
            store.save();
            AppPrefs.setSignedIn(this, true);
            Toast.makeText(this, "Google account linked: " + user.email,
                    Toast.LENGTH_LONG).show();
            recreate();
        } catch (com.google.android.gms.common.api.ApiException e) {
            if (e.getStatusCode() != 12501) {
                Toast.makeText(this, "Google Sign-In failed (code "
                        + e.getStatusCode() + ")", Toast.LENGTH_LONG).show();
            }
        }
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
