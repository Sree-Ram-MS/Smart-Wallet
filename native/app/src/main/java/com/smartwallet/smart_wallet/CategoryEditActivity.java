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
 * Phase 2: add / edit / delete a category. Parent must be a top-level
 * category of the SAME type. Changing the type of a category that has
 * sub-categories is blocked (its children would end up under a parent
 * of the wrong type). Delete is guarded by
 * WalletLogic.categoryDeleteBlockReason.
 */
public class CategoryEditActivity extends Activity {

    public static final String EXTRA_CATEGORY_ID = "category_id";

    private Store store;
    private WalletDb db;
    private Category editing;

    private String type = "expense";
    private LinearLayout typeRow;
    private EditText nameInput;
    private EditText emojiInput;
    private LinearLayout emojiRow;
    private LinearLayout colorBox;
    private long pickedColor;
    private Spinner parentSpinner;
    private List<Category> parentChoices = new ArrayList<>(); // index 0 = none

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = new Store(this);
        db = store.db();

        String id = getIntent() != null ? getIntent().getStringExtra(EXTRA_CATEGORY_ID) : null;
        editing = id != null ? WalletLogic.categoryById(db.categories, id) : null;
        if (editing != null) {
            type = editing.type != null ? editing.type : "expense";
            pickedColor = editing.colorValue;
        } else {
            pickedColor = Ui.CATEGORY_COLORS[0];
        }

        LinearLayout root = Ui.page(this,
                editing == null ? "Add Category" : "Edit Category", null);
        android.widget.ScrollView scroll = Ui.scrollBody(this, root);
        LinearLayout body = (LinearLayout) scroll.getChildAt(0);
        setContentView(root);

        body.addView(Ui.label(this, "TYPE"));
        typeRow = new LinearLayout(this);
        typeRow.setOrientation(LinearLayout.HORIZONTAL);
        typeRow.setLayoutParams(Ui.lpTop(this, 6));
        body.addView(typeRow);
        renderTypeChips();

        body.addView(Ui.label(this, "NAME"));
        nameInput = Ui.input(this, "e.g. Groceries", editing != null ? editing.name : "");
        body.addView(nameInput);

        body.addView(Ui.label(this, "EMOJI"));
        emojiInput = Ui.input(this, "📦", editing != null ? editing.icon : "📦");
        body.addView(emojiInput);
        emojiRow = new LinearLayout(this);
        emojiRow.setOrientation(LinearLayout.HORIZONTAL);
        emojiRow.setLayoutParams(Ui.lpTop(this, 6));
        body.addView(emojiRow);
        renderEmojiRow();

        body.addView(Ui.label(this, "COLOUR"));
        // Palette has 10 colours; renderColorRow fills this box with rows of 5.
        colorBox = new LinearLayout(this);
        colorBox.setOrientation(LinearLayout.VERTICAL);
        body.addView(colorBox);
        renderColorRow();

        body.addView(Ui.label(this, "PARENT CATEGORY (OPTIONAL)"));
        parentSpinner = new Spinner(this);
        parentSpinner.setBackground(Ui.rounded(Ui.CARD, 12, this));
        parentSpinner.setLayoutParams(Ui.lpTop(this, 6));
        body.addView(parentSpinner);
        refreshParentSpinner();

        if (editing != null && editing.parentId == null && hasChildren(editing.id)) {
            TextView note = Ui.tv(this, "This category has sub-categories, so its "
                    + "type can't be changed and it can't become a sub-category.",
                    12, Ui.SECONDARY, false);
            note.setLayoutParams(Ui.lpTop(this, 10));
            body.addView(note);
            parentSpinner.setEnabled(false);
        }

        Button save = Ui.primaryButton(this,
                editing == null ? "Add Category" : "Save Changes", Ui.PRIMARY);
        save.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { save(); }
        });
        body.addView(save);

        if (editing != null) {
            Button del = Ui.dangerButton(this, "Delete Category");
            del.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) { tryDelete(); }
            });
            body.addView(del);
        }
    }

    private boolean hasChildren(String categoryId) {
        for (Category c : db.categories) {
            if (c != null && categoryId.equals(c.parentId)) return true;
        }
        return false;
    }

    private void renderTypeChips() {
        typeRow.removeAllViews();
        final String[] types = {"income", "expense"};
        final String[] labels = {"↓ Income", "↑ Expense"};
        for (int i = 0; i < types.length; i++) {
            final String tp = types[i];
            TextView chip = Ui.chip(this, labels[i], tp.equals(type),
                    "income".equals(tp) ? Ui.INCOME : Ui.EXPENSE);
            chip.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) {
                    if (tp.equals(type)) return;
                    if (editing != null && hasChildren(editing.id)) {
                        toast("Can't change type: this category has sub-categories.");
                        return;
                    }
                    type = tp;
                    renderTypeChips();
                    refreshParentSpinner();
                }
            });
            typeRow.addView(chip);
        }
    }

    private void renderEmojiRow() {
        emojiRow.removeAllViews();
        // First 10 preset emojis as quick-pick; the field above accepts any emoji.
        for (int i = 0; i < 10 && i < Ui.CATEGORY_EMOJIS.length; i++) {
            final String e = Ui.CATEGORY_EMOJIS[i];
            TextView t = Ui.tv(this, e, 20, Ui.TEXT, false);
            t.setPadding(Ui.dp(this, 6), Ui.dp(this, 4), Ui.dp(this, 6), Ui.dp(this, 4));
            t.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) { emojiInput.setText(e); }
            });
            emojiRow.addView(t);
        }
    }

    private void renderColorRow() {
        colorBox.removeAllViews();
        LinearLayout row = null;
        for (int i = 0; i < Ui.CATEGORY_COLORS.length; i++) {
            if (i % 5 == 0) {
                row = new LinearLayout(this);
                row.setOrientation(LinearLayout.HORIZONTAL);
                colorBox.addView(row);
            }
            final long color = Ui.CATEGORY_COLORS[i];
            row.addView(Ui.swatch(this, color, color == pickedColor,
                    new View.OnClickListener() {
                        @Override public void onClick(View v) {
                            pickedColor = color;
                            renderColorRow();
                        }
                    }));
        }
    }

    private void refreshParentSpinner() {
        String wanted = editing != null ? editing.parentId : null;
        parentChoices = new ArrayList<>();
        List<String> names = new ArrayList<>();
        names.add("(top-level — no parent)");
        for (Category c : db.categories) {
            if (c == null || c.parentId != null || !type.equals(c.type)) continue;
            if (editing != null && c.id.equals(editing.id)) continue; // not its own parent
            parentChoices.add(c);
            names.add((c.icon != null ? c.icon + " " : "") + c.name);
        }
        parentSpinner.setAdapter(Ui.spinnerAdapter(this, names));
        if (wanted != null) {
            for (int i = 0; i < parentChoices.size(); i++) {
                if (wanted.equals(parentChoices.get(i).id)) {
                    parentSpinner.setSelection(i + 1);
                    break;
                }
            }
        }
    }

    private void save() {
        String name = nameInput.getText().toString().trim();
        if (name.isEmpty()) {
            toast("Give the category a name.");
            return;
        }
        Category c = editing != null ? editing : new Category();
        if (editing == null) c.id = "cat_" + System.currentTimeMillis();
        c.name = name;
        c.type = type;
        String emoji = emojiInput.getText().toString().trim();
        c.icon = emoji.isEmpty() ? "📦" : emoji;
        c.colorValue = pickedColor;
        int pos = parentSpinner.getSelectedItemPosition();
        c.parentId = (pos > 0 && pos - 1 < parentChoices.size())
                ? parentChoices.get(pos - 1).id : null;
        if (editing == null) db.categories.add(c);
        store.save();
        toast(editing == null ? "Category added." : "Category updated.");
        finish();
    }

    private void tryDelete() {
        String reason = WalletLogic.categoryDeleteBlockReason(db, editing.id);
        if (reason != null) {
            new AlertDialog.Builder(this)
                    .setTitle("Can't delete this category")
                    .setMessage(reason)
                    .setPositiveButton("OK", null)
                    .show();
            return;
        }
        new AlertDialog.Builder(this)
                .setTitle("Delete category?")
                .setMessage("Delete \"" + editing.name + "\"? This cannot be undone.")
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Delete", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface d, int w) {
                        db.categories.remove(editing);
                        store.save();
                        toast("Category deleted.");
                        finish();
                    }
                })
                .show();
    }

    private void toast(String msg) {
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show();
    }
}
