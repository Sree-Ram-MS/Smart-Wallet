package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.text.Editable;
import android.text.InputType;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.View;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Supplier;

/**
 * Phase 3: the split-members editor, shared by TxEditActivity and
 * PlannedEditActivity. One row per member (name + share + remove),
 * "+ Add person" and "Split Equally" actions, and a live shares-total
 * line so the sum-to-total rule is visible while editing.
 *
 * Member semantics follow the Flutter sheets as adapted in
 * WalletLogic.splitValidationError: the list INCLUDES "Me" (as the
 * shipped seed data does), equal split treats Me as one person (the
 * Flutter sheets' "friends + 1" rule), and the shares must sum to the
 * total. Paid state (isPaid / paidDate / paidAccountId) rides along in
 * each row's meta and is preserved by collect(); a caller editing a
 * planned payment passes forceUnpaid=true because Flutter's planned
 * editor always saves members unpaid.
 */
public final class SplitEditor {

    private static final class Row {
        SplitMember meta; // may be null for a brand-new row
        EditText name;
        EditText amount;
        LinearLayout view;
    }

    private final Activity act;
    private final Supplier<Double> totalSupplier;
    private final List<Row> rows = new ArrayList<>();
    private final LinearLayout container;
    private final LinearLayout rowsBox;
    private final TextView sumLabel;

    public SplitEditor(Activity act, Supplier<Double> totalSupplier) {
        this.act = act;
        this.totalSupplier = totalSupplier;
        container = new LinearLayout(act);
        rowsBox = new LinearLayout(act);
        container.setOrientation(LinearLayout.VERTICAL);
        rowsBox.setOrientation(LinearLayout.VERTICAL);
        container.addView(rowsBox);

        LinearLayout controls = new LinearLayout(act);
        controls.setOrientation(LinearLayout.HORIZONTAL);
        controls.setLayoutParams(Ui.lpTop(act, 8));
        TextView add = Ui.chip(act, "＋ Add person", false, Ui.PRIMARY);
        add.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                addRow(null, "Friend " + (rows.size()), 0);
            }
        });
        controls.addView(add);
        TextView equal = Ui.chip(act, "⚖ Split Equally", false, Ui.ACCENT);
        equal.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { splitEqually(); }
        });
        controls.addView(equal);
        container.addView(controls);

        sumLabel = Ui.tv(act, "", 12, Ui.SECONDARY, false);
        sumLabel.setLayoutParams(Ui.lpTop(act, 8));
        container.addView(sumLabel);
    }

    public View view() {
        return container;
    }

    public int size() {
        return rows.size();
    }

    /** Add a row. meta carries id/paid state for existing members (may be null). */
    public void addRow(SplitMember meta, String name, double amount) {
        final Row row = new Row();
        row.meta = meta;

        LinearLayout line = new LinearLayout(act);
        line.setOrientation(LinearLayout.HORIZONTAL);
        line.setGravity(Gravity.CENTER_VERTICAL);
        line.setLayoutParams(Ui.lpTop(act, 6));

        row.name = Ui.input(act, "Name", name == null ? "" : name);
        LinearLayout.LayoutParams nlp = new LinearLayout.LayoutParams(
                0, android.view.ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        row.name.setLayoutParams(nlp);
        line.addView(row.name);

        row.amount = Ui.input(act, "Share ₹", amount > 0 ? trimNum(amount) : "");
        row.amount.setInputType(InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_FLAG_DECIMAL);
        LinearLayout.LayoutParams alp = new LinearLayout.LayoutParams(
                Ui.dp(act, 104), android.view.ViewGroup.LayoutParams.WRAP_CONTENT);
        alp.leftMargin = Ui.dp(act, 8);
        row.amount.setLayoutParams(alp);
        line.addView(row.amount);

        if (meta != null && meta.isPaid) {
            TextView paid = Ui.tv(act, "✓paid", 11, Ui.INCOME, true);
            LinearLayout.LayoutParams plp = new LinearLayout.LayoutParams(
                    android.view.ViewGroup.LayoutParams.WRAP_CONTENT,
                    android.view.ViewGroup.LayoutParams.WRAP_CONTENT);
            plp.leftMargin = Ui.dp(act, 6);
            paid.setLayoutParams(plp);
            line.addView(paid);
        }

        TextView remove = Ui.tv(act, "✕", 16, Ui.EXPENSE, true);
        remove.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams rlp = new LinearLayout.LayoutParams(
                Ui.dp(act, 36), Ui.dp(act, 36));
        remove.setLayoutParams(rlp);
        remove.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) {
                rows.remove(row);
                rowsBox.removeView(row.view);
                updateSum();
            }
        });
        line.addView(remove);

        TextWatcher watcher = new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int a, int b, int c) {}
            @Override public void onTextChanged(CharSequence s, int a, int b, int c) {}
            @Override public void afterTextChanged(Editable s) { updateSum(); }
        };
        row.name.addTextChangedListener(watcher);
        row.amount.addTextChangedListener(watcher);

        row.view = line;
        rows.add(row);
        rowsBox.addView(line);
        updateSum();
    }

    /** Seed the editor for a brand-new split: "Me" (my share, settled by
     *  definition) plus one friend — then split equally. */
    public void seedNew() {
        SplitMember me = new SplitMember();
        me.id = "sp_" + System.currentTimeMillis() + "_me";
        me.name = "Me";
        me.isPaid = true;
        addRow(me, "Me", 0);
        addRow(null, "Friend 1", 0);
        splitEqually();
    }

    /** Distribute the unpaid shares evenly (Flutter skips paid entries):
     *  paid members keep their share; the rest of the total is split
     *  equally across the unpaid rows, last row takes the remainder. */
    public void splitEqually() {
        double total = totalSupplier.get();
        if (total <= 0 || rows.isEmpty()) return;
        double paidSum = 0;
        List<Row> unpaid = new ArrayList<>();
        for (Row r : rows) {
            if (r.meta != null && r.meta.isPaid) {
                paidSum += parseAmount(r.amount);
            } else {
                unpaid.add(r);
            }
        }
        if (unpaid.isEmpty()) return;
        List<Double> shares = WalletLogic.equalSplit(total - paidSum, unpaid.size());
        for (int i = 0; i < unpaid.size(); i++) {
            unpaid.get(i).amount.setText(trimNum(shares.get(i)));
        }
        updateSum();
    }

    /** Build the member list from the inputs. Paid state comes from
     *  each row's meta unless forceUnpaid is set (planned payments). */
    public List<SplitMember> collect(boolean forceUnpaid) {
        List<SplitMember> out = new ArrayList<>();
        long stamp = System.currentTimeMillis();
        int i = 0;
        for (Row r : rows) {
            SplitMember s = new SplitMember();
            i++;
            s.id = r.meta != null && r.meta.id != null ? r.meta.id : "sp_" + stamp + "_" + i;
            s.name = r.name.getText().toString().trim();
            s.amount = parseAmount(r.amount);
            if (!forceUnpaid && r.meta != null && r.meta.isPaid) {
                s.isPaid = true;
                s.paidDate = r.meta.paidDate;
                s.paidAccountId = r.meta.paidAccountId;
            } else {
                s.isPaid = false;
            }
            out.add(s);
        }
        return out;
    }

    public void updateSum() {
        double total = totalSupplier.get();
        double sum = 0;
        for (Row r : rows) sum += parseAmount(r.amount);
        if (rows.isEmpty()) {
            sumLabel.setText("No one added yet — the split needs at least one person.");
            sumLabel.setTextColor(Ui.SECONDARY);
            return;
        }
        boolean ok = total > 0 && Math.abs(sum - total) <= 0.01;
        sumLabel.setText("Shares total " + WalletLogic.formatINR(sum)
                + (total > 0 ? " of " + WalletLogic.formatINR(total) : "")
                + (ok ? " ✓" : ""));
        sumLabel.setTextColor(ok ? Ui.INCOME : Ui.SECONDARY);
    }

    static double parseAmount(EditText e) {
        try {
            return Double.parseDouble(e.getText().toString().trim());
        } catch (Exception ex) {
            return 0;
        }
    }

    static String trimNum(double v) {
        if (v == Math.floor(v) && !Double.isInfinite(v)) {
            return Long.toString(Math.round(v));
        }
        return String.format(java.util.Locale.US, "%.2f", v);
    }
}
