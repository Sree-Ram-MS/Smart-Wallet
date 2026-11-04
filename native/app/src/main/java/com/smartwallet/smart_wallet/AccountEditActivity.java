package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.text.InputType;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.Spinner;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.List;

/**
 * Phase 2: add / edit / delete an account. The balance field edits the
 * stored balance directly (that IS the account's current balance, as
 * in Flutter). Delete is guarded by WalletLogic.accountDeleteBlockReason
 * — an account referenced by transactions/planned payments/debts/
 * templates cannot be deleted until those are removed.
 */
public class AccountEditActivity extends Activity {

    public static final String EXTRA_ACCOUNT_ID = "account_id";

    private Store store;
    private WalletDb db;
    private Account editing;

    private EditText nameInput;
    private EditText balanceInput;
    private EditText currencyInput;
    private EditText emojiInput;
    private LinearLayout emojiRow;
    private LinearLayout colorRow;
    private long pickedColor;
    private Spinner cardTypeSpinner;
    private EditText notesInput;
    private Switch enabledSwitch;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = new Store(this);
        db = store.db();

        String id = getIntent() != null ? getIntent().getStringExtra(EXTRA_ACCOUNT_ID) : null;
        editing = id != null ? WalletLogic.accountById(db.accounts, id) : null;
        pickedColor = editing != null ? editing.colorValue : Ui.ACCOUNT_COLORS[0];

        LinearLayout root = Ui.page(this,
                editing == null ? "Add Account" : "Edit Account", null);
        android.widget.ScrollView scroll = Ui.scrollBody(this, root);
        LinearLayout body = (LinearLayout) scroll.getChildAt(0);
        setContentView(root);

        body.addView(Ui.label(this, "NAME"));
        nameInput = Ui.input(this, "e.g. HDFC Salary Account",
                editing != null ? editing.name : "");
        body.addView(nameInput);

        body.addView(Ui.label(this, "CURRENT BALANCE (₹)"));
        balanceInput = Ui.input(this, "0",
                editing != null ? trimNum(editing.balance) : "");
        balanceInput.setInputType(InputType.TYPE_CLASS_NUMBER
                | InputType.TYPE_NUMBER_FLAG_DECIMAL | InputType.TYPE_NUMBER_FLAG_SIGNED);
        body.addView(balanceInput);

        body.addView(Ui.label(this, "CURRENCY"));
        currencyInput = Ui.input(this, "INR",
                editing != null && editing.currency != null ? editing.currency : "INR");
        body.addView(currencyInput);

        body.addView(Ui.label(this, "EMOJI"));
        emojiInput = Ui.input(this, "💳", editing != null ? editing.emoji : "💳");
        body.addView(emojiInput);
        emojiRow = new LinearLayout(this);
        emojiRow.setOrientation(LinearLayout.HORIZONTAL);
        emojiRow.setLayoutParams(Ui.lpTop(this, 6));
        body.addView(emojiRow);
        renderEmojiRow();

        body.addView(Ui.label(this, "COLOUR"));
        colorRow = new LinearLayout(this);
        colorRow.setOrientation(LinearLayout.HORIZONTAL);
        colorRow.setLayoutParams(Ui.lpTop(this, 2));
        body.addView(colorRow);
        renderColorRow();

        body.addView(Ui.label(this, "CARD / ACCOUNT TYPE"));
        cardTypeSpinner = new Spinner(this);
        cardTypeSpinner.setBackground(Ui.rounded(Ui.CARD, 12, this));
        cardTypeSpinner.setLayoutParams(Ui.lpTop(this, 6));
        List<String> types = new ArrayList<>();
        for (String s : Ui.CARD_TYPES) types.add(s.isEmpty() ? "(none)" : s);
        String currentType = editing != null && editing.cardType != null ? editing.cardType : "";
        if (!currentType.isEmpty() && !types.contains(currentType)) types.add(currentType);
        cardTypeSpinner.setAdapter(Ui.spinnerAdapter(this, types));
        for (int i = 0; i < types.size(); i++) {
            String shown = types.get(i);
            if (shown.equals(currentType) || (currentType.isEmpty() && "(none)".equals(shown))) {
                cardTypeSpinner.setSelection(i);
                break;
            }
        }
        body.addView(cardTypeSpinner);

        body.addView(Ui.label(this, "NOTES"));
        notesInput = Ui.input(this, "Anything to remember…",
                editing != null ? editing.notes : "");
        body.addView(notesInput);

        LinearLayout switchRow = new LinearLayout(this);
        switchRow.setOrientation(LinearLayout.HORIZONTAL);
        switchRow.setLayoutParams(Ui.lpTop(this, 16));
        TextView switchLabel = Ui.tv(this, "Count in net wallet", 14, Ui.TEXT, false);
        LinearLayout.LayoutParams slp = new LinearLayout.LayoutParams(
                0, android.view.ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        switchLabel.setLayoutParams(slp);
        switchRow.addView(switchLabel);
        enabledSwitch = new Switch(this);
        enabledSwitch.setChecked(editing == null || editing.isEnabledForCalc);
        switchRow.addView(enabledSwitch);
        body.addView(switchRow);

        Button save = Ui.primaryButton(this,
                editing == null ? "Add Account" : "Save Changes", Ui.PRIMARY);
        save.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { save(); }
        });
        body.addView(save);

        if (editing != null) {
            Button del = Ui.dangerButton(this, "Delete Account");
            del.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) { tryDelete(); }
            });
            body.addView(del);
        }
    }

    private void renderEmojiRow() {
        emojiRow.removeAllViews();
        for (final String e : Ui.ACCOUNT_EMOJIS) {
            TextView t = Ui.tv(this, e, 20, Ui.TEXT, false);
            t.setPadding(Ui.dp(this, 6), Ui.dp(this, 4), Ui.dp(this, 6), Ui.dp(this, 4));
            t.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) { emojiInput.setText(e); }
            });
            emojiRow.addView(t);
        }
    }

    private void renderColorRow() {
        colorRow.removeAllViews();
        for (final long color : Ui.ACCOUNT_COLORS) {
            colorRow.addView(Ui.swatch(this, color, color == pickedColor,
                    new View.OnClickListener() {
                        @Override public void onClick(View v) {
                            pickedColor = color;
                            renderColorRow();
                        }
                    }));
        }
    }

    private void save() {
        String name = nameInput.getText().toString().trim();
        if (name.isEmpty()) {
            toast("Give the account a name.");
            return;
        }
        double balance;
        try {
            String text = balanceInput.getText().toString().trim();
            balance = text.isEmpty() ? 0 : Double.parseDouble(text);
        } catch (Exception e) {
            toast("Enter a valid balance.");
            return;
        }
        Account a = editing != null ? editing : new Account();
        if (editing == null) {
            a.id = "acc_" + System.currentTimeMillis();
        }
        a.name = name;
        a.balance = balance;
        String cur = currencyInput.getText().toString().trim();
        a.currency = cur.isEmpty() ? "INR" : cur.toUpperCase();
        String emoji = emojiInput.getText().toString().trim();
        a.emoji = emoji.isEmpty() ? "💳" : emoji;
        a.colorValue = pickedColor;
        Object sel = cardTypeSpinner.getSelectedItem();
        String cardType = sel != null ? sel.toString() : "";
        a.cardType = "(none)".equals(cardType) ? "" : cardType;
        a.notes = notesInput.getText().toString().trim();
        a.isEnabledForCalc = enabledSwitch.isChecked();
        if (editing == null) db.accounts.add(a);
        store.save();
        toast(editing == null ? "Account added." : "Account updated.");
        finish();
    }

    private void tryDelete() {
        String reason = WalletLogic.accountDeleteBlockReason(db, editing.id);
        if (reason != null) {
            new AlertDialog.Builder(this)
                    .setTitle("Can't delete this account")
                    .setMessage(reason)
                    .setPositiveButton("OK", null)
                    .show();
            return;
        }
        new AlertDialog.Builder(this)
                .setTitle("Delete account?")
                .setMessage("Delete \"" + editing.name + "\" ("
                        + WalletLogic.formatINR(editing.balance) + ")? This cannot be undone.")
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Delete", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface d, int w) {
                        db.accounts.remove(editing);
                        store.save();
                        toast("Account deleted.");
                        finish();
                    }
                })
                .show();
    }

    private void toast(String msg) {
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show();
    }

    private static String trimNum(double v) {
        if (v == Math.floor(v) && !Double.isInfinite(v)) return Long.toString(Math.round(v));
        return Double.toString(v);
    }
}
