package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * Phase 2: Manage Accounts — every account as a card (emoji, name,
 * balance, card type, counted/not-counted), the net wallet total at
 * the top, tap to edit, + to add.
 */
public class AccountsActivity extends Activity {

    private Store store;
    private WalletDb db;
    private LinearLayout body;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = new Store(this);
        db = store.db();

        LinearLayout root = Ui.page(this, "Manage Accounts", new View.OnClickListener() {
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

        LinearLayout netCard = Ui.card(this, Ui.CARD_ALT);
        netCard.addView(Ui.tv(this, "NET WALLET (counted accounts)", 11, Ui.SECONDARY, true));
        TextView net = Ui.tv(this, WalletLogic.formatINR(WalletLogic.netWallet(db.accounts)),
                28, Ui.TEXT, true);
        net.setLayoutParams(Ui.lpTop(this, 4));
        netCard.addView(net);
        body.addView(netCard);

        if (db.accounts.isEmpty()) {
            TextView empty = Ui.tv(this, "No accounts yet. Tap + to add your first account.",
                    13, Ui.SECONDARY, false);
            empty.setLayoutParams(Ui.lpTop(this, 16));
            body.addView(empty);
            return;
        }

        int anim = 0;
        for (final Account a : db.accounts) {
            body.addView(accountCard(a));
            anim += 40;
        }
    }

    private View accountCard(final Account a) {
        LinearLayout card = Ui.card(this, Ui.CARD);
        card.setLayoutParams(Ui.lpTop(this, 10));

        // colour strip
        View strip = new View(this);
        android.graphics.drawable.GradientDrawable stripBg =
                new android.graphics.drawable.GradientDrawable();
        stripBg.setColor(a.colorInt());
        stripBg.setCornerRadius(Ui.dp(this, 3));
        strip.setBackground(stripBg);
        strip.setLayoutParams(new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, Ui.dp(this, 5)));
        card.addView(strip);

        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setLayoutParams(Ui.lpTop(this, 10));
        TextView emoji = Ui.tv(this, a.emoji == null || a.emoji.isEmpty() ? "💳" : a.emoji,
                26, Ui.TEXT, false);
        row.addView(emoji);
        LinearLayout mid = new LinearLayout(this);
        mid.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams mlp = new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        mlp.leftMargin = Ui.dp(this, 12);
        mid.setLayoutParams(mlp);
        mid.addView(Ui.tv(this, a.name, 15, Ui.TEXT, true));
        StringBuilder sub = new StringBuilder();
        if (a.cardType != null && !a.cardType.isEmpty()) sub.append(a.cardType).append("  •  ");
        sub.append(a.currency != null ? a.currency : "INR");
        if (!a.isEnabledForCalc) sub.append("  •  not counted in net wallet");
        mid.addView(Ui.tv(this, sub.toString(), 12, Ui.SECONDARY, false));
        row.addView(mid);
        TextView bal = Ui.tv(this, WalletLogic.formatINR(a.balance), 17,
                a.balance < 0 ? Ui.EXPENSE : Ui.TEXT, true);
        row.addView(bal);
        card.addView(row);

        if (a.notes != null && !a.notes.isEmpty()) {
            TextView notes = Ui.tv(this, a.notes, 12, Ui.SECONDARY, false);
            notes.setLayoutParams(Ui.lpTop(this, 6));
            card.addView(notes);
        }

        card.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { openEditor(a.id); }
        });
        Ui.entrance(card, this, 0);
        return card;
    }

    private void openEditor(String accountId) {
        Intent i = new Intent(this, AccountEditActivity.class);
        if (accountId != null) i.putExtra(AccountEditActivity.EXTRA_ACCOUNT_ID, accountId);
        startActivity(i);
    }
}
