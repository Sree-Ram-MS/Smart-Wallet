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

import java.time.LocalDate;
import java.util.List;

/**
 * Phase 3: Planned Payments — sorted by next due date (Flutter's
 * getPlanned), overdue highlighted, occurrence progress and end info,
 * with Mark Paid (creates the real expense transaction) and Skip
 * (advance without paying) per row.
 */
public class PlannedActivity extends Activity {

    private Store store;
    private WalletDb db;
    private LinearLayout body;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = new Store(this);
        db = store.db();

        LinearLayout root = Ui.page(this, "Planned Payments", new View.OnClickListener() {
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
        List<PlannedPayment> all = WalletLogic.plannedSorted(db);
        if (all.isEmpty()) {
            TextView empty = Ui.tv(this, "No planned payments.\n"
                    + "Add subscriptions, EMIs, or bills with + .", 13, Ui.SECONDARY, false);
            empty.setLayoutParams(Ui.lpTop(this, 16));
            body.addView(empty);
            return;
        }
        String today = LocalDate.now().toString();
        boolean completedHeaderShown = false;
        for (PlannedPayment p : all) {
            if (p.isCompleted && !completedHeaderShown) {
                completedHeaderShown = true;
                TextView h = Ui.tv(this, "COMPLETED", 12, Ui.SECONDARY, true);
                h.setLayoutParams(Ui.lpTop(this, 20));
                body.addView(h);
            }
            body.addView(plannedCard(p, today));
        }
    }

    private View plannedCard(final PlannedPayment p, String today) {
        LinearLayout card = Ui.card(this, Ui.CARD);
        card.setLayoutParams(Ui.lpTop(this, 10));

        Account acc = WalletLogic.accountById(db.accounts, p.accountId);
        Category cat = WalletLogic.categoryById(db.categories, p.categoryId);
        boolean overdue = WalletLogic.isOverdue(p, today);
        boolean paidToday = p.lastPaidDate != null && p.lastPaidDate.startsWith(today);

        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        TextView icon = Ui.tv(this, cat != null && cat.icon != null && !cat.icon.isEmpty()
                ? cat.icon : "📅", 22, Ui.TEXT, false);
        icon.setGravity(Gravity.CENTER);
        icon.setBackground(Ui.rounded(Ui.CARD_ALT, 12, this));
        icon.setLayoutParams(new LinearLayout.LayoutParams(
                Ui.dp(this, 44), Ui.dp(this, 44)));
        row.addView(icon);

        LinearLayout mid = new LinearLayout(this);
        mid.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams mlp = new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        mlp.leftMargin = Ui.dp(this, 12);
        mid.setLayoutParams(mlp);
        TextView name = Ui.tv(this, p.name == null ? "" : p.name, 15, Ui.TEXT, true);
        if (p.isCompleted) {
            name.setPaintFlags(name.getPaintFlags()
                    | android.graphics.Paint.STRIKE_THRU_TEXT_FLAG);
        }
        mid.addView(name);
        StringBuilder detail = new StringBuilder();
        if (paidToday && !p.isCompleted) {
            detail.append("Paid today • Next: ").append(Ui.prettyDate(p.nextDueDate));
        } else {
            detail.append(p.isCompleted ? "Done • " : overdue ? "Overdue • " : "Due ")
                    .append(Ui.prettyDate(p.nextDueDate));
        }
        if (p.isRecurring) {
            detail.append(" • ").append(p.period == null ? "MONTHLY"
                    : p.period.toUpperCase(java.util.Locale.ENGLISH));
            if ("occurrences".equals(p.endType)) {
                detail.append(" • ").append(p.currentOccurrence).append("/")
                        .append(p.totalOccurrences != null
                                ? String.valueOf(p.totalOccurrences) : "∞").append(" times");
            } else if ("until_date".equals(p.endType) && p.untilDate != null) {
                detail.append(" • Till ").append(Ui.prettyDate(p.untilDate));
            } else {
                detail.append(" • Ongoing");
            }
        }
        TextView det = Ui.tv(this, detail.toString(), 12,
                p.isCompleted ? Ui.MUTED : overdue ? Ui.EXPENSE
                        : paidToday ? Ui.INCOME : Ui.SECONDARY, overdue || paidToday);
        mid.addView(det);
        if (acc != null) {
            mid.addView(Ui.tv(this, (acc.emoji != null ? acc.emoji + " " : "") + acc.name,
                    11, Ui.SECONDARY, false));
        }
        if (p.isSplit && p.splits != null && !p.splits.isEmpty()) {
            double share = 0;
            for (SplitMember s : p.splits) share += s.amount;
            mid.addView(Ui.tv(this, "👥 Split (" + p.splits.size() + " people • "
                    + WalletLogic.formatINR(share) + " shared)", 11, Ui.PRIMARY, false));
        }
        row.addView(mid);

        TextView amount = Ui.tv(this, WalletLogic.formatINR(p.amount), 16, Ui.TEXT, true);
        amount.setGravity(Gravity.RIGHT);
        row.addView(amount);
        card.addView(row);

        if (p.isCompleted) {
            TextView done = Ui.tv(this, "✓ Completed"
                    + (p.lastPaidDate != null
                            ? " • Last paid " + Ui.prettyDate(p.lastPaidDate) : ""),
                    12, Ui.INCOME, true);
            done.setLayoutParams(Ui.lpTop(this, 8));
            card.addView(done);
        } else {
            LinearLayout actions = new LinearLayout(this);
            actions.setOrientation(LinearLayout.HORIZONTAL);
            actions.setGravity(Gravity.END);
            actions.setLayoutParams(Ui.lpTop(this, 8));
            if (paidToday) {
                TextView badge = Ui.chip(this, "✓ Paid Today", true, Ui.INCOME);
                actions.addView(badge);
            } else {
                TextView pay = Ui.chip(this, "✓ Mark Paid", true, Ui.PRIMARY);
                pay.setOnClickListener(new View.OnClickListener() {
                    @Override public void onClick(View v) { confirmPay(p); }
                });
                actions.addView(pay);
                TextView skip = Ui.chip(this, "Skip ⏭", false, Ui.SECONDARY);
                skip.setOnClickListener(new View.OnClickListener() {
                    @Override public void onClick(View v) { confirmSkip(p); }
                });
                actions.addView(skip);
            }
            TextView edit = Ui.chip(this, "Edit", false, Ui.SECONDARY);
            edit.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) { openEditor(p.id); }
            });
            actions.addView(edit);
            card.addView(actions);
        }
        Ui.entrance(card, this, 0);
        return card;
    }

    private void confirmPay(final PlannedPayment p) {
        new AlertDialog.Builder(this)
                .setTitle("Mark as paid?")
                .setMessage("Record an expense of " + WalletLogic.formatINR(p.amount)
                        + " for \"" + p.name + "\" now? The amount will be taken "
                        + "from the account and the schedule will advance.")
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Mark Paid", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface d, int w) {
                        WalletLogic.markPlannedPaid(db, p,
                                WalletLogic.nowIso(),
                                "tx_" + System.currentTimeMillis());
                        store.save();
                        NotifService.sync(PlannedActivity.this);
                        Toast.makeText(PlannedActivity.this,
                                "Marked \"" + p.name + "\" as paid & recorded transaction!",
                                Toast.LENGTH_SHORT).show();
                        render();
                    }
                })
                .show();
    }

    private void confirmSkip(final PlannedPayment p) {
        String msg = p.isRecurring
                ? "Skip this occurrence of \"" + p.name + "\"? No transaction "
                        + "will be recorded; the schedule just moves to the next due date."
                : "Skip \"" + p.name + "\"? It will be marked completed without "
                        + "recording a transaction.";
        new AlertDialog.Builder(this)
                .setTitle("Skip this payment?")
                .setMessage(msg)
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Skip", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface d, int w) {
                        WalletLogic.skipPlanned(p);
                        store.save();
                        NotifService.sync(PlannedActivity.this);
                        Toast.makeText(PlannedActivity.this,
                                "Skipped \"" + p.name + "\".", Toast.LENGTH_SHORT).show();
                        render();
                    }
                })
                .show();
    }

    private void openEditor(String plannedId) {
        Intent i = new Intent(this, PlannedEditActivity.class);
        if (plannedId != null) i.putExtra(PlannedEditActivity.EXTRA_PLANNED_ID, plannedId);
        startActivity(i);
    }
}
