package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * Phase 3: Templates — tap a template to USE it (opens the transaction
 * editor prefilled, saved through the normal transaction path, exactly
 * like Flutter opening its add sheet from a template). Edit/Delete
 * buttons manage the template itself.
 */
public class TemplatesActivity extends Activity {

    private Store store;
    private WalletDb db;
    private LinearLayout body;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = new Store(this);
        db = store.db();

        LinearLayout root = Ui.page(this, "Templates", new View.OnClickListener() {
            @Override public void onClick(View v) {
                startActivity(new Intent(TemplatesActivity.this,
                        TemplateEditActivity.class));
            }
        });
        android.widget.ScrollView scroll = Ui.scrollBody(this, root);
        body = (LinearLayout) scroll.getChildAt(0);
        setContentView(root);
        render();
    }

    @Override
    protected void onResume() {
        super.onResume();
        db = store.load();
        render();
    }

    private void render() {
        body.removeAllViews();
        if (db.templates.isEmpty()) {
            TextView empty = Ui.tv(this, "No templates yet.\n"
                    + "Save your frequent transactions (coffee, metro, "
                    + "salary) as templates with + .", 13, Ui.SECONDARY, false);
            empty.setLayoutParams(Ui.lpTop(this, 16));
            body.addView(empty);
            return;
        }
        TextView hint = Ui.tv(this, "Tap a template to use it — it opens the "
                + "transaction form filled in, ready to save.", 12, Ui.SECONDARY, false);
        hint.setLayoutParams(Ui.lpTop(this, 6));
        body.addView(hint);

        for (final Template tpl : db.templates) {
            body.addView(templateCard(tpl));
        }
    }

    private View templateCard(final Template tpl) {
        LinearLayout card = Ui.card(this, Ui.CARD);
        card.setLayoutParams(Ui.lpTop(this, 10));
        Account acc = WalletLogic.accountById(db.accounts, tpl.accountId);
        Account toAcc = WalletLogic.accountById(db.accounts, tpl.toAccountId);
        Category cat = WalletLogic.categoryById(db.categories, tpl.categoryId);
        int typeColor = "income".equals(tpl.type) ? Ui.INCOME
                : "expense".equals(tpl.type) ? Ui.EXPENSE : Ui.TRANSFER;

        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        TextView icon = Ui.tv(this, cat != null && cat.icon != null && !cat.icon.isEmpty()
                ? cat.icon : "⚡", 20, Ui.TEXT, false);
        icon.setGravity(Gravity.CENTER);
        icon.setBackground(Ui.circle(typeColor, this));
        icon.setLayoutParams(new LinearLayout.LayoutParams(Ui.dp(this, 44), Ui.dp(this, 44)));
        row.addView(icon);

        LinearLayout mid = new LinearLayout(this);
        mid.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams mlp = new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        mlp.leftMargin = Ui.dp(this, 12);
        mid.setLayoutParams(mlp);
        mid.addView(Ui.tv(this, tpl.name, 15, Ui.TEXT, true));
        StringBuilder detail = new StringBuilder();
        detail.append(tpl.type.toUpperCase(java.util.Locale.ENGLISH));
        if (acc != null) detail.append(" • ").append(acc.name);
        if ("transfer".equals(tpl.type) && toAcc != null) {
            detail.append(" → ").append(toAcc.name);
        }
        if (cat != null) detail.append(" • ").append(cat.name);
        if (tpl.note != null && !tpl.note.isEmpty()) {
            detail.append(" • ").append(tpl.note);
        }
        mid.addView(Ui.tv(this, detail.toString(), 11, Ui.SECONDARY, false));
        row.addView(mid);

        TextView amt = Ui.tv(this, WalletLogic.formatINR(tpl.amount), 15, typeColor, true);
        amt.setGravity(Gravity.RIGHT);
        row.addView(amt);
        card.addView(row);

        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        actions.setGravity(Gravity.END);
        actions.setLayoutParams(Ui.lpTop(this, 8));
        TextView use = Ui.chip(this, "▶ Use", true, Ui.PRIMARY);
        use.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { useTemplate(tpl); }
        });
        actions.addView(use);
        TextView edit = Ui.chip(this, "Edit", false, Ui.SECONDARY);
        edit.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                Intent i = new Intent(TemplatesActivity.this, TemplateEditActivity.class);
                i.putExtra(TemplateEditActivity.EXTRA_TEMPLATE_ID, tpl.id);
                startActivity(i);
            }
        });
        actions.addView(edit);
        card.addView(actions);

        card.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { useTemplate(tpl); }
        });
        return card;
    }

    private void useTemplate(Template tpl) {
        Intent i = new Intent(this, TxEditActivity.class);
        i.putExtra(TxEditActivity.EXTRA_TEMPLATE_ID, tpl.id);
        startActivity(i);
    }
}
