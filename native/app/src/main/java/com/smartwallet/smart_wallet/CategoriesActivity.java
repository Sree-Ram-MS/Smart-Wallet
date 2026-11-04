package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.content.Intent;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * Phase 2: Config → Categories. Income group first, then Expense;
 * sub-categories are indented under their parent. Tap to edit, + to add.
 */
public class CategoriesActivity extends Activity {

    private Store store;
    private WalletDb db;
    private LinearLayout body;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = new Store(this);
        db = store.db();

        LinearLayout root = Ui.page(this, "Categories", new View.OnClickListener() {
            @Override public void onClick(View v) { openEditor(null); }
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
        renderGroup("income", "↓ Income", Ui.INCOME);
        renderGroup("expense", "↑ Expense", Ui.EXPENSE);
        if (db.categories.isEmpty()) {
            TextView empty = Ui.tv(this, "No categories yet. Tap + to add one.",
                    13, Ui.SECONDARY, false);
            empty.setLayoutParams(Ui.lpTop(this, 16));
            body.addView(empty);
        }
    }

    private void renderGroup(String type, String title, int color) {
        boolean any = false;
        for (Category c : db.categories) {
            if (c != null && type.equals(c.type)) { any = true; break; }
        }
        if (!any) return;

        TextView header = Ui.tv(this, title, 16, color, true);
        header.setLayoutParams(Ui.lpTop(this, 18));
        body.addView(header);

        for (Category parent : WalletLogic.categoriesForPicker(db.categories, type)) {
            body.addView(row(parent, parent.parentId != null));
        }
    }

    private View row(final Category c, boolean isSub) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(Ui.dp(this, isSub ? 34 : 12), Ui.dp(this, 9),
                Ui.dp(this, 12), Ui.dp(this, 9));
        row.setBackground(Ui.rounded(Ui.CARD, 14, this));
        row.setLayoutParams(Ui.lpTop(this, 8));

        TextView icon = Ui.tv(this, c.icon == null || c.icon.isEmpty() ? "📦" : c.icon,
                18, Ui.TEXT, false);
        icon.setGravity(Gravity.CENTER);
        GradientDrawable circle = new GradientDrawable();
        circle.setShape(GradientDrawable.OVAL);
        circle.setColor(Ui.withAlpha(c.colorInt(), 48));
        icon.setBackground(circle);
        icon.setLayoutParams(new LinearLayout.LayoutParams(
                Ui.dp(this, 40), Ui.dp(this, 40)));
        row.addView(icon);

        LinearLayout mid = new LinearLayout(this);
        mid.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams mlp = new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        mlp.leftMargin = Ui.dp(this, 12);
        mid.setLayoutParams(mlp);
        mid.addView(Ui.tv(this, (isSub ? "↳ " : "") + c.name, 14, Ui.TEXT, true));
        if (isSub) {
            Category parent = WalletLogic.categoryById(db.categories, c.parentId);
            mid.addView(Ui.tv(this, "under " + (parent != null ? parent.name : "?"),
                    12, Ui.SECONDARY, false));
        } else {
            int subs = 0;
            for (Category s : db.categories) if (s != null && c.id.equals(s.parentId)) subs++;
            if (subs > 0) {
                mid.addView(Ui.tv(this, subs + (subs == 1
                        ? " sub-category" : " sub-categories"), 12, Ui.SECONDARY, false));
            }
        }
        row.addView(mid);

        row.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { openEditor(c.id); }
        });
        return row;
    }

    private void openEditor(String categoryId) {
        Intent i = new Intent(this, CategoryEditActivity.class);
        if (categoryId != null) i.putExtra(CategoryEditActivity.EXTRA_CATEGORY_ID, categoryId);
        startActivity(i);
    }
}
