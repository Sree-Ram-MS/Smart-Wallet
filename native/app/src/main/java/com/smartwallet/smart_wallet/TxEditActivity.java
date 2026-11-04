package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.DatePickerDialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.CompoundButton;
import android.widget.DatePicker;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.Spinner;
import android.widget.Switch;
import android.widget.TextView;
import android.widget.Toast;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Phase 2/3: add / edit / delete one transaction.
 *
 * All balance effects go through WalletLogic.addTransaction /
 * updateTransaction / deleteTransaction, so the math is JVM-tested.
 * The edited record is never mutated in place (a fresh Transaction is
 * built from the form); updateTransaction reverses the old record
 * (including split recoveries) and applies the new one.
 *
 * Phase 3 changes:
 *  - Split EDITING replaces the Phase 2 read-only block: a members
 *    editor (SplitEditor) with add/remove, Split Equally and
 *    sum-to-total validation. Paid state of existing members is
 *    preserved across edits so recoveries stay consistent.
 *  - Templates: EXTRA_TEMPLATE_ID opens the form prefilled from a
 *    template (via WalletLogic.draftFromTemplate); saving creates a
 *    normal transaction.
 *  - EXTRA_START_SPLIT opens a new expense with the split switch on
 *    (the Split Bills screen's + action).
 */
public class TxEditActivity extends Activity {

    public static final String EXTRA_TX_ID = "tx_id";
    public static final String EXTRA_TEMPLATE_ID = "template_id";
    public static final String EXTRA_START_SPLIT = "start_split";

    private Store store;
    private WalletDb db;
    private Transaction editing;   // stored record being edited; null when adding
    private Template usedTemplate; // non-null when opened from a template

    private String type = "expense";
    private LinearLayout typeRow;
    private EditText amountInput;
    private Spinner accountSpinner;
    private LinearLayout toBox;
    private Spinner toAccountSpinner;
    private Spinner categorySpinner;
    private Button dateButton;
    private LocalDate pickedDate;
    private LocalTime pickedTime = LocalTime.of(12, 0);
    private EditText noteInput;
    private LinearLayout splitSection;
    private Switch splitSwitch;
    private LinearLayout splitBox;
    private SplitEditor splitEditor;

    private List<Account> accountChoices = new ArrayList<>();
    private List<Category> categoryChoices = new ArrayList<>(); // entry 0 = null "(none)"

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = new Store(this);
        db = store.db();

        String txId = getIntent() != null ? getIntent().getStringExtra(EXTRA_TX_ID) : null;
        editing = txId != null ? WalletLogic.transactionById(db, txId) : null;

        // "seed" pre-fills the form: the stored record when editing, a
        // template draft when adding from a template, else null.
        Transaction seed = editing;
        if (seed == null && getIntent() != null) {
            String tplId = getIntent().getStringExtra(EXTRA_TEMPLATE_ID);
            if (tplId != null) {
                usedTemplate = WalletLogic.templateById(db, tplId);
                if (usedTemplate != null) {
                    seed = WalletLogic.draftFromTemplate(usedTemplate,
                            "tx_" + System.currentTimeMillis(), WalletLogic.nowIso());
                }
            }
        }
        boolean startSplit = editing == null && usedTemplate == null && getIntent() != null
                && getIntent().getBooleanExtra(EXTRA_START_SPLIT, false);

        LinearLayout root = Ui.page(this,
                editing != null ? "Edit Transaction"
                        : usedTemplate != null ? "New from Template" : "Add Transaction",
                null);
        android.widget.ScrollView scroll = Ui.scrollBody(this, root);
        LinearLayout body = (LinearLayout) scroll.getChildAt(0);
        setContentView(root);

        if (db.accounts.isEmpty()) {
            body.addView(Ui.tv(this, "You need an account first — add one in "
                    + "Manage Accounts, then come back.", 14, Ui.EXPENSE, false));
            return;
        }

        // Form state.
        if (seed != null) {
            type = seed.type;
            pickedDate = parseDate(seed.date, LocalDate.now());
            pickedTime = parseTime(seed.date);
        } else {
            pickedDate = LocalDate.now();
            if (getIntent() != null) {
                String preset = getIntent().getStringExtra("preset_type");
                if ("income".equals(preset) || "transfer".equals(preset)) type = preset;
            }
        }

        body.addView(Ui.label(this, "TYPE"));
        typeRow = new LinearLayout(this);
        typeRow.setOrientation(LinearLayout.HORIZONTAL);
        typeRow.setLayoutParams(Ui.lpTop(this, 6));
        body.addView(typeRow);
        renderTypeChips();

        body.addView(Ui.label(this, "AMOUNT (₹)"));
        amountInput = Ui.input(this, "0", seed != null ? fmt(seed.amount) : "");
        amountInput.setInputType(android.text.InputType.TYPE_CLASS_NUMBER
                | android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL);
        body.addView(amountInput);

        body.addView(Ui.label(this, "ACCOUNT"));
        accountSpinner = new Spinner(this);
        accountSpinner.setBackground(Ui.rounded(Ui.CARD, 12, this));
        accountSpinner.setLayoutParams(Ui.lpTop(this, 6));
        body.addView(accountSpinner);

        toBox = new LinearLayout(this);
        toBox.setOrientation(LinearLayout.VERTICAL);
        toBox.addView(Ui.label(this, "TO ACCOUNT"));
        toAccountSpinner = new Spinner(this);
        toAccountSpinner.setBackground(Ui.rounded(Ui.CARD, 12, this));
        toAccountSpinner.setLayoutParams(Ui.lpTop(this, 6));
        toBox.addView(toAccountSpinner);
        body.addView(toBox);

        body.addView(Ui.label(this, "CATEGORY"));
        categorySpinner = new Spinner(this);
        categorySpinner.setBackground(Ui.rounded(Ui.CARD, 12, this));
        categorySpinner.setLayoutParams(Ui.lpTop(this, 6));
        body.addView(categorySpinner);

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

        body.addView(Ui.label(this, "NOTE"));
        noteInput = Ui.input(this, "What was this for?",
                seed != null && seed.note != null ? seed.note : "");
        body.addView(noteInput);

        // ---------------- Split members editor (Phase 3) ----------------
        splitSection = new LinearLayout(this);
        splitSection.setOrientation(LinearLayout.VERTICAL);
        LinearLayout sRow = new LinearLayout(this);
        sRow.setOrientation(LinearLayout.HORIZONTAL);
        sRow.setGravity(android.view.Gravity.CENTER_VERTICAL);
        sRow.setLayoutParams(Ui.lpTop(this, 16));
        LinearLayout sCol = new LinearLayout(this);
        sCol.setOrientation(LinearLayout.VERTICAL);
        sCol.setLayoutParams(new LinearLayout.LayoutParams(
                0, android.view.ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        sCol.addView(Ui.tv(this, "SPLIT THIS EXPENSE", 12, Ui.SECONDARY, true));
        sCol.addView(Ui.tv(this, "Shares must add up to the full amount. "
                + "Money a friend pays back lands in their paid account.",
                11, Ui.SECONDARY, false));
        sRow.addView(sCol);
        splitSwitch = new Switch(this);
        boolean seedIsSplit = seed != null && seed.isSplit
                && seed.splits != null && !seed.splits.isEmpty();
        splitSwitch.setChecked(seedIsSplit || startSplit);
        sRow.addView(splitSwitch);
        splitSection.addView(sRow);

        splitBox = new LinearLayout(this);
        splitBox.setOrientation(LinearLayout.VERTICAL);
        splitEditor = new SplitEditor(this, new java.util.function.Supplier<Double>() {
            @Override public Double get() { return currentAmount(); }
        });
        splitBox.addView(splitEditor.view());
        splitSection.addView(splitBox);
        body.addView(splitSection);

        if (seedIsSplit) {
            for (SplitMember s : seed.splits) {
                splitEditor.addRow(s, s.name, s.amount);
            }
        }
        splitSwitch.setOnCheckedChangeListener(new CompoundButton.OnCheckedChangeListener() {
            @Override public void onCheckedChanged(CompoundButton b, boolean on) {
                refreshFieldVisibility();
                if (on && splitEditor.size() == 0) splitEditor.seedNew();
                if (on) splitEditor.updateSum();
            }
        });
        if (startSplit && splitEditor.size() == 0) {
            splitEditor.seedNew();
        }

        Button save = Ui.primaryButton(this,
                editing != null ? "Save Changes" : "Add Transaction", Ui.PRIMARY);
        save.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { save(); }
        });
        body.addView(save);

        if (editing != null) {
            Button del = Ui.dangerButton(this, "Delete Transaction");
            del.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) { confirmDelete(); }
            });
            body.addView(del);
        }

        refreshAccountSpinners(seed);
        refreshCategorySpinner(seed);
        refreshDateButton();
        refreshFieldVisibility();
    }

    // ------------------------------------------------------------------ UI state

    private void renderTypeChips() {
        typeRow.removeAllViews();
        final String[] types = {"expense", "income", "transfer"};
        final String[] labels = {"💸 Expense", "💰 Income", "🔄 Transfer"};
        for (int i = 0; i < types.length; i++) {
            final String t = types[i];
            int color = "income".equals(t) ? Ui.INCOME
                    : "expense".equals(t) ? Ui.EXPENSE : Ui.TRANSFER;
            TextView chip = Ui.chip(this, labels[i], t.equals(type), color);
            chip.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) {
                    if (!t.equals(type)) {
                        type = t;
                        renderTypeChips();
                        refreshCategorySpinner(null);
                        refreshFieldVisibility();
                    }
                }
            });
            typeRow.addView(chip);
        }
    }

    private void refreshFieldVisibility() {
        boolean isTransfer = "transfer".equals(type);
        toBox.setVisibility(isTransfer ? View.VISIBLE : View.GONE);
        // Splits exist only for expenses (Flutter's rule).
        boolean isExpense = "expense".equals(type);
        splitSection.setVisibility(isExpense ? View.VISIBLE : View.GONE);
        splitBox.setVisibility(isExpense && splitSwitch.isChecked()
                ? View.VISIBLE : View.GONE);
    }

    private void refreshAccountSpinners(Transaction seed) {
        accountChoices = new ArrayList<>(db.accounts);
        List<String> names = new ArrayList<>();
        for (Account a : accountChoices) {
            names.add((a.emoji != null ? a.emoji + " " : "") + a.name);
        }
        accountSpinner.setAdapter(Ui.spinnerAdapter(this, names));
        toAccountSpinner.setAdapter(Ui.spinnerAdapter(this, names));
        if (seed != null) {
            selectAccount(accountSpinner, seed.accountId);
            selectAccount(toAccountSpinner, seed.toAccountId);
        }
    }

    private void selectAccount(Spinner spinner, String accountId) {
        if (accountId == null) return;
        for (int i = 0; i < accountChoices.size(); i++) {
            if (accountId.equals(accountChoices.get(i).id)) {
                spinner.setSelection(i);
                return;
            }
        }
    }

    private void refreshCategorySpinner(Transaction seed) {
        categoryChoices = new ArrayList<>();
        categoryChoices.add(null);
        if (!"transfer".equals(type)) {
            categoryChoices.addAll(WalletLogic.categoriesForPicker(db.categories, type));
        }
        List<String> names = new ArrayList<>();
        names.add("(no category)");
        for (int i = 1; i < categoryChoices.size(); i++) {
            Category c = categoryChoices.get(i);
            String prefix = c.parentId != null ? "    ↳ " : "";
            names.add(prefix + (c.icon != null ? c.icon + " " : "") + c.name);
        }
        categorySpinner.setAdapter(Ui.spinnerAdapter(this, names));
        if (seed != null && seed.categoryId != null) {
            for (int i = 1; i < categoryChoices.size(); i++) {
                if (seed.categoryId.equals(categoryChoices.get(i).id)) {
                    categorySpinner.setSelection(i);
                    break;
                }
            }
        }
    }

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

    // ------------------------------------------------------------------ save/delete

    private void save() {
        double amount = currentAmount();
        if (amount <= 0 || Double.isNaN(amount)) {
            toast("Enter an amount greater than zero.");
            return;
        }
        int accPos = accountSpinner.getSelectedItemPosition();
        if (accPos < 0 || accPos >= accountChoices.size()) {
            toast("Pick an account.");
            return;
        }
        String toId = null;
        if ("transfer".equals(type)) {
            int toPos = toAccountSpinner.getSelectedItemPosition();
            if (toPos < 0 || toPos >= accountChoices.size()) {
                toast("Pick the destination account.");
                return;
            }
            toId = accountChoices.get(toPos).id;
            if (toId.equals(accountChoices.get(accPos).id)) {
                toast("Source and destination accounts must be different.");
                return;
            }
        }
        String catId = null;
        if (!"transfer".equals(type)) {
            int catPos = categorySpinner.getSelectedItemPosition();
            if (catPos > 0 && catPos < categoryChoices.size()) {
                catId = categoryChoices.get(catPos).id;
            }
        }

        boolean splitOn = "expense".equals(type) && splitSwitch.isChecked();
        List<SplitMember> members = new ArrayList<>();
        if (splitOn) {
            members = splitEditor.collect(false);
            String err = WalletLogic.splitValidationError(members, amount);
            if (err != null) {
                toast(err);
                return;
            }
        }

        Transaction fresh = new Transaction();
        fresh.id = editing != null ? editing.id : "tx_" + System.currentTimeMillis();
        fresh.type = type;
        fresh.amount = amount;
        fresh.accountId = accountChoices.get(accPos).id;
        fresh.toAccountId = toId;
        fresh.categoryId = catId;
        fresh.date = pickedDate.toString() + "T"
                + DateTimeFormatter.ofPattern("HH:mm:ss").format(pickedTime) + ".000";
        fresh.note = noteInput.getText().toString().trim();
        fresh.isSplit = splitOn;
        fresh.splits = members;

        if (editing == null) {
            WalletLogic.addTransaction(db, fresh);
        } else {
            WalletLogic.updateTransaction(db, fresh);
        }
        store.save();
        toast(editing != null ? "Transaction updated."
                : usedTemplate != null ? "Transaction added from template."
                : "Transaction added.");
        finish();
    }

    private void confirmDelete() {
        String extra = "";
        if (editing.isSplit && editing.splits != null && !editing.splits.isEmpty()) {
            int paidBack = 0;
            for (SplitMember s : editing.splits) if (s.isPaid) paidBack++;
            extra = "\n\nThis is a split transaction shared with "
                    + editing.splits.size() + " people (" + paidBack
                    + " already paid back). Deleting it reverses the expense "
                    + "and any money collected for it.";
        }
        new AlertDialog.Builder(this)
                .setTitle("Delete transaction?")
                .setMessage("Delete this " + editing.type + " of "
                        + WalletLogic.formatINR(editing.amount)
                        + "? Account balances will be updated." + extra)
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Delete", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface d, int w) {
                        WalletLogic.deleteTransaction(db, editing.id);
                        store.save();
                        toast("Transaction deleted.");
                        finish();
                    }
                })
                .show();
    }

    // ------------------------------------------------------------------ misc

    private double currentAmount() {
        try {
            return Double.parseDouble(amountInput.getText().toString().trim());
        } catch (Exception e) {
            return 0;
        }
    }

    private static String fmt(double v) {
        if (v == Math.floor(v) && !Double.isInfinite(v)) {
            return Long.toString(Math.round(v));
        }
        return String.format(Locale.US, "%.2f", v);
    }

    private static LocalDate parseDate(String iso, LocalDate fallback) {
        if (iso == null || iso.length() < 10) return fallback;
        try {
            return LocalDate.parse(iso.substring(0, 10));
        } catch (Exception e) {
            return fallback;
        }
    }

    private static LocalTime parseTime(String iso) {
        if (iso != null && iso.length() >= 19) {
            try {
                return LocalTime.parse(iso.substring(11, 19));
            } catch (Exception ignored) {
                // fall through
            }
        }
        return LocalTime.of(12, 0);
    }

    private void toast(String msg) {
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show();
    }
}
