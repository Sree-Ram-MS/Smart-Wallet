package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import java.util.List;

/**
 * Phase 3: Debts & Credits — Flutter's two screens (Debts = lent,
 * Credits = borrowed) merged into one screen with Lent / Borrowed
 * tabs, per the phase brief. Settle/Close and Reopen follow the
 * Flutter semantics in WalletLogic (settlement is a real transaction
 * when the record affects an account).
 */
public class DebtsActivity extends Activity {

    private Store store;
    private WalletDb db;
    private LinearLayout body;
    private LinearLayout tabRow;
    private String direction = "lent";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = new Store(this);
        db = store.db();

        LinearLayout root = Ui.page(this, "Debts & Credits", new View.OnClickListener() {
            @Override public void onClick(View v) { openEditor(null); }
        });
        android.widget.ScrollView scroll = Ui.scrollBody(this, root);
        LinearLayout pageBody = (LinearLayout) scroll.getChildAt(0);
        setContentView(root);

        tabRow = new LinearLayout(this);
        tabRow.setOrientation(LinearLayout.HORIZONTAL);
        tabRow.setLayoutParams(Ui.lpTop(this, 4));
        pageBody.addView(tabRow);

        body = new LinearLayout(this);
        body.setOrientation(LinearLayout.VERTICAL);
        pageBody.addView(body);
        render();
    }

    @Override
    protected void onResume() {
        super.onResume();
        db = store.load();
        render();
    }

    private void renderTabs() {
        tabRow.removeAllViews();
        tabRow.addView(tabChip("lent", "💸 Lent (Debts)"));
        tabRow.addView(tabChip("borrowed", "💳 Borrowed (Credits)"));
    }

    private View tabChip(final String dir, String label) {
        TextView chip = Ui.chip(this, label, dir.equals(direction),
                "lent".equals(dir) ? Ui.EXPENSE : Ui.TRANSFER);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        lp.rightMargin = Ui.dp(this, 4);
        chip.setLayoutParams(lp);
        chip.setGravity(Gravity.CENTER);
        chip.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                direction = dir;
                render();
            }
        });
        return chip;
    }

    private void render() {
        renderTabs();
        body.removeAllViews();

        double activeTotal = WalletLogic.totalActiveDebt(db.debtCredits, direction);
        LinearLayout totalCard = Ui.card(this, Ui.CARD);
        totalCard.setLayoutParams(Ui.lpTop(this, 12));
        totalCard.addView(Ui.tv(this, "lent".equals(direction)
                ? "Total people owe you" : "Total you owe", 12, Ui.SECONDARY, true));
        TextView amt = Ui.tv(this, WalletLogic.formatINR(activeTotal), 22,
                "lent".equals(direction) ? Ui.EXPENSE : Ui.TRANSFER, true);
        amt.setLayoutParams(Ui.lpTop(this, 2));
        totalCard.addView(amt);
        body.addView(totalCard);

        boolean anyActive = false, anyClosed = false;
        for (DebtCredit d : db.debtCredits) {
            if (direction.equals(d.direction)) {
                if ("active".equals(d.status)) anyActive = true; else anyClosed = true;
            }
        }
        if (!anyActive && !anyClosed) {
            TextView empty = Ui.tv(this, "lent".equals(direction)
                    ? "No debts recorded. Add who owes you with + ."
                    : "No credits recorded. Add what you borrowed with + .",
                    13, Ui.SECONDARY, false);
            empty.setLayoutParams(Ui.lpTop(this, 16));
            body.addView(empty);
            return;
        }
        if (anyActive) {
            TextView h = Ui.tv(this, "lent".equals(direction) ? "ACTIVE DEBTS" : "ACTIVE CREDITS",
                    12, Ui.SECONDARY, true);
            h.setLayoutParams(Ui.lpTop(this, 16));
            body.addView(h);
            for (DebtCredit d : db.debtCredits) {
                if (direction.equals(d.direction) && "active".equals(d.status)) {
                    body.addView(debtCard(d));
                }
            }
        }
        if (anyClosed) {
            TextView h = Ui.tv(this, "lent".equals(direction) ? "RECOVERED" : "REPAID",
                    12, Ui.SECONDARY, true);
            h.setLayoutParams(Ui.lpTop(this, 16));
            body.addView(h);
            for (DebtCredit d : db.debtCredits) {
                if (direction.equals(d.direction) && !"active".equals(d.status)) {
                    body.addView(debtCard(d));
                }
            }
        }
    }

    private View debtCard(final DebtCredit d) {
        LinearLayout card = Ui.card(this, Ui.CARD);
        card.setLayoutParams(Ui.lpTop(this, 10));
        Account acc = WalletLogic.accountById(db.accounts, d.accountId);

        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        TextView avatar = Ui.tv(this, d.personName != null && !d.personName.isEmpty()
                ? d.personName.substring(0, 1).toUpperCase(java.util.Locale.ENGLISH) : "?",
                18, Ui.TEXT, true);
        avatar.setGravity(Gravity.CENTER);
        avatar.setBackground(Ui.circle("lent".equals(d.direction) ? Ui.EXPENSE : Ui.TRANSFER, this));
        avatar.setLayoutParams(new LinearLayout.LayoutParams(Ui.dp(this, 44), Ui.dp(this, 44)));
        row.addView(avatar);

        LinearLayout mid = new LinearLayout(this);
        mid.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams mlp = new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        mlp.leftMargin = Ui.dp(this, 12);
        mid.setLayoutParams(mlp);
        mid.addView(Ui.tv(this, d.personName, 15, Ui.TEXT, true));
        mid.addView(Ui.tv(this, Ui.prettyDate(d.startDate)
                + (acc != null ? " • " + (acc.emoji != null ? acc.emoji + " " : "") + acc.name : "")
                + (d.affectsAccount ? "" : " • not in account"), 11, Ui.SECONDARY, false));
        if (d.dueDate != null && "active".equals(d.status)) {
            boolean overdue = d.dueDate.substring(0, 10)
                    .compareTo(java.time.LocalDate.now().toString()) < 0;
            mid.addView(Ui.tv(this, (overdue ? "⚠ Overdue • " : "Due ")
                    + Ui.prettyDate(d.dueDate), 11, overdue ? Ui.EXPENSE : Ui.SECONDARY, overdue));
        }
        if (d.notes != null && !d.notes.isEmpty()) {
            mid.addView(Ui.tv(this, d.notes, 11, Ui.SECONDARY, false));
        }
        row.addView(mid);

        LinearLayout right = new LinearLayout(this);
        right.setOrientation(LinearLayout.VERTICAL);
        TextView amt = Ui.tv(this, WalletLogic.formatINR(d.amount), 15, Ui.TEXT, true);
        amt.setGravity(Gravity.RIGHT);
        right.addView(amt);
        boolean closed = !"active".equals(d.status);
        right.addView(Ui.chip(this, closed ? "✓ Closed" : "● Active",
                false, closed ? Ui.INCOME : Ui.SECONDARY));
        row.addView(right);
        card.addView(row);

        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        actions.setGravity(Gravity.END);
        actions.setLayoutParams(Ui.lpTop(this, 8));
        if (!closed) {
            TextView settle = Ui.chip(this,
                    "lent".equals(d.direction) ? "✓ Mark Recovered" : "✓ Mark Repaid",
                    true, Ui.INCOME);
            settle.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) { confirmSettle(d); }
            });
            actions.addView(settle);
        } else {
            TextView reopen = Ui.chip(this, "↩ Reopen", false, Ui.SECONDARY);
            reopen.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) { confirmReopen(d); }
            });
            actions.addView(reopen);
        }
        TextView edit = Ui.chip(this, "Edit", false, Ui.SECONDARY);
        edit.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { openEditor(d.id); }
        });
        actions.addView(edit);
        card.addView(actions);
        return card;
    }

    private void confirmSettle(final DebtCredit d) {
        boolean lent = "lent".equals(d.direction);
        String msg = d.affectsAccount
                ? "A " + (lent ? "income" : "expense") + " of "
                        + WalletLogic.formatINR(d.amount) + " will be recorded "
                        + "and the record closed."
                : "The record will be closed. It does not affect any account, "
                        + "so no transaction is recorded.";
        new AlertDialog.Builder(this)
                .setTitle(lent ? "Mark as recovered?" : "Mark as repaid?")
                .setMessage(msg)
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Settle", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface dlg, int w) {
                        WalletLogic.settleDebt(db, d, WalletLogic.nowIso(),
                                "tx_" + System.currentTimeMillis());
                        store.save();
                        Toast.makeText(DebtsActivity.this, "Settled.", Toast.LENGTH_SHORT).show();
                        render();
                    }
                })
                .show();
    }

    private void confirmReopen(final DebtCredit d) {
        new AlertDialog.Builder(this)
                .setTitle("Reopen this record?")
                .setMessage(d.affectsAccount
                        ? "The settlement transaction will be removed (balances "
                                + "reversed) and the record becomes active again."
                        : "The record becomes active again.")
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Reopen", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface dlg, int w) {
                        WalletLogic.reopenDebt(db, d);
                        store.save();
                        Toast.makeText(DebtsActivity.this, "Reopened.", Toast.LENGTH_SHORT).show();
                        render();
                    }
                })
                .show();
    }

    private void openEditor(String debtId) {
        Intent i = new Intent(this, DebtEditActivity.class);
        i.putExtra(DebtEditActivity.EXTRA_DIRECTION, direction);
        if (debtId != null) i.putExtra(DebtEditActivity.EXTRA_DEBT_ID, debtId);
        startActivity(i);
    }
}
