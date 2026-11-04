package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.DatePickerDialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.text.InputType;
import android.view.View;
import android.widget.Button;
import android.widget.DatePicker;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Phase 2: add / edit / delete a transaction.
 *
 * Balance effects go through WalletLogic only (apply/reverse), never by
 * poking Account.balance here. Date is stored as an ISO-8601 string, the
 * same format the Flutter app uses.
 *
 * SPLIT DECISION (Phase 2): split transactions are READ-ONLY here.
 * Opening one shows its split breakdown and a clear message; Save is
 * not offered, so its splits can never be silently destroyed by an
 * edit. Split editing arrives in Phase 3. Deleting a split transaction
 * IS allowed (it is an explicit action, confirmed in a dialog that
 * names the split) and reverses the full amount via WalletLogic.
 */
public class TxEditActivity extends Activity {

    public static final String EXTRA_TX_ID = "tx_id";

    private Store store;
    private WalletDb db;
    private Transaction editing; // null = adding new

    private String type = "expense";
    private TextView[] typeChips;
    private LinearLayout typeRow;
    private EditText amountInput;
    private Spinner accountSpinner;
    private LinearLayout toBox;
    private Spinner toAccountSpinner;
    private LinearLayout categoryBox;
    private Spinner categorySpinner;
    private Button dateButton;
    private EditText noteInput;
    private LocalDate pickedDate;

    private List<Account> accountChoices = new ArrayList<>();
    private List<Category> categoryChoices = new ArrayList<>();

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = new Store(this);
        db = store.db();

        String txId = getIntent() != null ? getIntent().getStringExtra(EXTRA_TX_ID) : null;
        editing = txId != null ? WalletLogic.transactionById(db, txId) : null;
        boolean isSplit = editing != null && (editing.isSplit
                || (editing.splits != null && !editing.splits.isEmpty()));

        LinearLayout root = Ui.page(this,
                editing == null ? "Add Transaction" : "Edit Transaction", null);
        android.widget.ScrollView scroll = Ui.scrollBody(this, root);
        LinearLayout body = (LinearLayout) scroll.getChildAt(0);
        setContentView(root);

        if (db.accounts.isEmpty()) {
            body.addView(Ui.tv(this, "You need an account first — add one in "
                    + "Manage Accounts, then come back.", 14, Ui.EXPENSE, false));
            return;
        }

        if (editing != null) {
            type = editing.type != null ? editing.type : "expense";
            try {
                pickedDate = LocalDate.parse(editing.date.substring(0, 10));
            } catch (Exception e) {
                pickedDate = LocalDate.now();
            }
        } else {
            pickedDate = LocalDate.now();
        }

        if (isSplit) {
            buildSplitNotice(body, editing);
            Button del = Ui.dangerButton(this, "Delete this split transaction");
            del.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) { confirmDelete(editing, true); }
            });
            body.addView(del);
            return;
        }

        // ---- type chips
        body.addView(Ui.label(this, "TYPE"));
        typeRow = new LinearLayout(this);
        typeRow.setOrientation(LinearLayout.HORIZONTAL);
        typeRow.setLayoutParams(Ui.lpTop(this, 6));
        body.addView(typeRow);
        renderTypeChips();

        // ---- amount
        body.addView(Ui.label(this, "AMOUNT (₹)"));
        amountInput = Ui.input(this, "0", editing != null ? trimNum(editing.amount) : "");
        amountInput.setInputType(InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_FLAG_DECIMAL);
        body.addView(amountInput);

        // ---- account
        body.addView(Ui.label(this, "transfer".equals(type) ? "FROM ACCOUNT" : "ACCOUNT"));
        accountSpinner = new Spinner(this);
        accountSpinner.setBackground(Ui.rounded(Ui.CARD, 12, this));
        accountSpinner.setLayoutParams(Ui.lpTop(this, 6));
        body.addView(accountSpinner);

        // ---- to account (transfer only)
        toBox = new LinearLayout(this);
        toBox.setOrientation(LinearLayout.VERTICAL);
        toBox.addView(Ui.label(this, "TO ACCOUNT"));
        toAccountSpinner = new Spinner(this);
        toAccountSpinner.setBackground(Ui.rounded(Ui.CARD, 12, this));
        toAccountSpinner.setLayoutParams(Ui.lpTop(this, 6));
        toBox.addView(toAccountSpinner);
        body.addView(toBox);

        // ---- category (not for transfers)
        categoryBox = new LinearLayout(this);
        categoryBox.setOrientation(LinearLayout.VERTICAL);
        categoryBox.addView(Ui.label(this, "CATEGORY"));
        categorySpinner = new Spinner(this);
        categorySpinner.setBackground(Ui.rounded(Ui.CARD, 12, this));
        categorySpinner.setLayoutParams(Ui.lpTop(this, 6));
        categoryBox.addView(categorySpinner);
        body.addView(categoryBox);

        // ---- date
        body.addView(Ui.label(this, "DATE"));
        dateButton = new Button(this);
        dateButton.setAllCaps(false);
        dateButton.setTextSize(15);
        dateButton.setTextColor(Ui.TEXT);
        dateButton.setBackground(Ui.rounded(Ui.CARD, 12, this));
        dateButton.setLayoutParams(Ui.lpTop(this, 6));
        dateButton.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { pickDate(); }
        });
        body.addView(dateButton);
        refreshDateButton();

        // ---- note
        body.addView(Ui.label(this, "NOTE"));
        noteInput = Ui.input(this, "What was this for?", editing != null ? editing.note : "");
        body.addView(noteInput);

        // ---- actions
        Button save = Ui.primaryButton(this,
                editing == null ? "Add Transaction" : "Save Changes", Ui.PRIMARY);
        save.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { save(); }
        });
        body.addView(save);

        if (editing != null) {
            Button del = Ui.dangerButton(this, "Delete Transaction");
            del.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) { confirmDelete(editing, false); }
            });
            body.addView(del);
        }

        refreshAccountSpinners();
        refreshCategorySpinner();
        refreshFieldVisibility();
    }

    // ------------------------------------------------------------------ splits

    private void buildSplitNotice(LinearLayout body, Transaction t) {
        LinearLayout card = Ui.card(this, Ui.CARD_ALT);
        card.setLayoutParams(Ui.lpTop(this, 8));
        card.addView(Ui.tv(this, "👥 Split transaction", 16, Ui.TEXT, true));
        TextView msg = Ui.tv(this, "Split transactions can't be edited in Phase 2 — "
                + "split editing arrives in Phase 3. Nothing here can change or "
                + "destroy the split below; it is shown read-only.", 13, Ui.SECONDARY, false);
        msg.setLayoutParams(Ui.lpTop(this, 6));
        card.addView(msg);
        TextView head = Ui.tv(this, WalletLogic.formatSigned(t) + "  •  "
                + Ui.prettyDate(t.date) + (t.note != null && !t.note.isEmpty()
                ? "  •  " + t.note : ""), 14, Ui.TEXT, true);
        head.setLayoutParams(Ui.lpTop(this, 10));
        card.addView(head);
        if (t.splits != null) {
            for (SplitMember s : t.splits) {
                TextView row = Ui.tv(this, (s.isPaid ? "✅ " : "⏳ ") + s.name
                        + " — " + WalletLogic.formatINR(s.amount)
                        + (s.isPaid ? " (paid)" : " (unpaid)"), 13, Ui.TEXT, false);
                row.setLayoutParams(Ui.lpTop(this, 4));
                card.addView(row);
            }
        }
        body.addView(card);
    }

    // ------------------------------------------------------------------ type

    private void renderTypeChips() {
        typeRow.removeAllViews();
        final String[] types = {"income", "expense", "transfer"};
        final String[] labels = {"↓ Income", "↑ Expense", "⇄ Transfer"};
        typeChips = new TextView[types.length];
        for (int i = 0; i < types.length; i++) {
            final String tp = types[i];
            int color = "income".equals(tp) ? Ui.INCOME
                    : "expense".equals(tp) ? Ui.EXPENSE : Ui.TRANSFER;
            TextView chip = Ui.chip(this, labels[i], tp.equals(type), color);
            chip.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) {
                    type = tp;
                    renderTypeChips();
                    refreshCategorySpinner();
                    refreshFieldVisibility();
                }
            });
            typeChips[i] = chip;
            typeRow.addView(chip);
        }
    }

    private void refreshFieldVisibility() {
        boolean transfer = "transfer".equals(type);
        toBox.setVisibility(transfer ? View.VISIBLE : View.GONE);
        categoryBox.setVisibility(transfer ? View.GONE : View.VISIBLE);
    }

    // ------------------------------------------------------------------ spinners

    private void refreshAccountSpinners() {
        accountChoices = new ArrayList<>(db.accounts);
        List<String> names = new ArrayList<>();
        for (Account a : accountChoices) {
            names.add((a.emoji != null ? a.emoji + " " : "") + a.name);
        }
        accountSpinner.setAdapter(Ui.spinnerAdapter(this, names));
        toAccountSpinner.setAdapter(Ui.spinnerAdapter(this, names));
        if (editing != null) {
            selectById(accountSpinner, accountChoices, editing.accountId);
            if (editing.toAccountId != null) {
                selectById(toAccountSpinner, accountChoices, editing.toAccountId);
            } else if (accountChoices.size() > 1) {
                toAccountSpinner.setSelection(1);
            }
        } else if (accountChoices.size() > 1) {
            toAccountSpinner.setSelection(1);
        }
    }

    private void selectById(Spinner spinner, List<Account> choices, String id) {
        for (int i = 0; i < choices.size(); i++) {
            if (choices.get(i).id != null && choices.get(i).id.equals(id)) {
                spinner.setSelection(i);
                return;
            }
        }
    }

    private void refreshCategorySpinner() {
        if ("transfer".equals(type)) return;
        // Remember the current pick where possible (editing / type switch).
        String wanted = null;
        int cur = categorySpinner.getSelectedItemPosition();
        if (cur >= 0 && cur < categoryChoices.size()) {
            wanted = categoryChoices.get(cur).id;
        } else if (editing != null) {
            wanted = editing.categoryId;
        }
        categoryChoices = WalletLogic.categoriesForPicker(db.categories, type);
        List<String> names = new ArrayList<>();
        for (Category c : categoryChoices) {
            String prefix = c.parentId != null ? "    ↳ " : "";
            names.add(prefix + (c.icon != null ? c.icon + " " : "") + c.name);
        }
        if (names.isEmpty()) names.add("(no categories — add one in Config)");
        categorySpinner.setAdapter(Ui.spinnerAdapter(this, names));
        if (wanted != null) {
            for (int i = 0; i < categoryChoices.size(); i++) {
                if (wanted.equals(categoryChoices.get(i).id)) {
                    categorySpinner.setSelection(i);
                    break;
                }
            }
        }
    }

    // ------------------------------------------------------------------ date

    private void pickDate() {
        new DatePickerDialog(this, new DatePickerDialog.OnDateSetListener() {
            @Override public void onDateSet(DatePicker view, int y, int m, int d) {
                pickedDate = LocalDate.of(y, m + 1, d);
                refreshDateButton();
            }
        }, pickedDate.getYear(), pickedDate.getMonthValue() - 1,
                pickedDate.getDayOfMonth()).show();
    }

    private void refreshDateButton() {
        dateButton.setText("📅  " + pickedDate.format(
                DateTimeFormatter.ofPattern("EEE, d MMM yyyy", Locale.ENGLISH)));
    }

    private String isoDate() {
        String time;
        if (editing != null && editing.date != null && editing.date.length() >= 19
                && editing.date.startsWith(pickedDate.toString())) {
            time = editing.date.substring(11, 19); // keep original time on same-day edits
        } else if (editing != null && editing.date != null && editing.date.length() >= 19) {
            time = editing.date.substring(11, 19);
        } else {
            time = LocalTime.now().format(DateTimeFormatter.ofPattern("HH:mm:ss"));
        }
        return pickedDate.toString() + "T" + time + ".000";
    }

    // ------------------------------------------------------------------ save/delete

    private void save() {
        String amtText = amountInput.getText().toString().trim();
        double amount;
        try {
            amount = Double.parseDouble(amtText);
        } catch (Exception e) {
            toast("Enter a valid amount.");
            return;
        }
        if (amount <= 0) {
            toast("Amount must be more than zero.");
            return;
        }
        int accPos = accountSpinner.getSelectedItemPosition();
        if (accPos < 0 || accPos >= accountChoices.size()) {
            toast("Pick an account.");
            return;
        }
        Account from = accountChoices.get(accPos);

        // IMPORTANT: build a NEW object for edits. updateTransaction()
        // reverses the OLD object it finds in the DB — mutating `editing`
        // in place first would make it reverse the new values instead.
        Transaction t = new Transaction();
        t.id = editing != null ? editing.id : "tx_" + System.currentTimeMillis();
        t.type = type;
        t.amount = amount;
        t.accountId = from.id;
        t.date = isoDate();
        t.note = noteInput.getText().toString().trim();

        if ("transfer".equals(type)) {
            int toPos = toAccountSpinner.getSelectedItemPosition();
            if (toPos < 0 || toPos >= accountChoices.size()) {
                toast("Pick the account the money goes to.");
                return;
            }
            Account to = accountChoices.get(toPos);
            if (to.id != null && to.id.equals(from.id)) {
                toast("From and To accounts can't be the same.");
                return;
            }
            t.toAccountId = to.id;
            t.categoryId = null;
        } else {
            t.toAccountId = null;
            int catPos = categorySpinner.getSelectedItemPosition();
            t.categoryId = (catPos >= 0 && catPos < categoryChoices.size())
                    ? categoryChoices.get(catPos).id : null;
        }
        // Non-split form: a brand-new tx has no splits; an edited tx here is
        // guaranteed non-split (split txs are blocked above), so this is safe.
        t.isSplit = false;

        if (editing == null) {
            WalletLogic.addTransaction(db, t);
        } else {
            WalletLogic.updateTransaction(db, t);
        }
        store.save();
        toast(editing == null ? "Transaction added." : "Transaction updated.");
        finish();
    }

    private void confirmDelete(final Transaction t, final boolean split) {
        String msg = split
                ? "Delete this split transaction (" + WalletLogic.formatSigned(t)
                        + ")? The full amount will be reversed from the account. "
                        + "Its split with " + (t.splits != null ? t.splits.size() : 0)
                        + " people will be removed too."
                : "Delete this transaction (" + WalletLogic.formatSigned(t)
                        + ")? The amount will be reversed from the account.";
        new AlertDialog.Builder(this)
                .setTitle("Delete transaction?")
                .setMessage(msg)
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Delete", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface d, int w) {
                        WalletLogic.deleteTransaction(db, t.id);
                        store.save();
                        toast("Transaction deleted.");
                        finish();
                    }
                })
                .show();
    }

    private void toast(String msg) {
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show();
    }

    private static String trimNum(double v) {
        if (v == Math.floor(v) && !Double.isInfinite(v)) {
            return Long.toString(Math.round(v));
        }
        return Double.toString(v);
    }
}
