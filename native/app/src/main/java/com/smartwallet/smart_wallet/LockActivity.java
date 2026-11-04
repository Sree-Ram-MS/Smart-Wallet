package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

/**
 * Biometric lock screen (Phase 5), mirroring Flutter's
 * biometric_lock_screen.dart: auto-prompts on open, success goes to
 * the dashboard, failure shows "Authentication failed. Try again.",
 * and there is an Authenticate retry plus a Sign Out option.
 *
 * If the prompt cannot run at all (no hardware, nothing enrolled,
 * lockout), the user is let in with a notice instead of being
 * locked out forever — the gate only routes here when biometrics
 * looked available, and availability can change.
 */
public class LockActivity extends Activity {

    private static final int RC_DEVICE_CREDENTIAL = 4201;

    private TextView statusTv;
    private boolean prompting;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(Ui.BG);
        getWindow().setNavigationBarColor(Ui.BG);
        buildUi();
        // The gate said AVAILABLE, but re-check: if biometrics have
        // vanished since, don't strand the user on this screen.
        if (!BiometricGate.available(this)) {
            Toast.makeText(this, "Biometric unavailable — continuing without it",
                    Toast.LENGTH_LONG).show();
            unlock();
            return;
        }
        prompt();
    }

    private void buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(Ui.BG);
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        root.setPadding(dp(28), dp(72), dp(28), dp(24));
        setContentView(root);

        TextView icon = Ui.tv(this, "🔒", 44, Ui.TEXT, false);
        icon.setGravity(Gravity.CENTER);
        icon.setBackground(Ui.circle(Ui.CARD_ALT, this));
        icon.setLayoutParams(new LinearLayout.LayoutParams(dp(84), dp(84)));
        root.addView(icon);

        TextView title = Ui.tv(this, "Smart Wallet Locked", 22, Ui.TEXT, true);
        title.setGravity(Gravity.CENTER);
        title.setLayoutParams(Ui.lpTop(this, 24));
        root.addView(title);

        TextView sub = Ui.tv(this, "Authenticate to continue", 14, Ui.SECONDARY, false);
        sub.setGravity(Gravity.CENTER);
        sub.setLayoutParams(Ui.lpTop(this, 6));
        root.addView(sub);

        statusTv = Ui.tv(this, "", 13, Ui.EXPENSE, false);
        statusTv.setGravity(Gravity.CENTER);
        statusTv.setLayoutParams(Ui.lpTop(this, 16));
        root.addView(statusTv);

        Button auth = Ui.primaryButton(this, "Authenticate", Ui.PRIMARY);
        auth.setLayoutParams(Ui.lpTop(this, 32));
        auth.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                prompt();
            }
        });
        root.addView(auth);

        if (Build.VERSION.SDK_INT < 30) {
            // API 28–29 prompts can't fold in the device credential;
            // offer the keyguard prompt as a separate path.
            Button pin = Ui.primaryButton(this, "Use PIN / Password", Ui.CARD_ALT);
            pin.setLayoutParams(Ui.lpTop(this, 10));
            pin.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) {
                    Intent intent = BiometricGate.deviceCredentialIntent(LockActivity.this);
                    if (intent != null) {
                        startActivityForResult(intent, RC_DEVICE_CREDENTIAL);
                    } else {
                        Toast.makeText(LockActivity.this,
                                "No device credential set", Toast.LENGTH_SHORT).show();
                    }
                }
            });
            root.addView(pin);
        }

        Button signOut = Ui.primaryButton(this, "Sign Out", Ui.CARD_ALT);
        signOut.setLayoutParams(Ui.lpTop(this, 10));
        signOut.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                AuthService.signOut(LockActivity.this, new Runnable() {
                    @Override public void run() {
                        Store store = new Store(LockActivity.this);
                        WalletDb db = store.db();
                        db.user = null; // clearUser only — data remains
                        store.save();
                        AppPrefs.setSignedIn(LockActivity.this, false);
                        AppLock.unlockedThisSession = false;
                        Intent i = new Intent(LockActivity.this, LoginActivity.class);
                        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                                | Intent.FLAG_ACTIVITY_CLEAR_TASK);
                        startActivity(i);
                        finish();
                    }
                });
            }
        });
        root.addView(signOut);
    }

    private void prompt() {
        if (prompting) return;
        prompting = true;
        statusTv.setText("");
        BiometricGate.prompt(this, new BiometricGate.Listener() {
            @Override public void onSuccess() {
                prompting = false;
                unlock();
            }

            @Override public void onError(int errorCode, String message) {
                prompting = false;
                // Errors that mean "biometrics cannot run at all"
                // must never lock the user out.
                if (errorCode == android.hardware.biometrics.BiometricPrompt.BIOMETRIC_ERROR_NO_BIOMETRICS
                        || errorCode == android.hardware.biometrics.BiometricPrompt.BIOMETRIC_ERROR_HW_NOT_PRESENT
                        || errorCode == android.hardware.biometrics.BiometricPrompt.BIOMETRIC_ERROR_NO_DEVICE_CREDENTIAL) {
                    Toast.makeText(LockActivity.this,
                            "Biometric unavailable — continuing without it",
                            Toast.LENGTH_LONG).show();
                    unlock();
                    return;
                }
                if (errorCode == android.hardware.biometrics.BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT
                        || errorCode == android.hardware.biometrics.BiometricPrompt.BIOMETRIC_ERROR_LOCKOUT_PERMANENT) {
                    statusTv.setText("Too many attempts. Wait a bit, then try again.");
                    return;
                }
                statusTv.setText("Authentication failed. Try again.");
            }

            @Override public void onFailed() {
                statusTv.setText("Authentication failed. Try again.");
            }
        });
    }

    private void unlock() {
        AppLock.unlockedThisSession = true;
        startActivity(new Intent(this, MainActivity.class));
        finish();
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == RC_DEVICE_CREDENTIAL && resultCode == RESULT_OK) {
            unlock();
        }
    }

    private int dp(int v) {
        return Ui.dp(this, v);
    }
}
