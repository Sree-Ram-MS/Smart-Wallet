package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.widget.CheckBox;
import android.widget.CompoundButton;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.List;

/**
 * Phase 4: Import / Export — the last placeholder screen goes live.
 *
 * Backup export/import uses the Flutter .smartwallet format via
 * BackupCodec (plain or password-encrypted, byte-compatible both
 * ways); CSV export/import uses CsvCodec (Flutter's exact format and
 * import behaviour). All file access goes through the Storage Access
 * Framework (ACTION_CREATE_DOCUMENT / ACTION_OPEN_DOCUMENT), so the
 * app needs NO new permissions.
 *
 * Restore safety: the backup is parsed fully and previewed before
 * anything is touched; confirming first saves a rotating safety
 * snapshot of the live DB, and "Undo Last Restore" swaps it back.
 */
public class ImportExportActivity extends Activity {

    private static final int REQ_CREATE_BACKUP = 4101;
    private static final int REQ_OPEN_BACKUP = 4102;
    private static final int REQ_CREATE_CSV = 4103;
    private static final int REQ_OPEN_CSV = 4104;
    private static final int REQ_DRIVE_RECOVERY = 4105;

    private Store store;
    private WalletDb db;
    private LinearLayout body;
    private TextView status;
    private TextView undoButton;

    // Phase 5: Google Drive section state.
    private DriveBackupService drive;
    private TextView driveInfo;
    private android.widget.Button driveBackupBtn;
    private android.widget.Button driveRestoreBtn;
    private boolean driveBusy;
    private Intent pendingRecoveryIntent;

    private String pendingBackupContent;
    private String pendingCsvContent;
    private String pendingImportContent;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = new Store(this);
        db = store.db();

        LinearLayout root = Ui.page(this, "Import / Export", null);
        android.widget.ScrollView scroll = Ui.scrollBody(this, root);
        body = (LinearLayout) scroll.getChildAt(0);
        setContentView(root);
        render();
    }

    @Override
    protected void onResume() {
        super.onResume();
        db = store.load();
        refreshUndoVisibility();
    }

    // ------------------------------------------------------------------ UI

    private void render() {
        body.removeAllViews();

        TextView intro = Ui.tv(this, "Your data lives only on this phone. "
                + "Back it up to a .smartwallet file — the same format the "
                + "Flutter app uses, so backups move between them freely.",
                13, Ui.SECONDARY, false);
        body.addView(intro);

        // ---- Backup card ----
        LinearLayout backup = Ui.card(this, Ui.CARD);
        backup.setLayoutParams(Ui.lpTop(this, 16));
        TextView bt = Ui.tv(this, "💾  Backup (.smartwallet)", 16, Ui.TEXT, true);
        backup.addView(bt);
        TextView bd = Ui.tv(this, "Export the whole wallet — accounts, "
                + "categories, transactions, planned payments, debts and "
                + "templates — optionally protected with a password. "
                + "Import restores a backup, replacing everything.",
                12, Ui.SECONDARY, false);
        bd.setLayoutParams(Ui.lpTop(this, 6));
        backup.addView(bd);

        TextView exportBtn = Ui.primaryButton(this, "Export Backup", Ui.PRIMARY);
        exportBtn.setLayoutParams(Ui.lpTop(this, 12));
        exportBtn.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { askBackupPasswordAndExport(); }
        });
        backup.addView(exportBtn);

        TextView importBtn = Ui.primaryButton(this, "Import / Restore Backup", Ui.ACCENT);
        importBtn.setLayoutParams(Ui.lpTop(this, 10));
        importBtn.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                openDocument(REQ_OPEN_BACKUP);
            }
        });
        backup.addView(importBtn);

        undoButton = Ui.dangerButton(this, "Undo Last Restore");
        undoButton.setLayoutParams(Ui.lpTop(this, 10));
        undoButton.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { confirmUndo(); }
        });
        backup.addView(undoButton);
        body.addView(backup);

        // ---- CSV card ----
        LinearLayout csv = Ui.card(this, Ui.CARD);
        csv.setLayoutParams(Ui.lpTop(this, 14));
        TextView ct = Ui.tv(this, "📊  Spreadsheet (CSV)", 16, Ui.TEXT, true);
        csv.addView(ct);
        TextView cd = Ui.tv(this, "Export all transactions to a CSV for "
                + "Excel or Google Sheets, in the Flutter app's format. "
                + "Import reads the same format — like Flutter, imported "
                + "rows land in your first account with no category.",
                12, Ui.SECONDARY, false);
        cd.setLayoutParams(Ui.lpTop(this, 6));
        csv.addView(cd);

        TextView csvExportBtn = Ui.primaryButton(this, "Export Transactions (CSV)", Ui.PRIMARY);
        csvExportBtn.setLayoutParams(Ui.lpTop(this, 12));
        csvExportBtn.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                pendingCsvContent = CsvCodec.exportCsv(store.db());
                createDocument(REQ_CREATE_CSV, "text/csv",
                        "smart_wallet_export_" + System.currentTimeMillis() + ".csv");
            }
        });
        csv.addView(csvExportBtn);

        TextView csvImportBtn = Ui.primaryButton(this, "Import Transactions (CSV)", Ui.ACCENT);
        csvImportBtn.setLayoutParams(Ui.lpTop(this, 10));
        csvImportBtn.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { openDocument(REQ_OPEN_CSV); }
        });
        csv.addView(csvImportBtn);
        body.addView(csv);

        // ---- Google Drive card (Phase 5) ----
        body.addView(buildDriveCard());

        status = Ui.tv(this, "", 13, Ui.SECONDARY, false);
        status.setLayoutParams(Ui.lpTop(this, 16));
        body.addView(status);
        refreshUndoVisibility();
    }

    private void refreshUndoVisibility() {
        if (undoButton != null) {
            undoButton.setVisibility(
                    store != null && store.hasSafetySnapshot() ? View.VISIBLE : View.GONE);
        }
    }

    private void setStatus(String msg) {
        if (status != null) status.setText(msg);
    }

    private void toast(String msg) {
        Toast.makeText(this, msg, Toast.LENGTH_LONG).show();
    }

    // ------------------------------------------------------------- SAF plumbing

    private void createDocument(int requestCode, String mime, String title) {
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType(mime);
        intent.putExtra(Intent.EXTRA_TITLE, title);
        startActivityForResult(intent, requestCode);
    }

    private void openDocument(int requestCode) {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        startActivityForResult(intent, requestCode);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        // Phase 5 results carry no content URI — handle them first.
        if (requestCode == AuthService.RC_SIGN_IN) {
            handleLinkResult(data);
            return;
        }
        if (requestCode == REQ_DRIVE_RECOVERY) {
            pendingRecoveryIntent = null;
            if (resultCode == RESULT_OK) {
                toast("Drive permission granted — tap the Drive action again.");
                render();
            }
            return;
        }
        if (resultCode != RESULT_OK || data == null || data.getData() == null) return;
        Uri uri = data.getData();
        try {
            if (requestCode == REQ_CREATE_BACKUP) {
                writeAll(uri, pendingBackupContent);
                pendingBackupContent = null;
                setStatus("Backup exported.");
                toast("Backup exported.");
            } else if (requestCode == REQ_CREATE_CSV) {
                writeAll(uri, pendingCsvContent);
                pendingCsvContent = null;
                setStatus("CSV exported.");
                toast("CSV exported.");
            } else if (requestCode == REQ_OPEN_BACKUP) {
                pendingImportContent = readAll(uri);
                startBackupImport();
            } else if (requestCode == REQ_OPEN_CSV) {
                startCsvImport(readAll(uri));
            }
        } catch (Exception e) {
            setStatus("Failed: " + e.getMessage());
            toast("Failed: " + e.getMessage());
        }
    }

    private void writeAll(Uri uri, String content) throws Exception {
        if (content == null) throw new Exception("Nothing to write.");
        OutputStream out = getContentResolver().openOutputStream(uri);
        if (out == null) throw new Exception("Could not open the chosen file.");
        out.write(content.getBytes(StandardCharsets.UTF_8));
        out.close();
    }

    private String readAll(Uri uri) throws Exception {
        InputStream in = getContentResolver().openInputStream(uri);
        if (in == null) throw new Exception("Could not open the chosen file.");
        ByteArrayOutputStream buf = new ByteArrayOutputStream();
        byte[] chunk = new byte[8192];
        int n;
        while ((n = in.read(chunk)) != -1) buf.write(chunk, 0, n);
        in.close();
        return new String(buf.toByteArray(), StandardCharsets.UTF_8);
    }

    // ------------------------------------------------- Google Drive (Phase 5)

    private LinearLayout buildDriveCard() {
        if (drive == null) {
            drive = new DriveBackupService(this,
                    DriveBackupService.authServiceProvider(this));
        }
        LinearLayout card = Ui.card(this, Ui.CARD);
        card.setLayoutParams(Ui.lpTop(this, 14));
        card.addView(Ui.tv(this, "☁️  Google Drive Backup", 16, Ui.TEXT, true));
        TextView desc = Ui.tv(this, "Back up the same .smartwallet file to "
                + "your Google Drive app folder — only this app can see it. "
                + "Restoring uses the same preview + undo safety as a local "
                + "file.", 12, Ui.SECONDARY, false);
        desc.setLayoutParams(Ui.lpTop(this, 6));
        card.addView(desc);

        UserProfile user = store.db().user;
        boolean googleUser = user != null && !user.isGuest();
        if (!googleUser) {
            TextView need = Ui.tv(this, user == null
                    ? "Sign in with Google to use Drive backup."
                    : "Drive backup needs a Google account — you are a guest.",
                    12, Ui.EXPENSE, false);
            need.setLayoutParams(Ui.lpTop(this, 10));
            card.addView(need);
            if (user != null) {
                TextView link = Ui.primaryButton(this, "Link Google Account", Ui.PRIMARY);
                link.setLayoutParams(Ui.lpTop(this, 10));
                link.setOnClickListener(new View.OnClickListener() {
                    @Override public void onClick(View v) {
                        startActivityForResult(AuthService.signInIntent(
                                ImportExportActivity.this), AuthService.RC_SIGN_IN);
                    }
                });
                card.addView(link);
            }
            return card;
        }

        TextView account = Ui.tv(this, "Account: " + user.email, 12, Ui.SECONDARY, false);
        account.setLayoutParams(Ui.lpTop(this, 8));
        card.addView(account);

        String last = AppPrefs.lastCloudBackup(this);
        TextView lastTv = Ui.tv(this, last == null
                ? "Last cloud backup (from this device): never"
                : "Last cloud backup (from this device): " + CsvCodec.formatCsvDate(last),
                12, Ui.SECONDARY, false);
        lastTv.setLayoutParams(Ui.lpTop(this, 2));
        card.addView(lastTv);

        driveInfo = Ui.tv(this, "Cloud backup: checking…", 12, Ui.TEXT, false);
        driveInfo.setLayoutParams(Ui.lpTop(this, 6));
        card.addView(driveInfo);

        driveBackupBtn = Ui.primaryButton(this, "☁️ Backup to Drive", Ui.PRIMARY);
        driveBackupBtn.setLayoutParams(Ui.lpTop(this, 12));
        driveBackupBtn.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { askDrivePasswordAndBackup(); }
        });
        card.addView(driveBackupBtn);

        driveRestoreBtn = Ui.primaryButton(this, "⬇️ Restore from Drive", Ui.ACCENT);
        driveRestoreBtn.setLayoutParams(Ui.lpTop(this, 10));
        driveRestoreBtn.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { doDriveRestore(); }
        });
        card.addView(driveRestoreBtn);

        if (pendingRecoveryIntent != null) {
            TextView grant = Ui.primaryButton(this, "Grant Drive Access", Ui.EXPENSE);
            grant.setLayoutParams(Ui.lpTop(this, 10));
            grant.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) {
                    try {
                        startActivityForResult(pendingRecoveryIntent, REQ_DRIVE_RECOVERY);
                    } catch (Exception e) {
                        toast("Could not open the permission screen: " + e.getMessage());
                    }
                }
            });
            card.addView(grant);
        }

        refreshDriveInfo();
        return card;
    }

    private void handleLinkResult(Intent data) {
        try {
            com.google.android.gms.auth.api.signin.GoogleSignInAccount account =
                    AuthService.accountFromIntent(data);
            if (account == null) return;
            WalletDb live = store.db();
            if (live.user != null && live.user.isGuest()) {
                AuthService.applyLinkedAccount(live.user, account);
            } else if (live.user == null) {
                live.user = AuthService.userFromAccount(account);
            }
            store.save();
            AppPrefs.setSignedIn(this, true);
            toast("Google account linked: " + live.user.email);
            render();
        } catch (com.google.android.gms.common.api.ApiException e) {
            if (e.getStatusCode() != 12501) {
                toast("Google Sign-In failed (code " + e.getStatusCode() + ")");
            }
        }
    }

    private void setDriveBusy(boolean busy, String message) {
        driveBusy = busy;
        if (driveBackupBtn != null) driveBackupBtn.setEnabled(!busy);
        if (driveRestoreBtn != null) driveRestoreBtn.setEnabled(!busy);
        if (message != null) setStatus(message);
    }

    private void driveError(final String message, final Intent recovery) {
        runOnUiThread(new Runnable() {
            @Override public void run() {
                if (isFinishing()) return;
                setDriveBusy(false, null);
                if (recovery != null) {
                    pendingRecoveryIntent = recovery;
                    toast(message + " Tap “Grant Drive Access” below.");
                    render();
                } else {
                    toast("Drive: " + message);
                    setStatus("Drive failed: " + message);
                }
            }
        });
    }

    private void refreshDriveInfo() {
        drive.fetchInfo(new DriveBackupService.Callback<DriveCodec.BackupInfo>() {
            @Override public void onOk(final DriveCodec.BackupInfo info) {
                runOnUiThread(new Runnable() {
                    @Override public void run() {
                        if (isFinishing() || driveInfo == null) return;
                        driveInfo.setText(info == null
                                ? "Cloud backup: none yet"
                                : "Cloud backup: " + info.prettyModified()
                                        + "  •  " + info.prettySize());
                    }
                });
            }
            @Override public void onError(String message, Intent recovery) {
                // Quiet on the info probe (the screen may be guest-less
                // for other reasons); actions surface their own errors.
                runOnUiThread(new Runnable() {
                    @Override public void run() {
                        if (!isFinishing() && driveInfo != null) {
                            driveInfo.setText("Cloud backup: sign-in needed");
                        }
                    }
                });
            }
        });
    }

    private void askDrivePasswordAndBackup() {
        if (driveBusy) return;
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(48, 16, 48, 0);
        final CheckBox usePw = new CheckBox(this);
        usePw.setText("Password protect / encrypt");
        usePw.setTextColor(Ui.TEXT);
        box.addView(usePw);
        final EditText pw = Ui.input(this, "Enter backup password", "");
        pw.setInputType(android.text.InputType.TYPE_CLASS_TEXT
                | android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD);
        pw.setEnabled(false);
        box.addView(pw);
        usePw.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override public void onCheckedChanged(CompoundButton b, boolean checked) {
                pw.setEnabled(checked);
            }
        });
        new AlertDialog.Builder(this)
                .setTitle("Backup to Google Drive")
                .setView(box)
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Back Up", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface d, int which) {
                        final String password =
                                usePw.isChecked() ? pw.getText().toString().trim() : "";
                        doDriveBackup(password);
                    }
                })
                .show();
    }

    private void doDriveBackup(final String password) {
        setDriveBusy(true, "Preparing backup…");
        new Thread(new Runnable() {
            @Override public void run() {
                final byte[] bytes;
                try {
                    String now = WalletLogic.nowIso();
                    WalletDb live = store.db();
                    String content = password.isEmpty()
                            ? BackupCodec.createPlainBackup(live, now)
                            : BackupCodec.createEncryptedBackup(live, password, now);
                    bytes = content.getBytes(StandardCharsets.UTF_8);
                } catch (final Exception e) {
                    runOnUiThread(new Runnable() {
                        @Override public void run() {
                            setDriveBusy(false, null);
                            toast("Backup failed: " + e.getMessage());
                        }
                    });
                    return;
                }
                runOnUiThread(new Runnable() {
                    @Override public void run() {
                        setStatus("Uploading backup to Google Drive…");
                    }
                });
                drive.upload(bytes, new DriveBackupService.Callback<DriveCodec.BackupInfo>() {
                    @Override public void onOk(final DriveCodec.BackupInfo info) {
                        AppPrefs.setLastCloudBackup(ImportExportActivity.this,
                                WalletLogic.nowIso());
                        runOnUiThread(new Runnable() {
                            @Override public void run() {
                                if (isFinishing()) return;
                                setDriveBusy(false, null);
                                toast("☁️ Backup uploaded to Google Drive");
                                setStatus("Drive backup complete"
                                        + (info != null ? " — " + info.prettyModified()
                                                + " • " + info.prettySize() : "") + ".");
                                render();
                            }
                        });
                    }
                    @Override public void onError(String message, Intent recovery) {
                        driveError(message, recovery);
                    }
                });
            }
        }, "drive-prep").start();
    }

    private void doDriveRestore() {
        if (driveBusy) return;
        setDriveBusy(true, "Checking Google Drive…");
        drive.fetchInfo(new DriveBackupService.Callback<DriveCodec.BackupInfo>() {
            @Override public void onOk(final DriveCodec.BackupInfo info) {
                if (info == null) {
                    runOnUiThread(new Runnable() {
                        @Override public void run() {
                            if (isFinishing()) return;
                            setDriveBusy(false, null);
                            toast("No backup found in Google Drive.");
                            setStatus("No backup found in Google Drive.");
                        }
                    });
                    return;
                }
                runOnUiThread(new Runnable() {
                    @Override public void run() {
                        if (!isFinishing()) setStatus("Downloading backup from Drive…");
                    }
                });
                drive.download(info.fileId, new DriveBackupService.Callback<byte[]>() {
                    @Override public void onOk(final byte[] bytes) {
                        runOnUiThread(new Runnable() {
                            @Override public void run() {
                                if (isFinishing()) return;
                                setDriveBusy(false, null);
                                // SAME preview + confirm + undo flow as a
                                // local file restore (Phase 4).
                                pendingImportContent =
                                        new String(bytes, StandardCharsets.UTF_8);
                                startBackupImport();
                            }
                        });
                    }
                    @Override public void onError(String message, Intent recovery) {
                        driveError(message, recovery);
                    }
                });
            }
            @Override public void onError(String message, Intent recovery) {
                driveError(message, recovery);
            }
        });
    }

    // ------------------------------------------------------------- backup export

    private void askBackupPasswordAndExport() {
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(48, 16, 48, 0);
        final CheckBox usePw = new CheckBox(this);
        usePw.setText("Password protect / encrypt");
        usePw.setTextColor(Ui.TEXT);
        box.addView(usePw);
        final EditText pw = Ui.input(this, "Enter backup password", "");
        pw.setInputType(android.text.InputType.TYPE_CLASS_TEXT
                | android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD);
        pw.setEnabled(false);
        box.addView(pw);
        usePw.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override public void onCheckedChanged(CompoundButton b, boolean checked) {
                pw.setEnabled(checked);
            }
        });
        new AlertDialog.Builder(this)
                .setTitle("Export Backup")
                .setView(box)
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Export", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface d, int which) {
                        String password = usePw.isChecked() ? pw.getText().toString().trim() : "";
                        try {
                            String now = WalletLogic.nowIso();
                            WalletDb live = store.db();
                            pendingBackupContent = password.isEmpty()
                                    ? BackupCodec.createPlainBackup(live, now)
                                    : BackupCodec.createEncryptedBackup(live, password, now);
                            createDocument(REQ_CREATE_BACKUP, "application/octet-stream",
                                    "smart_wallet_backup_" + System.currentTimeMillis()
                                            + ".smartwallet");
                        } catch (Exception e) {
                            toast("Export failed: " + e.getMessage());
                        }
                    }
                })
                .show();
    }

    // ------------------------------------------------------------- backup import

    private void startBackupImport() {
        try {
            BackupCodec.Inspection in = BackupCodec.inspect(pendingImportContent);
            if (in.isEncrypted) {
                askImportPassword();
            } else {
                previewAndConfirm(null);
            }
        } catch (BackupCodec.BackupException e) {
            showError("Not a Smart Wallet backup", e.getMessage());
        }
    }

    private void askImportPassword() {
        final EditText pw = Ui.input(this, "Password", "");
        pw.setInputType(android.text.InputType.TYPE_CLASS_TEXT
                | android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD);
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(48, 16, 48, 0);
        box.addView(pw);
        new AlertDialog.Builder(this)
                .setTitle("Password Protected Backup")
                .setMessage("This backup is password protected. Enter the password:")
                .setView(box)
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Unlock", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface d, int which) {
                        previewAndConfirm(pw.getText().toString().trim());
                    }
                })
                .show();
    }

    private void previewAndConfirm(String password) {
        final BackupCodec.Preview preview;
        try {
            preview = BackupCodec.loadPreview(pendingImportContent, password);
        } catch (BackupCodec.WrongPasswordException e) {
            new AlertDialog.Builder(this)
                    .setTitle("Could not unlock backup")
                    .setMessage(e.getMessage())
                    .setNegativeButton("Cancel", null)
                    .setPositiveButton("Try Again", new DialogInterface.OnClickListener() {
                        @Override public void onClick(DialogInterface d, int which) {
                            askImportPassword();
                        }
                    })
                    .show();
            return;
        } catch (BackupCodec.BackupException e) {
            showError("Backup could not be read", e.getMessage());
            return;
        }

        String created = preview.createdAt == null || preview.createdAt.isEmpty()
                ? "Unknown date" : CsvCodec.formatCsvDate(preview.createdAt);
        String text = "Created: " + created + "\n"
                + "Encrypted: " + (preview.isEncrypted ? "Yes" : "No") + "\n"
                + "User: " + preview.userName + " (" + preview.currency + ")\n\n"
                + "Accounts: " + preview.accountsCount + "\n"
                + "Categories: " + preview.categoriesCount + "\n"
                + "Transactions: " + preview.transactionsCount + "\n"
                + "Planned payments: " + preview.plannedCount + "\n"
                + "Debts & credits: " + preview.debtsCount + "\n"
                + "Templates: " + preview.templatesCount + "\n\n"
                + "⚠️ This replaces ALL current data in the app. "
                + "A safety snapshot of your current data is saved first, "
                + "and you can undo the restore from this screen.";
        new AlertDialog.Builder(this)
                .setTitle("Restore this backup?")
                .setMessage(text)
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Restore — Replace All",
                        new DialogInterface.OnClickListener() {
                            @Override public void onClick(DialogInterface d, int which) {
                                doRestore(preview);
                            }
                        })
                .show();
    }

    private void doRestore(BackupCodec.Preview preview) {
        if (!store.saveSafetySnapshot()) {
            showError("Restore stopped",
                    "The safety snapshot of your current data could not be "
                            + "saved, so nothing was restored.");
            return;
        }
        store.replaceDb(preview.db);
        NotifService.sync(this);
        pendingImportContent = null;
        refreshUndoVisibility();
        toast("Backup restored.");
        goDashboard();
    }

    private void confirmUndo() {
        new AlertDialog.Builder(this)
                .setTitle("Undo last restore?")
                .setMessage("This brings back the data as it was just before "
                        + "the last restore. The restored data is kept as the "
                        + "new safety snapshot, so you can undo the undo.")
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Undo Restore", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface d, int which) {
                        try {
                            WalletDb snapshot = store.loadSafetySnapshot();
                            store.saveSafetySnapshot(); // rotate current into safety
                            store.replaceDb(snapshot);
                            NotifService.sync(ImportExportActivity.this);
                            refreshUndoVisibility();
                            toast("Restore undone.");
                            goDashboard();
                        } catch (Exception e) {
                            showError("Undo failed", e.getMessage());
                        }
                    }
                })
                .show();
    }

    private void goDashboard() {
        Intent intent = new Intent(this, MainActivity.class);
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
        startActivity(intent);
        finish();
    }

    // ------------------------------------------------------------- CSV import

    private void startCsvImport(final String content) {
        final List<List<String>> rows;
        try {
            rows = CsvCodec.parseCsv(content);
        } catch (Exception e) {
            showError("CSV could not be read", e.getMessage());
            return;
        }
        if (rows.size() < 2) {
            setStatus("CSV is empty or invalid.");
            toast("CSV is empty or invalid.");
            return;
        }
        int dataRows = rows.size() - 1;
        String first = store.db().accounts.isEmpty()
                ? "(you have no accounts — every row will be skipped)"
                : store.db().accounts.get(0).name;
        new AlertDialog.Builder(this)
                .setTitle("Import Preview")
                .setMessage("Found " + dataRows + " transactions. Import will "
                        + "add them to your first account (" + first + ").")
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Import", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface d, int which) {
                        try {
                            CsvCodec.ImportResult result = CsvCodec.importCsv(
                                    store.db(), content,
                                    "tx_csv_" + System.currentTimeMillis(),
                                    WalletLogic.nowIso());
                            store.save();
                            StringBuilder sb = new StringBuilder();
                            sb.append("Imported ").append(result.imported)
                                    .append(" transactions from CSV.");
                            if (result.skipped > 0) {
                                sb.append("\nSkipped ").append(result.skipped).append(":");
                                int shown = Math.min(5, result.skipReasons.size());
                                for (int i = 0; i < shown; i++) {
                                    sb.append("\n• ").append(result.skipReasons.get(i));
                                }
                                if (result.skipReasons.size() > shown) {
                                    sb.append("\n• …and ")
                                            .append(result.skipReasons.size() - shown)
                                            .append(" more");
                                }
                            }
                            setStatus(sb.toString());
                            toast("Imported " + result.imported + " transactions from CSV!");
                        } catch (Exception e) {
                            showError("CSV import failed", e.getMessage());
                        }
                    }
                })
                .show();
    }

    private void showError(String title, String message) {
        new AlertDialog.Builder(this)
                .setTitle(title)
                .setMessage(message == null ? "Unknown error" : message)
                .setPositiveButton("OK", null)
                .show();
        setStatus(title + ": " + message);
    }
}
