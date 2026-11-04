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
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Phase 3: add / edit / delete a debt or credit. Balance effects follow
 * the Flutter semantics via WalletLogic.createDebt / updateDebt /
 * deleteDebt (linked transaction when the record affects an account).
 * Editing REBUILDS the linked transaction(s) with the new fields — see
 * WalletLogic.updateDebt for why net balances match Flutter's
 * in-place update.
 */
public class DebtEditActivity extends Activity {

    public static final String EXTRA_DEBT_ID = "debt_id";
    public static final String EXTRA_DIRECTION = "debt_direction";

    private Store store;
    private WalletDb db;
    private DebtCredit editing;
    private String direction = "lent";

    private LinearLayout dirRow;
    private EditText personInput;
    private EditText amountInput;
    private Spinner accountSpinner;
    private Spinner categorySpinner;
    private Button startButton;
    private LocalDate startDate;
    private Button dueButton;
    private LocalDate dueDate; // null = none
    private EditText notesInput;
    private Switch affectsSwitch;

    private List<Account> accountChoices = new ArrayList<>();
    private List<Category> categoryChoices = new ArrayList<>(); // includes a null at 0

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = new Store(this);
        db = store.db();

        String did = getIntent() != null ? getIntent().getStringExtra(EXTRA_DEBT_ID) : null;
        editing = did != null ? WalletLogic.debtById(db, did) : null;
        if (editing != null) {
            direction = editing.direction;
        } else {
            String dir = getIntent() != null
                    ? getIntent().getStringExtra(EXTRA_DIRECTION) : null;
            if ("borrowed".equals(dir)) direction = "borrowed";
        }

        LinearLayout root = Ui.page(this,
                editing == null ? "Add Debt / Credit" : "Edit Debt / Credit", null);
        android.widget.ScrollView scroll = Ui.scrollBody(this, root);
        LinearLayout body = (LinearLayout) scroll.getChildAt(0);
        setContentView(root);

        if (db.accounts.isEmpty()) {
            body.addView(Ui.tv(this, "You need an account first — add one in "
                    + "Manage Accounts, then come back.", 14, Ui.EXPENSE, false));
            return;
        }

        startDate = editing != null && editing.startDate != null
                ? parseDate(editing.startDate, LocalDate.now()) : LocalDate.now();
        dueDate = editing != null && editing.dueDate != null
                ? parseDate(editing.dueDate, null) : null;

        body.addView(Ui.label(this, "DIRECTION"));
        dirRow = new LinearLayout(this);
        dirRow.setOrientation(LinearLayout.HORIZONTAL);
        dirRow.setLayoutParams(Ui.lpTop(this, 6));
        body.addView(dirRow);
        renderDirChips();

        body.addView(Ui.label(this, "PERSON NAME"));
        personInput = Ui.input(this, "e.g. Rahul, Uncle Ravi",
                editing != null ? editing.personName : "");
        body.addView(personInput);

        body.addView(Ui.label(this, "AMOUNT (₹)"));
        amountInput = Ui.input(this, "0",
                editing != null ? SplitEditor.trimNum(editing.amount) : "");
        amountInput.setInputType(android.text.InputType.TYPE_CLASS_NUMBER
                | android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL);
        body.addView(amountInput);

        body.addView(Ui.label(this, "ACCOUNT"));
        accountSpinner = new Spinner(this);
        accountSpinner.setBackground(Ui.rounded(Ui.CARD, 12, this));
        accountSpinner.setLayoutParams(Ui.lpTop(this, 6));
        body.addView(accountSpinner);

        body.addView(Ui.label(this, "CATEGORY (OPTIONAL)"));
        TextView catHint = Ui.tv(this, "The linked transaction keeps the category only "
                + "when its type matches the direction (lent → expense, borrowed → income).",
                11, Ui.SECONDARY, false);
        catHint.setLayoutParams(Ui.lpTop(this, 2));
        body.addView(catHint);
        categorySpinner = new Spinner(this);
        categorySpinner.setBackground(Ui.rounded(Ui.CARD, 12, this));
        categorySpinner.setLayoutParams(Ui.lpTop(this, 6));
        body.addView(categorySpinner);

        body.addView(Ui.label(this, "START DATE"));
        startButton = dateButton(new View.OnClickListener() {
            @Override public void onClick(View v) {
                pickDate(startDate, new DateConsumer() {
                    @Override public void accept(LocalDate d) {
                        startDate = d;
                        refreshDateButtons();
                    }
                });
            }
        });
        body.addView(startButton);

        body.addView(Ui.label(this, "DUE DATE (OPTIONAL)"));
        dueButton = dateButton(new View.OnClickListener() {
            @Override public void onClick(View v) {
                pickDate(dueDate != null ? dueDate : startDate.plusDays(30),
                        new DateConsumer() {
                            @Override public void accept(LocalDate d) {
                                dueDate = d;
                                refreshDateButtons();
                            }
                        });
            }
        });
        body.addView(dueButton);
        TextView clearDue = Ui.tv(this, "Clear due date", 12, Ui.PRIMARY, true);
        clearDue.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                dueDate = null;
                refreshDateButtons();
            }
        });
        LinearLayout clearRow = new LinearLayout(this);
        clearRow.setGravity(android.view.Gravity.END);
        clearRow.addView(clearDue);
        body.addView(clearRow);

        body.addView(Ui.label(this, "NOTES"));
        notesInput = Ui.input(this, "Optional notes", editing != null ? editing.notes : "");
        body.addView(notesInput);

        // Affects-account switch (Flutter's "This Affects My Account Balance").
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(android.view.Gravity.CENTER_VERTICAL);
        row.setLayoutParams(Ui.lpTop(this, 16));
        LinearLayout labelCol = new LinearLayout(this);
        labelCol.setOrientation(LinearLayout.VERTICAL);
        labelCol.setLayoutParams(new LinearLayout.LayoutParams(
                0, android.view.ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        labelCol.addView(Ui.tv(this, "AFFECTS ACCOUNT BALANCE", 12, Ui.SECONDARY, true));
        labelCol.addView(Ui.tv(this, "Keep on if the money already left / entered "
                + "the account, so a linked transaction keeps the balance right.",
                11, Ui.SECONDARY, false));
        row.addView(labelCol);
        affectsSwitch = new Switch(this);
        affectsSwitch.setChecked(editing == null || editing.affectsAccount);
        row.addView(affectsSwitch);
        body.addView(row);

        Button save = Ui.primaryButton(this,
                editing == null ? "Add Record" : "Save Changes", Ui.PRIMARY);
        save.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { save(); }
        });
        body.addView(save);

        if (editing != null) {
            Button del = Ui.dangerButton(this, "Delete Record");
            del.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) { confirmDelete(); }
            });
            body.addView(del);
        }

        refreshAccountSpinner();
        refreshCategorySpinner();
        refreshDateButtons();
    }

    // ------------------------------------------------------------------ helpers

    private interface DateConsumer { void accept(LocalDate d); }

    private void renderDirChips() {
        dirRow.removeAllViews();
        dirRow.addView(dirChip("lent", "💸 I Lent"));
        dirRow.addView(dirChip("borrowed", "💳 I Borrowed"));
    }

    private View dirChip(final String dir, String label) {
        TextView chip = Ui.chip(this, label, dir.equals(direction),
                "lent".equals(dir) ? Ui.EXPENSE : Ui.TRANSFER);
        chip.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                direction = dir;
                renderDirChips();
                refreshCategorySpinner();
            }
        });
        return chip;
    }

    private Button dateButton(View.OnClickListener onClick) {
        Button b = new Button(this);
        b.setAllCaps(false);
        b.setTextSize(15);
        b.setTextColor(Ui.TEXT);
        b.setBackground(Ui.rounded(Ui.CARD, 12, this));
        b.setLayoutParams(Ui.lpTop(this, 6));
        b.setOnClickListener(onClick);
        return b;
    }

    private void pickDate(LocalDate initial, final DateConsumer consumer) {
        new DatePickerDialog(this, new DatePickerDialog.OnDateSetListener() {
            @Override public void onDateSet(DatePicker view, int y, int m, int d) {
                consumer.accept(LocalDate.of(y, m + 1, d));
            }
        }, initial.getYear(), initial.getMonthValue() - 1, initial.getDayOfMonth()).show();
    }

    private void refreshDateButtons() {
        DateTimeFormatter f = DateTimeFormatter.ofPattern("EEE, d MMM yyyy", Locale.ENGLISH);
        startButton.setText("📅  " + startDate.format(f));
        dueButton.setText("📅  " + (dueDate != null ? dueDate.format(f) : "Not set"));
    }

    private void refreshAccountSpinner() {
        accountChoices = new ArrayList<>(db.accounts);
        List<String> names = new ArrayList<>();
        for (Account a : accountChoices) {
            names.add((a.emoji != null ? a.emoji + " " : "") + a.name);
        }
        accountSpinner.setAdapter(Ui.spinnerAdapter(this, names));
        if (editing != null) {
            for (int i = 0; i < accountChoices.size(); i++) {
                if (accountChoices.get(i).id != null
                        && accountChoices.get(i).id.equals(editing.accountId)) {
                    accountSpinner.setSelection(i);
                    break;
                }
            }
        }
    }

    private void refreshCategorySpinner() {
        // The picker offers the categories of the type the direction maps
        // to (plus (none)); Flutter's picker offers all and validates at
        // save — equivalent, since a mismatched category never lands on
        // the linked transaction (see the hint text).
        String type = "lent".equals(direction) ? "expense" : "income";
        categoryChoices = new ArrayList<>();
        categoryChoices.add(null);
        categoryChoices.addAll(WalletLogic.categoriesForPicker(db.categories, type));
        List<String> names = new ArrayList<>();
        names.add("(no category)");
        for (int i = 1; i < categoryChoices.size(); i++) {
            Category c = categoryChoices.get(i);
            String prefix = c.parentId != null ? "    ↳ " : "";
            names.add(prefix + (c.icon != null ? c.icon + " " : "") + c.name);
        }
        categorySpinner.setAdapter(Ui.spinnerAdapter(this, names));
        if (editing != null && editing.categoryId != null) {
            for (int i = 1; i < categoryChoices.size(); i++) {
                if (editing.categoryId.equals(categoryChoices.get(i).id)) {
                    categorySpinner.setSelection(i);
                    break;
                }
            }
        }
    }

    private static LocalDate parseDate(String iso, LocalDate fallback) {
        if (iso == null || iso.length() < 10) return fallback;
        try {
            return LocalDate.parse(iso.substring(0, 10));
        } catch (Exception e) {
            return fallback;
        }
    }

    private String isoOf(LocalDate d, DebtCredit from, boolean isStart) {
        if (from != null) {
            String ref = isStart ? from.startDate : from.dueDate;
            if (ref != null && ref.length() >= 19 && ref.startsWith(d.toString())) {
                return ref; // same day: keep the stored time part
            }
        }
        return d.toString() + "T00:00:00.000";
    }

    // ------------------------------------------------------------------ save/delete

    private void save() {
        String person = personInput.getText().toString().trim();
        if (person.isEmpty()) {
            toast("Enter the person's name.");
            return;
        }
        double amount;
        try {
            amount = Double.parseDouble(amountInput.getText().toString().trim());
        } catch (Exception e) {
            amount = 0;
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

        long stamp = System.currentTimeMillis();
        DebtCredit d = new DebtCredit();
        d.id = editing != null ? editing.id : "debt_" + stamp;
        d.direction = direction;
        d.personName = person;
        d.amount = amount;
        d.accountId = accountChoices.get(accPos).id;
        int catPos = categorySpinner.getSelectedItemPosition();
        d.categoryId = (catPos >= 0 && catPos < categoryChoices.size()
                && categoryChoices.get(catPos) != null)
                ? categoryChoices.get(catPos).id : null;
        d.startDate = isoOf(startDate, editing, true);
        d.dueDate = dueDate != null ? isoOf(dueDate, editing, false) : null;
        d.notes = notesInput.getText().toString().trim();
        d.affectsAccount = affectsSwitch.isChecked();
        d.status = editing != null ? editing.status : "active";

        if (editing == null) {
            db.debtCredits.add(d);
            WalletLogic.createDebt(db, d, "tx_" + stamp);
        } else {
            // Keep the original settlement date when a closed record is edited.
            String settleDate = null;
            if ("closed".equals(editing.status)
                    && editing.settlementTransactionId != null) {
                Transaction st = WalletLogic.transactionById(
                        db, editing.settlementTransactionId);
                if (st != null) settleDate = st.date;
            }
            WalletLogic.updateDebt(db, d,
                    "tx_" + stamp, "tx_" + stamp + "_settle", settleDate);
        }
        store.save();
        toast(editing == null ? "Record added." : "Record updated.");
        finish();
    }

    private void confirmDelete() {
        new AlertDialog.Builder(this)
                .setTitle("Delete this record?")
                .setMessage("Delete the " + WalletLogic.formatINR(editing.amount)
                        + " record for " + editing.personName + "? Any linked "
                        + "transaction is removed too and balances are reversed.")
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Delete", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface dlg, int w) {
                        WalletLogic.deleteDebt(db, editing);
                        store.save();
                        toast("Record deleted.");
                        finish();
                    }
                })
                .show();
    }

    private void toast(String msg) {
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show();
    }
}
