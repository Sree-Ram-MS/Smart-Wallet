package com.smartwallet.smart_wallet;

import android.animation.ValueAnimator;
import android.app.Activity;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.HorizontalScrollView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;

/**
 * Phase 1: single-Activity dashboard for Smart Wallet (native rebuild).
 *
 * All views are built in code (no layout XML, no libraries) to keep the
 * APK tiny, same pattern as Ram's Her Cycle app. The other sections are
 * present in the bottom nav but show a "later phase" placeholder.
 *
 * Colours match the Flutter app (lib/core/theme/app_colors.dart) exactly:
 * bg #0D0E1A, card #1E2138, cardAlt #252840, primary #6C63FF,
 * accent #00D9A3, income #00C896, expense #FF5C7A,
 * text #E8EAFF, secondary #8890B8.
 */
public class MainActivity extends Activity {

    private static final int BG = Color.rgb(0x0D, 0x0E, 0x1A);
    private static final int CARD = Color.rgb(0x1E, 0x21, 0x38);
    private static final int CARD_ALT = Color.rgb(0x25, 0x28, 0x40);
    private static final int PRIMARY = Color.rgb(0x6C, 0x63, 0xFF);
    private static final int ACCENT = Color.rgb(0x00, 0xD9, 0xA3);
    private static final int INCOME = Color.rgb(0x00, 0xC8, 0x96);
    private static final int EXPENSE = Color.rgb(0xFF, 0x5C, 0x7A);
    private static final int TRANSFER = Color.rgb(0x5B, 0xA4, 0xFF);
    private static final int TEXT = Color.rgb(0xE8, 0xEA, 0xFF);
    private static final int SECONDARY = Color.rgb(0x88, 0x90, 0xB8);
    private static final int MUTED = Color.rgb(0x55, 0x5D, 0x80);
    private static final int BORDER = Color.rgb(0x2E, 0x31, 0x50);

    private static final String[] NAV_ICONS = {
            "🏠", "🧾", "🗓️", "👥", "🤝", "📋", "📤", "⚙️"};
    private static final String[] NAV_LABELS = {
            "Dashboard", "Transactions", "Planned", "Split Bills",
            "Debts", "Templates", "Import/Export", "Settings"};

    private Store store;
    private WalletDb db;
    private FrameLayout container;
    private TextView[] navItems;
    private int selectedNav = 0;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(BG);
        getWindow().setNavigationBarColor(BG);

        store = new Store(this);
        db = store.db();

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(BG);

        container = new FrameLayout(this);
        container.setLayoutParams(new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        root.addView(container);

        root.addView(buildBottomNav());
        setContentView(root);
        showDashboard();
    }

    // ------------------------------------------------------------ bottom nav

    private View buildBottomNav() {
        HorizontalScrollView scroll = new HorizontalScrollView(this);
        scroll.setHorizontalScrollBarEnabled(false);
        scroll.setBackgroundColor(CARD);
        LinearLayout.LayoutParams slp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(62));
        scroll.setLayoutParams(slp);

        LinearLayout nav = new LinearLayout(this);
        nav.setOrientation(LinearLayout.HORIZONTAL);
        nav.setGravity(Gravity.CENTER_VERTICAL);
        nav.setPadding(dp(6), dp(4), dp(6), dp(4));
        scroll.addView(nav);

        navItems = new TextView[NAV_LABELS.length];
        for (int i = 0; i < NAV_LABELS.length; i++) {
            final int idx = i;
            TextView item = new TextView(this);
            item.setText(NAV_ICONS[i] + "\n" + NAV_LABELS[i]);
            item.setTextSize(10);
            item.setGravity(Gravity.CENTER);
            item.setPadding(dp(10), dp(4), dp(10), dp(4));
            item.setOnClickListener(new View.OnClickListener() {
                @Override public void onClick(View v) { onNavTapped(idx); }
            });
            navItems[i] = item;
            nav.addView(item);
        }
        styleNav();
        return scroll;
    }

    private void styleNav() {
        if (navItems == null) return;
        for (int i = 0; i < navItems.length; i++) {
            boolean sel = i == selectedNav;
            navItems[i].setTextColor(sel ? PRIMARY : SECONDARY);
            navItems[i].setTypeface(null, sel ? Typeface.BOLD : Typeface.NORMAL);
            GradientDrawable bg = new GradientDrawable();
            bg.setColor(sel ? CARD_ALT : Color.TRANSPARENT);
            bg.setCornerRadius(dp(12));
            navItems[i].setBackground(bg);
        }
    }

    private void onNavTapped(int idx) {
        selectedNav = idx;
        styleNav();
        if (idx == 0) {
            showDashboard();
        } else {
            showPlaceholder(NAV_LABELS[idx]);
        }
    }

    // ------------------------------------------------------------ placeholder

    private void showPlaceholder(String section) {
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setGravity(Gravity.CENTER);
        page.setPadding(dp(32), dp(32), dp(32), dp(32));
        page.setBackgroundColor(BG);

        TextView emoji = tv("🚧", 44, TEXT, false);
        emoji.setGravity(Gravity.CENTER);
        page.addView(emoji);

        TextView title = tv(section, 22, TEXT, true);
        title.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams tlp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        tlp.topMargin = dp(14);
        title.setLayoutParams(tlp);
        page.addView(title);

        TextView sub = tv("Coming in a later phase.\nPhase 1 ships the Dashboard on your wallet data — "
                + "this section is on the roadmap in the project README.", 13, SECONDARY, false);
        sub.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams slp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        slp.topMargin = dp(8);
        sub.setLayoutParams(slp);
        page.addView(sub);

        container.removeAllViews();
        container.addView(page);
        entrance(page, 0);
    }

    // ------------------------------------------------------------ dashboard

    private void showDashboard() {
        ScrollView scroll = new ScrollView(this);
        scroll.setBackgroundColor(BG);
        scroll.setFillViewport(true);

        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(dp(16), dp(18), dp(16), dp(20));
        scroll.addView(page);

        int anim = 0;

        // Header
        TextView title = tv("Smart Wallet", 26, TEXT, true);
        page.addView(title);
        String who = db.user != null && db.user.name != null && !db.user.name.isEmpty()
                ? db.user.name : "My Wallet";
        String currency = db.user != null && db.user.baseCurrency != null
                ? db.user.baseCurrency : "INR";
        TextView sub = tv(who + "  •  " + currency, 13, SECONDARY, false);
        page.addView(sub);
        entrance(title, anim); entrance(sub, anim); anim += 60;

        // Net wallet card (count-up)
        LinearLayout netCard = card(CARD_ALT);
        LinearLayout.LayoutParams nlp = lp();
        nlp.topMargin = dp(16);
        netCard.setLayoutParams(nlp);
        netCard.addView(tv("NET WALLET", 11, SECONDARY, true));
        final TextView netValue = tv("₹0", 34, TEXT, true);
        LinearLayout.LayoutParams vlp = lp(); vlp.topMargin = dp(4);
        netValue.setLayoutParams(vlp);
        netCard.addView(netValue);
        int enabled = 0;
        for (Account a : db.accounts) if (a.isEnabledForCalc) enabled++;
        netCard.addView(tv(enabled + " of " + db.accounts.size()
                + " accounts counted", 12, SECONDARY, false));
        page.addView(netCard);
        entrance(netCard, anim); anim += 60;

        final double net = WalletLogic.netWallet(db.accounts);
        ValueAnimator countUp = ValueAnimator.ofFloat(0f, (float) net);
        countUp.setDuration(900);
        countUp.addUpdateListener(new ValueAnimator.AnimatorUpdateListener() {
            @Override public void onAnimationUpdate(ValueAnimator animation) {
                float v = (Float) animation.getAnimatedValue();
                netValue.setText(WalletLogic.formatINR(v));
            }
        });
        countUp.start();

        // This-month income / expense.
        // Display month = the current month when it has activity; for the
        // seeded demo data (or a quiet month) fall back to the month of the
        // most recent transaction so the cards are never misleadingly empty,
        // and label it with that month's name.
        YearMonth displayMonth = displayMonth();
        String monthLabel = displayMonth.format(
                DateTimeFormatter.ofPattern("MMM yyyy", Locale.ENGLISH));
        boolean isCurrentMonth = displayMonth.equals(YearMonth.now());
        double income = WalletLogic.monthlyIncome(
                db.transactions, displayMonth.getYear(), displayMonth.getMonthValue());
        double expense = WalletLogic.monthlyExpense(
                db.transactions, displayMonth.getYear(), displayMonth.getMonthValue());

        TextView flowTitle = tv(isCurrentMonth ? "This month" : monthLabel, 16, TEXT, true);
        LinearLayout.LayoutParams ftp = lp(); ftp.topMargin = dp(20);
        flowTitle.setLayoutParams(ftp);
        page.addView(flowTitle);
        entrance(flowTitle, anim); anim += 60;

        LinearLayout flowRow = new LinearLayout(this);
        flowRow.setOrientation(LinearLayout.HORIZONTAL);
        LinearLayout.LayoutParams frp = lp(); frp.topMargin = dp(10);
        flowRow.setLayoutParams(frp);

        LinearLayout inCard = card(CARD);
        inCard.setLayoutParams(new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f));
        inCard.addView(tv("↓ Income" + (isCurrentMonth ? "" : " • " + monthLabel), 12, INCOME, true));
        TextView inVal = tv(WalletLogic.formatINR(income), 20, TEXT, true);
        LinearLayout.LayoutParams ivp = lp(); ivp.topMargin = dp(4); inVal.setLayoutParams(ivp);
        inCard.addView(inVal);
        flowRow.addView(inCard);

        View gap = new View(this);
        gap.setLayoutParams(new LinearLayout.LayoutParams(dp(10), 1));
        flowRow.addView(gap);

        LinearLayout exCard = card(CARD);
        LinearLayout.LayoutParams exLp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        exCard.setLayoutParams(exLp);
        exCard.addView(tv("↑ Expense" + (isCurrentMonth ? "" : " • " + monthLabel), 12, EXPENSE, true));
        TextView exVal = tv(WalletLogic.formatINR(expense), 20, TEXT, true);
        LinearLayout.LayoutParams evp = lp(); evp.topMargin = dp(4); exVal.setLayoutParams(evp);
        exCard.addView(exVal);
        flowRow.addView(exCard);
        page.addView(flowRow);
        entrance(flowRow, anim); anim += 60;

        // Accounts
        TextView accTitle = tv("Accounts", 16, TEXT, true);
        LinearLayout.LayoutParams atp = lp(); atp.topMargin = dp(22);
        accTitle.setLayoutParams(atp);
        page.addView(accTitle);
        entrance(accTitle, anim); anim += 60;

        HorizontalScrollView accScroll = new HorizontalScrollView(this);
        accScroll.setHorizontalScrollBarEnabled(false);
        LinearLayout.LayoutParams asp = lp(); asp.topMargin = dp(10);
        accScroll.setLayoutParams(asp);
        LinearLayout accRow = new LinearLayout(this);
        accRow.setOrientation(LinearLayout.HORIZONTAL);
        accScroll.addView(accRow);
        for (Account a : db.accounts) {
            accRow.addView(accountCard(a));
        }
        page.addView(accScroll);
        entrance(accScroll, anim); anim += 60;

        // Recent transactions
        TextView txTitle = tv("Recent transactions", 16, TEXT, true);
        LinearLayout.LayoutParams ttp = lp(); ttp.topMargin = dp(22);
        txTitle.setLayoutParams(ttp);
        page.addView(txTitle);
        entrance(txTitle, anim); anim += 60;

        LinearLayout txList = new LinearLayout(this);
        txList.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams txp = lp(); txp.topMargin = dp(8);
        txList.setLayoutParams(txp);
        List<Transaction> recent = WalletLogic.recentTransactions(db.transactions, 10);
        if (recent.isEmpty()) {
            TextView empty = tv("No transactions yet.", 13, SECONDARY, false);
            txList.addView(empty);
        } else {
            for (Transaction t : recent) {
                txList.addView(transactionRow(t));
            }
        }
        page.addView(txList);
        entrance(txList, anim);

        container.removeAllViews();
        container.addView(scroll);
    }

    /** Current month if it has any transaction, else the latest tx month. */
    private YearMonth displayMonth() {
        YearMonth now = YearMonth.now();
        for (Transaction t : db.transactions) {
            if (WalletLogic.yearOf(t.date) == now.getYear()
                    && WalletLogic.monthOf(t.date) == now.getMonthValue()) {
                return now;
            }
        }
        List<Transaction> recent = WalletLogic.recentTransactions(db.transactions, 1);
        if (!recent.isEmpty()) {
            int y = WalletLogic.yearOf(recent.get(0).date);
            int m = WalletLogic.monthOf(recent.get(0).date);
            if (y > 0 && m >= 1 && m <= 12) return YearMonth.of(y, m);
        }
        return now;
    }

    private View accountCard(Account a) {
        LinearLayout card = card(CARD);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(dp(228), ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.rightMargin = dp(12);
        card.setLayoutParams(lp);

        // colour strip
        View strip = new View(this);
        GradientDrawable stripBg = new GradientDrawable();
        stripBg.setColor(a.colorInt());
        stripBg.setCornerRadius(dp(3));
        strip.setBackground(stripBg);
        strip.setLayoutParams(new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(5)));
        card.addView(strip);

        TextView emoji = tv(a.emoji == null || a.emoji.isEmpty() ? "💳" : a.emoji, 26, TEXT, false);
        LinearLayout.LayoutParams elp = lp(); elp.topMargin = dp(10);
        emoji.setLayoutParams(elp);
        card.addView(emoji);

        TextView name = tv(a.name, 15, TEXT, true);
        LinearLayout.LayoutParams nlp = lp(); nlp.topMargin = dp(6);
        name.setLayoutParams(nlp);
        card.addView(name);

        TextView bal = tv(WalletLogic.formatINR(a.balance), 20,
                a.balance < 0 ? EXPENSE : TEXT, true);
        LinearLayout.LayoutParams blp = lp(); blp.topMargin = dp(2);
        bal.setLayoutParams(blp);
        card.addView(bal);

        if (a.notes != null && !a.notes.isEmpty()) {
            TextView notes = tv(a.notes, 12, SECONDARY, false);
            LinearLayout.LayoutParams ntp = lp(); ntp.topMargin = dp(4);
            notes.setLayoutParams(ntp);
            card.addView(notes);
        }
        if (!a.isEnabledForCalc) {
            TextView off = tv("Not counted in net wallet", 11, MUTED, false);
            LinearLayout.LayoutParams olp = lp(); olp.topMargin = dp(4);
            off.setLayoutParams(olp);
            card.addView(off);
        }
        return card;
    }

    private View transactionRow(Transaction t) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(12), dp(10), dp(12), dp(10));
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(CARD);
        bg.setCornerRadius(dp(14));
        bg.setStroke(1, BORDER);
        row.setBackground(bg);
        LinearLayout.LayoutParams rlp = lp(); rlp.bottomMargin = dp(8);
        row.setLayoutParams(rlp);

        Category cat = WalletLogic.categoryById(db.categories, t.categoryId);

        TextView icon = tv(cat != null && cat.icon != null && !cat.icon.isEmpty() ? cat.icon : "📦",
                20, TEXT, false);
        icon.setGravity(Gravity.CENTER);
        GradientDrawable circle = new GradientDrawable();
        circle.setShape(GradientDrawable.OVAL);
        circle.setColor(cat != null ? withAlpha(cat.colorInt(), 48) : CARD_ALT);
        icon.setBackground(circle);
        icon.setLayoutParams(new LinearLayout.LayoutParams(dp(44), dp(44)));
        row.addView(icon);

        LinearLayout middle = new LinearLayout(this);
        middle.setOrientation(LinearLayout.VERTICAL);
        LinearLayout.LayoutParams mlp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        mlp.leftMargin = dp(12);
        middle.setLayoutParams(mlp);
        String title = t.note != null && !t.note.isEmpty()
                ? t.note : (cat != null ? cat.name : "Transaction");
        if (title.length() > 38) title = title.substring(0, 37) + "…";
        middle.addView(tv(title, 14, TEXT, true));
        StringBuilder detail = new StringBuilder();
        if (cat != null) detail.append(cat.name);
        String dateLabel = prettyDate(t.date);
        if (!dateLabel.isEmpty()) {
            if (detail.length() > 0) detail.append("  •  ");
            detail.append(dateLabel);
        }
        if (t.isSplit) {
            if (detail.length() > 0) detail.append("  •  ");
            detail.append("Split");
        }
        middle.addView(tv(detail.toString(), 12, SECONDARY, false));
        row.addView(middle);

        int amountColor = "income".equals(t.type) ? INCOME
                : "expense".equals(t.type) ? EXPENSE : TRANSFER;
        TextView amount = tv(WalletLogic.formatSigned(t), 15, amountColor, true);
        amount.setGravity(Gravity.RIGHT);
        row.addView(amount);
        return row;
    }

    private String prettyDate(String iso) {
        if (iso == null || iso.length() < 10) return "";
        try {
            LocalDate d = LocalDate.parse(iso.substring(0, 10));
            return d.format(DateTimeFormatter.ofPattern("d MMM yyyy", Locale.ENGLISH));
        } catch (Exception e) {
            return iso.substring(0, 10);
        }
    }

    // ------------------------------------------------------------ helpers

    private LinearLayout card(int color) {
        LinearLayout card = new LinearLayout(this);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(dp(16), dp(14), dp(16), dp(14));
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(color);
        bg.setCornerRadius(dp(18));
        bg.setStroke(1, BORDER);
        card.setBackground(bg);
        return card;
    }

    private TextView tv(String text, float sizeSp, int color, boolean bold) {
        TextView t = new TextView(this);
        t.setText(text);
        t.setTextSize(sizeSp);
        t.setTextColor(color);
        if (bold) t.setTypeface(null, Typeface.BOLD);
        return t;
    }

    private LinearLayout.LayoutParams lp() {
        return new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
    }

    private void entrance(View v, long delayMs) {
        v.setAlpha(0f);
        v.setTranslationY(dp(18));
        v.animate().alpha(1f).translationY(0f)
                .setStartDelay(delayMs).setDuration(420).start();
    }

    private static int withAlpha(int color, int alpha) {
        return Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color));
    }

    private int dp(int value) {
        return (int) (value * getResources().getDisplayMetrics().density + 0.5f);
    }
}
