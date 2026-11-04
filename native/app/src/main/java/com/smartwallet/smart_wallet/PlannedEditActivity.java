package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.DatePickerDialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
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
 * Phase 3: add / edit / delete a planned payment. Mirrors the Flutter
 * editor: recurring off forces period=null and endType="never"; the
 * split members editor saves members UNPAID (as Flutter's planned
 * sheet does — paid state only exists on real transactions).
 * Deleting a planned payment never touches transactions it already
 * created by being marked paid.
 */
public class PlannedEditActivity extends Activity {

    public static final String EXTRA_PLANNED_ID = "planned_id";

    private Store store;
    private WalletDb db;
    private PlannedPayment editing;

    private EditText nameInput;
    private EditText amountInput;
    private Spinner accountSpinner;
    private Spinner categorySpinner;
    private Switch recurringSwitch;
    private LinearLayout periodBox;
    private LinearLayout periodRow;
    private String period = "monthly";
    private Button dateButton;
    private LocalDate pickedDate;
    private LinearLayout endBox;
    private LinearLayout endRow;
    private String endType = "never";
    private Button untilButton;
    private LocalDate pickedUntil;
    private EditText occInput;
    private LinearLayout untilBox;
    private LinearLayout occBox;
    private EditText noteInput;
    private Switch splitSwitch;
    private LinearLayout splitBox;
    private SplitEditor splitEditor;

    private List<Account> accountChoices = new ArrayList<>();
    private List<Category> categoryChoices = new ArrayList<>(); // index 0 = (none) -> null entry

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = new Store(this);
        db = store.db();

        String pid = getIntent() != null
                ? getIntent().getStringExtra(EXTRA_PLANNED_ID) : null;
        editing = pid != null ? WalletLogic.plannedById(db, pid) : null;

        LinearLayout root = Ui.page(this,
                editing == null ? "Add Planned Payment" : "Edit Planned Payment", null);
        android.widget.ScrollView scroll = Ui.scrollBody(this, root);
        LinearLayout body = (LinearLayout) scroll.getChildAt(0);
        setContentView(root);

        if (db.accounts.isEmpty()) {
            body.addView(Ui.tv(this, "You need an account first — add one in "
                    + "Manage Accounts, then come back.", 14, Ui.EXPENSE, false));
            return;
        }

        if (editing != null) {
            pickedDate = parseDate(editing.nextDueDate, LocalDate.now());
            period = editing.period != null ? editing.period : "monthly";
            endType = editing.endType != null ? editing.endType : "never";
            pickedUntil = editing.untilDate != null
                    ? parseDate(editing.untilDate, pickedDate.plusMonths(1)) : null;
        } else {
            pickedDate = LocalDate.now().plusDays(30); // Flutter's default
            pickedUntil = null;
        }

        body.addView(Ui.label(this, "NAME"));
        nameInput = Ui.input(this, "e.g. Netflix, Rent, EMI",
                editing != null ? editing.name : "");
        body.addView(nameInput);

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

        body.addView(Ui.label(this, "CATEGORY (EXPENSE)"));
        categorySpinner = new Spinner(this);
        categorySpinner.setBackground(Ui.rounded(Ui.CARD, 12, this));
        categorySpinner.setLayoutParams(Ui.lpTop(this, 6));
        body.addView(categorySpinner);

        body.addView(Ui.label(this, "DUE DATE"));
        dateButton = dateButton(new View.OnClickListener() {
            @Override public void onClick(View v) {
                pickDate(pickedDate, new DateConsumer() {
                    @Override public void accept(LocalDate d) {
                        pickedDate = d;
                        refreshDateButtons();
                    }
                });
            }
        });
        body.addView(dateButton);

        recurringSwitch = switchRow(body, "REPEATS (RECURRING)",
                editing != null && editing.isRecurring);
        recurringSwitch.setOnCheckedChangeListener(
                new android.widget.CompoundButton.OnCheckedChangeListener() {
                    @Override public void onCheckedChanged(
                            android.widget.CompoundButton b, boolean isChecked) {
                        refreshRecurringVisibility();
                    }
                });

        periodBox = new LinearLayout(this);
        periodBox.setOrientation(LinearLayout.VERTICAL);
        periodBox.addView(Ui.label(this, "PERIOD"));
        periodRow = new LinearLayout(this);
        periodRow.setOrientation(LinearLayout.HORIZONTAL);
        periodRow.setLayoutParams(Ui.lpTop(this, 6));
        periodBox.addView(periodRow);
        body.addView(periodBox);
        renderPeriodChips();

        endBox = new LinearLayout(this);
        endBox.setOrientation(LinearLayout.VERTICAL);
        endBox.addView(Ui.label(this, "ENDS"));
        endRow = new LinearLayout(this);
        endRow.setOrientation(LinearLayout.HORIZONTAL);
        endRow.setLayoutParams(Ui.lpTop(this, 6));
        endBox.addView(endRow);

        untilBox = new LinearLayout(this);
        untilBox.setOrientation(LinearLayout.VERTICAL);
        untilBox.addView(Ui.label(this, "UNTIL DATE"));
        untilButton = dateButton(new View.OnClickListener() {
            @Override public void onClick(View v) {
                pickDate(pickedUntil != null ? pickedUntil : pickedDate.plusMonths(1),
                        new DateConsumer() {
                            @Override public void accept(LocalDate d) {
                                pickedUntil = d;
                                refreshDateButtons();
                            }
                        });
            }
        });
        untilBox.addView(untilButton);
        endBox.addView(untilBox);

        occBox = new LinearLayout(this);
        occBox.setOrientation(LinearLayout.VERTICAL);
        occBox.addView(Ui.label(this, "TOTAL OCCURRENCES"));
        occInput = Ui.input(this, "12", editing != null && editing.totalOccurrences != null
                ? String.valueOf(editing.totalOccurrences) : "12");
        occInput.setInputType(android.text.InputType.TYPE_CLASS_NUMBER);
        occBox.addView(occInput);
        endBox.addView(occBox);
        body.addView(endBox);
        renderEndChips();

        body.addView(Ui.label(this, "NOTE"));
        noteInput = Ui.input(this, "Optional note", editing != null ? editing.note : "");
        body.addView(noteInput);

        splitSwitch = switchRow(body, "SPLIT THIS PAYMENT",
                editing != null && editing.isSplit
                        && editing.splits != null && !editing.splits.isEmpty());
        splitBox = new LinearLayout(this);
        splitBox.setOrientation(LinearLayout.VERTICAL);
        splitBox.setLayoutParams(Ui.lpTop(this, 6));
        splitEditor = new SplitEditor(this, new java.util.function.Supplier<Double>() {
            @Override public Double get() { return currentAmount(); }
        });
        splitBox.addView(splitEditor.view());
        splitSwitch.setOnCheckedChangeListener(
                new android.widget.CompoundButton.OnCheckedChangeListener() {
                    @Override public void onCheckedChanged(
                            android.widget.CompoundButton b, boolean isChecked) {
                        splitBox.setVisibility(isChecked ? View.VISIBLE : View.GONE);
                        if (isChecked && splitEditor.size() == 0) splitEditor.seedNew();
                        if (isChecked) splitEditor.updateSum();
                    }
                });
        body.addView(splitBox);
        if (editing != null && editing.isSplit && editing.splits != null) {
            for (SplitMember s : editing.splits) {
                splitEditor.addRow(s, s.name, s.amount);
            }
        }
        splitBox.setVisibility(splitSwitch.isChecked() ? View.VISIBLE : View.GONE);

        Button save = Ui.primaryButton(this,
                editing == null ? "Add Planned Payment" : "Save Changes", Ui.PRIMARY);
        save.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { save(); }
        });
        body.addView(save);

        if (editing != null) {
            Button del = Ui.dangerButton(this, "Delete Planned Payment");
            del.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) { confirmDelete(); }
            });
            body.addView(del);
        }

        refreshAccountSpinner();
        refreshCategorySpinner();
        refreshRecurringVisibility();
        refreshDateButtons();
    }

    // ------------------------------------------------------------------ helpers

    private interface DateConsumer { void accept(LocalDate d); }

    private Switch switchRow(LinearLayout body, String labelText, boolean checked) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(android.view.Gravity.CENTER_VERTICAL);
        row.setLayoutParams(Ui.lpTop(this, 16));
        TextView lab = Ui.tv(this, labelText, 12, Ui.SECONDARY, true);
        LinearLayout.LayoutParams llp = new LinearLayout.LayoutParams(
                0, android.view.ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        lab.setLayoutParams(llp);
        row.addView(lab);
        Switch sw = new Switch(this);
        sw.setChecked(checked);
        row.addView(sw);
        body.addView(row);
        return sw;
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
        dateButton.setText("📅  " + pickedDate.format(
                DateTimeFormatter.ofPattern("EEE, d MMM yyyy", Locale.ENGLISH)));
        untilButton.setText("📅  " + (pickedUntil != null ? pickedUntil : pickedDate.plusMonths(1))
                .format(DateTimeFormatter.ofPattern("EEE, d MMM yyyy", Locale.ENGLISH)));
    }

    private void renderPeriodChips() {
        periodRow.removeAllViews();
        final String[] values = {"daily", "weekly", "monthly", "yearly"};
        final String[] labels = {"Daily", "Weekly", "Monthly", "Yearly"};
        for (int i = 0; i < values.length; i++) {
            final String v = values[i];
            TextView chip = Ui.chip(this, labels[i], v.equals(period), Ui.PRIMARY);
            chip.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View view) {
                    period = v;
                    renderPeriodChips();
                }
            });
            periodRow.addView(chip);
        }
    }

    private void renderEndChips() {
        endRow.removeAllViews();
        final String[] values = {"never", "until_date", "occurrences"};
        final String[] labels = {"Never", "Until date", "Occurrences"};
        for (int i = 0; i < values.length; i++) {
            final String v = values[i];
            TextView chip = Ui.chip(this, labels[i], v.equals(endType), Ui.PRIMARY);
            chip.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View view) {
                    endType = v;
                    renderEndChips();
                    refreshEndVisibility();
                }
            });
            endRow.addView(chip);
        }
    }

    private void refreshRecurringVisibility() {
        boolean rec = recurringSwitch.isChecked();
        periodBox.setVisibility(rec ? View.VISIBLE : View.GONE);
        endBox.setVisibility(rec ? View.VISIBLE : View.GONE);
        refreshEndVisibility();
    }

    private void refreshEndVisibility() {
        untilBox.setVisibility("until_date".equals(endType) ? View.VISIBLE : View.GONE);
        occBox.setVisibility("occurrences".equals(endType) ? View.VISIBLE : View.GONE);
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
        categoryChoices = new ArrayList<>();
        categoryChoices.add(null); // (no category)
        categoryChoices.addAll(WalletLogic.categoriesForPicker(db.categories, "expense"));
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

    private double currentAmount() {
        try {
            return Double.parseDouble(amountInput.getText().toString().trim());
        } catch (Exception e) {
            return 0;
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

    private String isoFor(LocalDate date, PlannedPayment from) {
        String time = "09:00:00";
        if (from != null && from.nextDueDate != null && from.nextDueDate.length() >= 19
                && from.nextDueDate.startsWith(date.toString())) {
            time = from.nextDueDate.substring(11, 19);
        }
        return date.toString() + "T" + time + ".000";
    }

    // ------------------------------------------------------------------ save/delete

    private void save() {
        String name = nameInput.getText().toString().trim();
        if (name.isEmpty()) {
            toast("Give the payment a name.");
            return;
        }
        double amount = currentAmount();
        if (amount <= 0) {
            toast("Amount must be more than zero.");
            return;
        }
        int accPos = accountSpinner.getSelectedItemPosition();
        if (accPos < 0 || accPos >= accountChoices.size()) {
            toast("Pick an account.");
            return;
        }
        boolean recurring = recurringSwitch.isChecked();

        PlannedPayment p = new PlannedPayment();
        p.id = editing != null ? editing.id : "plan_" + System.currentTimeMillis();
        p.name = name;
        p.amount = amount;
        p.accountId = accountChoices.get(accPos).id;
        int catPos = categorySpinner.getSelectedItemPosition();
        p.categoryId = (catPos >= 0 && catPos < categoryChoices.size())
                ? (categoryChoices.get(catPos) == null
                        ? null : categoryChoices.get(catPos).id)
                : null;
        p.isRecurring = recurring;
        p.period = recurring ? period : null;
        p.nextDueDate = isoFor(pickedDate, editing);
        p.note = noteInput.getText().toString().trim();
        p.endType = recurring ? endType : "never";
        p.untilDate = recurring && "until_date".equals(endType)
                ? isoFor(pickedUntil != null ? pickedUntil : pickedDate.plusMonths(1), null)
                : null;
        if (recurring && "occurrences".equals(endType)) {
            try {
                int occ = Integer.parseInt(occInput.getText().toString().trim());
                if (occ <= 0) throw new NumberFormatException();
                p.totalOccurrences = occ;
            } catch (Exception e) {
                toast("Enter a valid number of occurrences.");
                return;
            }
        } else {
            p.totalOccurrences = null;
        }
        if (editing != null) {
            // Progress is not editable here.
            p.currentOccurrence = editing.currentOccurrence;
            p.isCompleted = editing.isCompleted;
            p.lastPaidDate = editing.lastPaidDate;
        } else {
            p.currentOccurrence = 1;
            p.isCompleted = false;
        }

        boolean splitOn = splitSwitch.isChecked();
        if (splitOn) {
            List<SplitMember> members = splitEditor.collect(true);
            String err = WalletLogic.splitValidationError(members, amount);
            if (err != null) {
                toast(err);
                return;
            }
            p.isSplit = true;
            p.splits = members;
        } else {
            p.isSplit = false;
            p.splits = new ArrayList<>();
        }

        if (editing == null) {
            db.plannedPayments.add(p);
        } else {
            for (int i = 0; i < db.plannedPayments.size(); i++) {
                if (p.id.equals(db.plannedPayments.get(i).id)) {
                    db.plannedPayments.set(i, p);
                    break;
                }
            }
        }
        store.save();
        NotifService.sync(this);
        toast(editing == null ? "Planned payment added." : "Planned payment updated.");
        finish();
    }

    private void confirmDelete() {
        new AlertDialog.Builder(this)
                .setTitle("Delete planned payment?")
                .setMessage("Delete \"" + editing.name + "\"? Transactions it "
                        + "already created by being paid stay as they are.")
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Delete", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface d, int w) {
                        db.plannedPayments.remove(editing);
                        store.save();
                        NotifService.sync(PlannedEditActivity.this);
                        toast("Planned payment deleted.");
                        finish();
                    }
                })
                .show();
    }

    private void toast(String msg) {
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show();
    }
}
