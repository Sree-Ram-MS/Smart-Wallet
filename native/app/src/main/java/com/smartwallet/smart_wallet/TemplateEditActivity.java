package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.List;

/**
 * Phase 3: add / edit / delete a template. A template is just a saved
 * transaction shape — no balance effects until it is Used.
 * Note: Flutter's template editor never sets toAccountId even for
 * transfers (the field exists only in the model); native supports it
 * because transfers need a destination to be one-tap usable.
 */
public class TemplateEditActivity extends Activity {

    public static final String EXTRA_TEMPLATE_ID = "template_id";

    private Store store;
    private WalletDb db;
    private Template editing;

    private EditText nameInput;
    private String type = "expense";
    private LinearLayout typeRow;
    private EditText amountInput;
    private Spinner accountSpinner;
    private LinearLayout toBox;
    private Spinner toAccountSpinner;
    private Spinner categorySpinner;
    private EditText noteInput;

    private List<Account> accountChoices = new ArrayList<>();
    private List<Category> categoryChoices = new ArrayList<>(); // entry 0 = null "(none)"

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = new Store(this);
        db = store.db();

        String tid = getIntent() != null
                ? getIntent().getStringExtra(EXTRA_TEMPLATE_ID) : null;
        editing = tid != null ? WalletLogic.templateById(db, tid) : null;
        if (editing != null) type = editing.type;

        LinearLayout root = Ui.page(this,
                editing == null ? "Add Template" : "Edit Template", null);
        android.widget.ScrollView scroll = Ui.scrollBody(this, root);
        LinearLayout body = (LinearLayout) scroll.getChildAt(0);
        setContentView(root);

        if (db.accounts.isEmpty()) {
            body.addView(Ui.tv(this, "You need an account first — add one in "
                    + "Manage Accounts, then come back.", 14, Ui.EXPENSE, false));
            return;
        }

        body.addView(Ui.label(this, "TEMPLATE NAME"));
        nameInput = Ui.input(this, "e.g. Morning Coffee ☕",
                editing != null ? editing.name : "");
        body.addView(nameInput);

        body.addView(Ui.label(this, "TYPE"));
        typeRow = new LinearLayout(this);
        typeRow.setOrientation(LinearLayout.HORIZONTAL);
        typeRow.setLayoutParams(Ui.lpTop(this, 6));
        body.addView(typeRow);
        renderTypeChips();

        body.addView(Ui.label(this, "AMOUNT (₹)"));
        amountInput = Ui.input(this, "0",
                editing != null ? SplitEditor.trimNum(editing.amount) : "");
        amountInput.setInputType(android.text.InputType.TYPE_CLASS_NUMBER
                | android.text.InputType.TYPE_NUMBER_FLAG_DECIMAL);
        body.addView(amountInput);

        body.addView(Ui.label(this, "ACCOUNT"));
        accountSpinner = plainSpinner();
        body.addView(accountSpinner);

        toBox = new LinearLayout(this);
        toBox.setOrientation(LinearLayout.VERTICAL);
        toBox.addView(Ui.label(this, "TO ACCOUNT"));
        toAccountSpinner = plainSpinner();
        toBox.addView(toAccountSpinner);
        body.addView(toBox);

        body.addView(Ui.label(this, "CATEGORY"));
        categorySpinner = plainSpinner();
        body.addView(categorySpinner);

        body.addView(Ui.label(this, "NOTE"));
        noteInput = Ui.input(this, "e.g. Daily coffee",
                editing != null ? editing.note : "");
        body.addView(noteInput);

        Button save = Ui.primaryButton(this,
                editing == null ? "Save Template" : "Save Changes", Ui.PRIMARY);
        save.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { save(); }
        });
        body.addView(save);

        if (editing != null) {
            Button del = Ui.dangerButton(this, "Delete Template");
            del.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) { confirmDelete(); }
            });
            body.addView(del);
        }

        refreshAccountSpinners();
        refreshCategorySpinner();
        refreshTypeVisibility();
    }

    private Spinner plainSpinner() {
        Spinner s = new Spinner(this);
        s.setBackground(Ui.rounded(Ui.CARD, 12, this));
        s.setLayoutParams(Ui.lpTop(this, 6));
        return s;
    }

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
                    type = t;
                    renderTypeChips();
                    refreshCategorySpinner();
                    refreshTypeVisibility();
                }
            });
            typeRow.addView(chip);
        }
    }

    private void refreshTypeVisibility() {
        toBox.setVisibility("transfer".equals(type) ? View.VISIBLE : View.GONE);
    }

    private void refreshAccountSpinners() {
        accountChoices = new ArrayList<>(db.accounts);
        List<String> names = new ArrayList<>();
        for (Account a : accountChoices) {
            names.add((a.emoji != null ? a.emoji + " " : "") + a.name);
        }
        accountSpinner.setAdapter(Ui.spinnerAdapter(this, names));
        toAccountSpinner.setAdapter(Ui.spinnerAdapter(this, names));
        if (editing != null) {
            selectAccount(accountSpinner, editing.accountId);
            selectAccount(toAccountSpinner, editing.toAccountId);
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

    private void refreshCategorySpinner() {
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
        if (editing != null && editing.categoryId != null) {
            for (int i = 1; i < categoryChoices.size(); i++) {
                if (editing.categoryId.equals(categoryChoices.get(i).id)) {
                    categorySpinner.setSelection(i);
                    break;
                }
            }
        }
    }

    private void save() {
        String name = nameInput.getText().toString().trim();
        if (name.isEmpty()) {
            toast("Give the template a name.");
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
        String toId = null;
        if ("transfer".equals(type)) {
            int toPos = toAccountSpinner.getSelectedItemPosition();
            if (toPos < 0 || toPos >= accountChoices.size()) {
                toast("Pick the destination account.");
                return;
            }
            toId = accountChoices.get(toPos).id;
            if (toId.equals(accountChoices.get(accPos).id)) {
                toast("Source and destination accounts must differ.");
                return;
            }
        }
        int catPos = categorySpinner.getSelectedItemPosition();
        String catId = (catPos >= 0 && catPos < categoryChoices.size()
                && categoryChoices.get(catPos) != null)
                ? categoryChoices.get(catPos).id : null;

        Template tpl = new Template();
        tpl.id = editing != null ? editing.id : "tpl_" + System.currentTimeMillis();
        tpl.name = name;
        tpl.type = type;
        tpl.amount = amount;
        tpl.accountId = accountChoices.get(accPos).id;
        tpl.toAccountId = toId;
        tpl.categoryId = catId;
        tpl.note = noteInput.getText().toString().trim();

        if (editing == null) {
            db.templates.add(tpl);
        } else {
            for (int i = 0; i < db.templates.size(); i++) {
                if (tpl.id.equals(db.templates.get(i).id)) {
                    db.templates.set(i, tpl);
                    break;
                }
            }
        }
        store.save();
        toast("Template saved.");
        finish();
    }

    private void confirmDelete() {
        new AlertDialog.Builder(this)
                .setTitle("Delete template?")
                .setMessage("Delete \"" + editing.name + "\"? Transactions it "
                        + "already created stay untouched.")
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Delete", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface d, int w) {
                        db.templates.remove(editing);
                        store.save();
                        toast("Template deleted.");
                        finish();
                    }
                })
                .show();
    }

    private void toast(String msg) {
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show();
    }
}
