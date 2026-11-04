package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.LinearLayout;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

/**
 * Phase 3: Split Bills — every split transaction with its members.
 * Following the Flutter screen (and hive_service semantics):
 * marking a member PAID credits their share into the member's paid
 * account (chosen here, defaulting to the transaction's account) as a
 * direct balance adjustment, NOT as a transaction; unmarking debits
 * it back out of that recorded account.
 */
public class SplitsActivity extends Activity {

    private Store store;
    private WalletDb db;
    private LinearLayout body;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        store = new Store(this);
        db = store.db();

        LinearLayout root = Ui.page(this, "Split Bills", new View.OnClickListener() {
            @Override public void onClick(View v) {
                android.content.Intent i = new android.content.Intent(
                        SplitsActivity.this, TxEditActivity.class);
                i.putExtra(TxEditActivity.EXTRA_START_SPLIT, true);
                startActivity(i);
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
        List<Transaction> splits = WalletLogic.splitTransactions(db);
        if (splits.isEmpty()) {
            TextView empty = Ui.tv(this, "No split bills yet.\n"
                    + "Split a group expense with + (expense → split) "
                    + "or the split switch in any expense.", 13, Ui.SECONDARY, false);
            empty.setLayoutParams(Ui.lpTop(this, 16));
            body.addView(empty);
            return;
        }

        // Summary totals — same three numbers as the Flutter screen.
        double outflow = 0, recovered = 0, pending = 0;
        for (Transaction t : splits) {
            outflow += t.amount;
            for (SplitMember s : t.splits) {
                if (s.isPaid && !"Me".equals(s.name)) recovered += s.amount;
                if (!s.isPaid) pending += s.amount;
            }
        }
        LinearLayout summary = Ui.card(this, Ui.CARD);
        summary.setLayoutParams(Ui.lpTop(this, 10));
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.addView(stat("Total Outflow", WalletLogic.formatINR(outflow), Ui.TEXT));
        row.addView(stat("Recovered", WalletLogic.formatINR(recovered), Ui.INCOME));
        row.addView(stat("Pending", WalletLogic.formatINR(pending), Ui.EXPENSE));
        summary.addView(row);
        body.addView(summary);

        for (Transaction t : splits) {
            body.addView(splitCard(t));
        }
    }

    private View stat(String label, String value, int color) {
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setLayoutParams(new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        TextView v = Ui.tv(this, value, 15, color, true);
        v.setGravity(Gravity.CENTER);
        col.addView(v);
        TextView l = Ui.tv(this, label, 10, Ui.SECONDARY, false);
        l.setGravity(Gravity.CENTER);
        col.addView(l);
        return col;
    }

    private View splitCard(final Transaction t) {
        LinearLayout card = Ui.card(this, Ui.CARD);
        card.setLayoutParams(Ui.lpTop(this, 10));

        Account acc = WalletLogic.accountById(db.accounts, t.accountId);
        LinearLayout head = new LinearLayout(this);
        head.setOrientation(LinearLayout.HORIZONTAL);
        head.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout titleCol = new LinearLayout(this);
        titleCol.setOrientation(LinearLayout.VERTICAL);
        titleCol.setLayoutParams(new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        titleCol.addView(Ui.tv(this,
                t.note != null && !t.note.isEmpty() ? t.note : "Shared expense",
                15, Ui.TEXT, true));
        titleCol.addView(Ui.tv(this, Ui.prettyDate(t.date)
                + (acc != null ? " • " + (acc.emoji != null ? acc.emoji + " " : "")
                        + acc.name : ""), 11, Ui.SECONDARY, false));
        head.addView(titleCol);
        TextView total = Ui.tv(this, WalletLogic.formatINR(t.amount), 16, Ui.TEXT, true);
        total.setGravity(Gravity.RIGHT);
        head.addView(total);
        card.addView(head);

        for (final SplitMember s : t.splits) {
            card.addView(memberRow(t, s));
        }

        TextView edit = Ui.chip(this, "✎ Edit bill", false, Ui.SECONDARY);
        edit.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                android.content.Intent i = new android.content.Intent(
                        SplitsActivity.this, TxEditActivity.class);
                i.putExtra(TxEditActivity.EXTRA_TX_ID, t.id);
                startActivity(i);
            }
        });
        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        actions.setGravity(Gravity.END);
        actions.setLayoutParams(Ui.lpTop(this, 6));
        actions.addView(edit);
        card.addView(actions);
        return card;
    }

    private View memberRow(final Transaction t, final SplitMember s) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setLayoutParams(Ui.lpTop(this, 6));
        row.setBackground(Ui.rounded(Ui.CARD_ALT, 10, this));
        row.setPadding(Ui.dp(this, 10), Ui.dp(this, 8), Ui.dp(this, 10), Ui.dp(this, 8));

        boolean isMe = "Me".equals(s.name);
        LinearLayout info = new LinearLayout(this);
        info.setOrientation(LinearLayout.VERTICAL);
        info.setLayoutParams(new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        info.addView(Ui.tv(this, s.name + (isMe ? "  (your share)" : ""), 13, Ui.TEXT, true));
        String status;
        if (isMe && s.isPaid) {
            status = "Your share — no recovery needed";
        } else if (s.isPaid) {
            Account into = WalletLogic.accountById(db.accounts, s.paidAccountId);
            status = "Paid" + (s.paidDate != null ? " on " + Ui.prettyDate(s.paidDate) : "")
                    + (into != null ? " → " + into.name : "");
        } else {
            status = "Yet to pay";
        }
        info.addView(Ui.tv(this, status, 11, s.isPaid ? Ui.INCOME : Ui.EXPENSE, false));
        row.addView(info);

        TextView amt = Ui.tv(this, WalletLogic.formatINR(s.amount), 13, Ui.TEXT, true);
        amt.setGravity(Gravity.RIGHT);
        row.addView(amt);

        if (!isMe) {
            TextView toggle = Ui.chip(this, s.isPaid ? "Undo" : "Collect",
                    !s.isPaid, s.isPaid ? Ui.SECONDARY : Ui.INCOME);
            toggle.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) {
                    if (s.isPaid) {
                        confirmUnmark(t, s);
                    } else {
                        showMarkPaidDialog(t, s);
                    }
                }
            });
            LinearLayout.LayoutParams tlp = (LinearLayout.LayoutParams) toggle.getLayoutParams();
            tlp.leftMargin = Ui.dp(this, 8);
            toggle.setLayoutParams(tlp);
            row.addView(toggle);
        }
        return row;
    }

    /** Flutter opens a dialog: account selector + date. Native keeps the
     *  account selector and uses today (paid date is stored; see report). */
    private void showMarkPaidDialog(final Transaction t, final SplitMember s) {
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(Ui.dp(this, 20), Ui.dp(this, 8), Ui.dp(this, 20), 0);
        box.addView(Ui.tv(this, s.name + " pays " + WalletLogic.formatINR(s.amount)
                + ". The money lands in:", 13, Ui.TEXT, false));

        final Spinner spinner = new Spinner(this);
        spinner.setBackground(Ui.rounded(Ui.CARD_ALT, 10, this));
        final List<Account> choices = new ArrayList<>(db.accounts);
        List<String> names = new ArrayList<>();
        int preselect = 0;
        for (int i = 0; i < choices.size(); i++) {
            Account a = choices.get(i);
            names.add((a.emoji != null ? a.emoji + " " : "") + a.name);
            if (a.id != null && a.id.equals(t.accountId)) preselect = i;
        }
        spinner.setAdapter(new ArrayAdapter<>(this,
                simpleSpinnerItem(), names));
        spinner.setSelection(preselect);
        box.addView(spinner);

        new AlertDialog.Builder(this)
                .setTitle("Mark as Paid")
                .setView(box)
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Received", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface d, int w) {
                        int pos = spinner.getSelectedItemPosition();
                        if (pos < 0 || pos >= choices.size()) return;
                        String acctId = choices.get(pos).id;
                        WalletLogic.markSplitMemberPaid(db, t, s.id,
                                LocalDate.now().toString() + "T00:00:00.000", acctId);
                        store.save();
                        Toast.makeText(SplitsActivity.this,
                                "Collected " + WalletLogic.formatINR(s.amount)
                                        + " from " + s.name + ".",
                                Toast.LENGTH_SHORT).show();
                        render();
                    }
                })
                .show();
    }

    private void confirmUnmark(final Transaction t, final SplitMember s) {
        Account into = WalletLogic.accountById(db.accounts, s.paidAccountId);
        new AlertDialog.Builder(this)
                .setTitle("Mark as unpaid?")
                .setMessage(s.name + " will owe " + WalletLogic.formatINR(s.amount)
                        + " again."
                        + (s.paidAccountId != null && into != null
                                ? " The collected amount is taken back out of "
                                        + into.name + "." : ""))
                .setNegativeButton("Cancel", null)
                .setPositiveButton("Mark Unpaid", new DialogInterface.OnClickListener() {
                    @Override public void onClick(DialogInterface d, int w) {
                        WalletLogic.unmarkSplitMemberPaid(db, t, s.id);
                        store.save();
                        render();
                    }
                })
                .show();
    }

    private int simpleSpinnerItem() {
        // Framework spinner row layout.
        return android.R.layout.simple_spinner_item;
    }
}
