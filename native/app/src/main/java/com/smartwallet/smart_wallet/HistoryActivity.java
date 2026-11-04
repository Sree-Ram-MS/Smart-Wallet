package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.content.Intent;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.List;

/**
 * Phase 2: full transaction history — newest first, text search over
 * note/category/account, and All / Income / Expense / Transfer chips.
 * Tap a row to edit it (split transactions open read-only, see
 * TxEditActivity). The + in the header starts a new transaction.
 */
public class HistoryActivity extends Activity {

    private Store store;
    private WalletDb db;
    private LinearLayout listBox;
    private String typeFilter = "all";
    private String query = "";
    private LinearLayout chipsRow;

    private static final String[] CHIP_LABELS = {"All", "Income", "Expense", "Transfer"};
    private static final String[] CHIP_TYPES = {"all", "income", "expense", "transfer"};

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = new Store(this);
        db = store.db();

        LinearLayout root = Ui.page(this, "Transactions", new View.OnClickListener() {
            @Override public void onClick(View v) { openEditor(null); }
        });
        android.widget.ScrollView scroll = Ui.scrollBody(this, root);
        LinearLayout body = (LinearLayout) scroll.getChildAt(0);

        EditText search = Ui.input(this, "Search note, category, account…", "");
        search.setLayoutParams(Ui.lp(this));
        search.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int a, int b, int c) {}
            @Override public void onTextChanged(CharSequence s, int a, int b, int c) {}
            @Override public void afterTextChanged(Editable s) {
                query = s.toString();
                renderList();
            }
        });
        body.addView(search);

        chipsRow = new LinearLayout(this);
        chipsRow.setOrientation(LinearLayout.HORIZONTAL);
        chipsRow.setLayoutParams(Ui.lpTop(this, 12));
        body.addView(chipsRow);
        renderChips();

        listBox = new LinearLayout(this);
        listBox.setOrientation(LinearLayout.VERTICAL);
        listBox.setLayoutParams(Ui.lpTop(this, 12));
        body.addView(listBox);

        setContentView(root);
        renderList();
    }

    @Override
    protected void onResume() {
        super.onResume();
        db = store.load(); // reflect edits made in the editor
        renderList();
    }

    private void renderChips() {
        chipsRow.removeAllViews();
        for (int i = 0; i < CHIP_LABELS.length; i++) {
            final String type = CHIP_TYPES[i];
            int color = "income".equals(type) ? Ui.INCOME
                    : "expense".equals(type) ? Ui.EXPENSE
                    : "transfer".equals(type) ? Ui.TRANSFER : Ui.PRIMARY;
            TextView chip = Ui.chip(this, CHIP_LABELS[i], type.equals(typeFilter), color);
            chip.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) {
                    typeFilter = type;
                    renderChips();
                    renderList();
                }
            });
            chipsRow.addView(chip);
        }
    }

    private void renderList() {
        if (listBox == null) return;
        listBox.removeAllViews();
        List<Transaction> txs = WalletLogic.filterTransactions(
                db.transactions, typeFilter, query, db.categories, db.accounts);
        if (txs.isEmpty()) {
            TextView empty = Ui.tv(this, db.transactions.isEmpty()
                    ? "No transactions yet. Tap + to add your first one."
                    : "Nothing matches this search / filter.", 13, Ui.SECONDARY, false);
            empty.setLayoutParams(Ui.lpTop(this, 16));
            listBox.addView(empty);
            return;
        }
        TextView count = Ui.tv(this, txs.size() + (txs.size() == 1
                ? " transaction" : " transactions"), 12, Ui.SECONDARY, false);
        listBox.addView(count);
        for (Transaction t : txs) {
            listBox.addView(row(t));
        }
    }

    private View row(final Transaction t) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(Ui.dp(this, 12), Ui.dp(this, 10), Ui.dp(this, 12), Ui.dp(this, 10));
        row.setBackground(Ui.rounded(Ui.CARD, 14, this));
        LinearLayout.LayoutParams rlp = Ui.lpTop(this, 8);
        row.setLayoutParams(rlp);

        Category cat = WalletLogic.categoryById(db.categories, t.categoryId);

        TextView icon = Ui.tv(this, cat != null && cat.icon != null && !cat.icon.isEmpty()
                ? cat.icon : "📦", 20, Ui.TEXT, false);
        icon.setGravity(Gravity.CENTER);
        GradientDrawable circle = new GradientDrawable();
        circle.setShape(GradientDrawable.OVAL);
        circle.setColor(cat != null ? Ui.withAlpha(cat.colorInt(), 48) : Ui.CARD_ALT);
        icon.setBackground(circle);
        icon.setLayoutParams(new LinearLayout.LayoutParams(
                Ui.dp(this, 44), Ui.dp(this, 44)));
        row.addView(icon);

        LinearLayout middle = new LinearLayout(this);
        middle.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams mlp = new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        mlp.leftMargin = Ui.dp(this, 12);
        middle.setLayoutParams(mlp);
        String title = t.note != null && !t.note.isEmpty()
                ? t.note : (cat != null ? cat.name : "Transaction");
        if (title.length() > 38) title = title.substring(0, 37) + "…";
        middle.addView(Ui.tv(this, title, 14, Ui.TEXT, true));

        StringBuilder detail = new StringBuilder();
        if ("transfer".equals(t.type)) {
            Account from = WalletLogic.accountById(db.accounts, t.accountId);
            Account to = WalletLogic.accountById(db.accounts, t.toAccountId);
            detail.append(from != null ? from.name : "?")
                    .append(" → ").append(to != null ? to.name : "?");
        } else {
            if (cat != null) detail.append(cat.name);
            Account a = WalletLogic.accountById(db.accounts, t.accountId);
            if (a != null) {
                if (detail.length() > 0) detail.append("  •  ");
                detail.append(a.name);
            }
        }
        String dateLabel = Ui.prettyDate(t.date);
        if (!dateLabel.isEmpty()) {
            if (detail.length() > 0) detail.append("  •  ");
            detail.append(dateLabel);
        }
        if (t.isSplit) detail.append("  •  Split");
        middle.addView(Ui.tv(this, detail.toString(), 12, Ui.SECONDARY, false));
        row.addView(middle);

        int amountColor = "income".equals(t.type) ? Ui.INCOME
                : "expense".equals(t.type) ? Ui.EXPENSE : Ui.TRANSFER;
        TextView amount = Ui.tv(this, WalletLogic.formatSigned(t), 15, amountColor, true);
        amount.setGravity(Gravity.RIGHT);
        row.addView(amount);

        row.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { openEditor(t.id); }
        });
        return row;
    }

    private void openEditor(String txId) {
        Intent i = new Intent(this, TxEditActivity.class);
        if (txId != null) i.putExtra(TxEditActivity.EXTRA_TX_ID, txId);
        startActivity(i);
    }
}
