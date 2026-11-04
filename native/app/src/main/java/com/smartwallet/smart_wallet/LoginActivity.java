package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import com.google.android.gms.auth.api.signin.GoogleSignInAccount;
import com.google.android.gms.common.api.ApiException;

/**
 * Login screen (Phase 5) — the app's LAUNCHER entry and session
 * gate, mirroring Flutter's login_screen.dart: gradient wallet tile,
 * "Smart Wallet", "Your personal finance companion", three feature
 * rows, a white "Continue with Google" button, an outlined
 * "Continue as Guest", and the local-storage footer.
 *
 * If a session already exists this activity forwards straight to
 * MainActivity, which applies the biometric part of the gate.
 */
public class LoginActivity extends Activity {

    private TextView statusTv;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(Ui.BG);
        getWindow().setNavigationBarColor(Ui.BG);

        Store store = new Store(this);
        WalletDb db = store.db();
        boolean signedIn = AppPrefs.signedIn(this) && db.user != null;
        if (signedIn) {
            startActivity(new Intent(this, MainActivity.class));
            finish();
            return;
        }
        buildUi();
    }

    private void buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Ui.BG);
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        root.setPadding(dp(28), dp(48), dp(28), dp(24));
        setContentView(root);

        // Gradient wallet tile (Flutter: purple -> teal gradient box).
        TextView logo = new TextView(this);
        logo.setText("👛");
        logo.setTextSize(40);
        logo.setGravity(Gravity.CENTER);
        GradientDrawable tile = new GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                new int[]{Ui.PRIMARY, Ui.ACCENT});
        tile.setCornerRadius(dp(24));
        logo.setBackground(tile);
        LinearLayout.LayoutParams logoLp = new LinearLayout.LayoutParams(dp(84), dp(84));
        logo.setLayoutParams(logoLp);
        root.addView(logo);

        TextView title = Ui.tv(this, "Smart Wallet", 30, Ui.TEXT, true);
        title.setGravity(Gravity.CENTER);
        title.setLayoutParams(Ui.lpTop(this, 24));
        root.addView(title);

        TextView subtitle = Ui.tv(this, "Your personal finance companion",
                15, Ui.SECONDARY, false);
        subtitle.setGravity(Gravity.CENTER);
        subtitle.setLayoutParams(Ui.lpTop(this, 6));
        root.addView(subtitle);

        LinearLayout features = new LinearLayout(this);
        features.setOrientation(LinearLayout.VERTICAL);
        features.setLayoutParams(Ui.lpTop(this, 40));
        features.addView(featureRow("💳", "Multiple Accounts"));
        features.addView(featureRow("📊", "Spending Charts"));
        features.addView(featureRow("🔒", "Biometric Lock"));
        root.addView(features);

        Button google = new Button(this);
        google.setText("G   Continue with Google");
        google.setTextSize(16);
        google.setTextColor(Color.rgb(0x1F, 0x1F, 0x1F));
        google.setAllCaps(false);
        GradientDrawable gbg = new GradientDrawable();
        gbg.setColor(Color.WHITE);
        gbg.setCornerRadius(dp(14));
        google.setBackground(gbg);
        google.setLayoutParams(Ui.lpTop(this, 48));
        google.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                setStatus("");
                startActivityForResult(AuthService.signInIntent(LoginActivity.this),
                        AuthService.RC_SIGN_IN);
            }
        });
        root.addView(google);

        Button guest = new Button(this);
        guest.setText("Continue as Guest");
        guest.setTextSize(16);
        guest.setTextColor(Ui.TEXT);
        guest.setAllCaps(false);
        GradientDrawable obg = new GradientDrawable();
        obg.setColor(Color.TRANSPARENT);
        obg.setCornerRadius(dp(14));
        obg.setStroke(dp(1), Ui.SECONDARY);
        guest.setBackground(obg);
        guest.setLayoutParams(Ui.lpTop(this, 12));
        guest.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                Store store = new Store(LoginActivity.this);
                WalletDb db = store.db();
                db.user = AuthService.guestUser();
                store.save();
                AppPrefs.setSignedIn(LoginActivity.this, true);
                goDashboard();
            }
        });
        root.addView(guest);

        statusTv = Ui.tv(this, "", 13, Ui.EXPENSE, false);
        statusTv.setGravity(Gravity.CENTER);
        statusTv.setLayoutParams(Ui.lpTop(this, 16));
        root.addView(statusTv);

        TextView footer = Ui.tv(this, "All data stored locally on your device",
                12, Ui.MUTED, false);
        footer.setGravity(Gravity.CENTER);
        footer.setLayoutParams(Ui.lpTop(this, 24));
        root.addView(footer);
    }

    private LinearLayout featureRow(String emoji, String text) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setLayoutParams(Ui.lpTop(this, 10));
        TextView e = Ui.tv(this, emoji, 18, Ui.TEXT, false);
        row.addView(e);
        TextView t = Ui.tv(this, "  " + text, 15, Ui.TEXT, false);
        row.addView(t);
        return row;
    }

    private void setStatus(String msg) {
        if (statusTv != null) statusTv.setText(msg);
    }

    private void goDashboard() {
        startActivity(new Intent(this, MainActivity.class));
        finish();
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != AuthService.RC_SIGN_IN) return;
        try {
            GoogleSignInAccount account = AuthService.accountFromIntent(data);
            if (account == null) {
                setStatus("Google Sign-In did not complete.");
                return;
            }
            Store store = new Store(this);
            WalletDb db = store.db();
            // Fresh sign-in replaces the profile (Flutter saveUser);
            // accounts/transactions are untouched.
            db.user = AuthService.userFromAccount(account);
            store.save();
            AppPrefs.setSignedIn(this, true);
            Toast.makeText(this, "Welcome, " + db.user.name + "!", Toast.LENGTH_SHORT).show();
            goDashboard();
        } catch (ApiException e) {
            if (e.getStatusCode() == 12501) { // user cancelled
                setStatus("");
                return;
            }
            String hint = e.getStatusCode() == 10
                    ? " (app signature not registered in Firebase yet — see Phase 5 notes)"
                    : "";
            setStatus("Google Sign-In failed (code " + e.getStatusCode() + ")" + hint);
        }
    }

    private int dp(int v) {
        return Ui.dp(this, v);
    }
}
