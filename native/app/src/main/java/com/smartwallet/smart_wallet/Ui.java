package com.smartwallet.smart_wallet;

import android.app.Activity;
import android.content.Context;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.List;

/**
 * Shared theme + widget helpers for the Phase 2 screens, so every
 * Activity looks like the Phase 1 dashboard without duplicating code.
 * Colours match the Flutter app exactly (see MainActivity).
 */
public final class Ui {

    public static final int BG = Color.rgb(0x0D, 0x0E, 0x1A);
    public static final int CARD = Color.rgb(0x1E, 0x21, 0x38);
    public static final int CARD_ALT = Color.rgb(0x25, 0x28, 0x40);
    public static final int PRIMARY = Color.rgb(0x6C, 0x63, 0xFF);
    public static final int ACCENT = Color.rgb(0x00, 0xD9, 0xA3);
    public static final int INCOME = Color.rgb(0x00, 0xC8, 0x96);
    public static final int EXPENSE = Color.rgb(0xFF, 0x5C, 0x7A);
    public static final int TRANSFER = Color.rgb(0x5B, 0xA4, 0xFF);
    public static final int TEXT = Color.rgb(0xE8, 0xEA, 0xFF);
    public static final int SECONDARY = Color.rgb(0x88, 0x90, 0xB8);
    public static final int MUTED = Color.rgb(0x55, 0x5D, 0x80);
    public static final int BORDER = Color.rgb(0x2E, 0x31, 0x50);

    /** Account colour palette from the Flutter AppColors.accountColors. */
    public static final long[] ACCOUNT_COLORS = {
            0xFF6C63FFL, 0xFF00D9A3L, 0xFFFF5C7AL, 0xFFFFB84DL,
            0xFF5BA4FFL, 0xFFFF79C6L, 0xFF50FA7BL, 0xFFEF7C8EL};

    /** Chart/category palette from the Flutter AppColors.chartColors. */
    public static final long[] CATEGORY_COLORS = {
            0xFF6C63FFL, 0xFF00D9A3L, 0xFFFF5C7AL, 0xFFFFB84DL, 0xFF5BA4FFL,
            0xFFFF79C6L, 0xFF8BE9FDL, 0xFF50FA7BL, 0xFFFFD166L, 0xFFEF7C8EL};

    public static final String[] ACCOUNT_EMOJIS = {
            "💳", "🏦", "💰", "💵", "🐷", "📈", "🏠", "🚗", "✈️", "🎓", "💼", "🛒"};

    public static final String[] CATEGORY_EMOJIS = {
            "📦", "🍔", "🛒", "🏠", "🚗", "⛽", "⚡", "🌐", "💼", "💻",
            "🎬", "🏥", "🎓", "✈️", "🎁", "💡", "📱", "👕", "🐾", "💰"};

    public static final String[] CARD_TYPES = {
            "", "Mastercard", "Visa", "Rupay", "American Express",
            "Cash", "Bank", "UPI", "Other"};

    private Ui() {}

    public static int dp(Context c, int v) {
        return (int) (v * c.getResources().getDisplayMetrics().density + 0.5f);
    }

    public static TextView tv(Context c, String text, float sizeSp, int color, boolean bold) {
        TextView t = new TextView(c);
        t.setText(text);
        t.setTextSize(sizeSp);
        t.setTextColor(color);
        if (bold) t.setTypeface(null, Typeface.BOLD);
        return t;
    }

    public static GradientDrawable rounded(int color, int radiusDp, Context c) {
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(color);
        bg.setCornerRadius(dp(c, radiusDp));
        bg.setStroke(1, BORDER);
        return bg;
    }

    public static LinearLayout card(Context c, int color) {
        LinearLayout card = new LinearLayout(c);
        card.setOrientation(LinearLayout.VERTICAL);
        card.setPadding(dp(c, 16), dp(c, 14), dp(c, 16), dp(c, 14));
        card.setBackground(rounded(color, 18, c));
        return card;
    }

    public static LinearLayout.LayoutParams lp(Context c) {
        return new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
    }

    public static LinearLayout.LayoutParams lpTop(Context c, int topDp) {
        LinearLayout.LayoutParams p = lp(c);
        p.topMargin = dp(c, topDp);
        return p;
    }

    /** Page scaffold: header row (‹ back, title, optional + button) + scrollable body. */
    public static LinearLayout page(Activity act, String title, View.OnClickListener addAction) {
        act.getWindow().setStatusBarColor(BG);
        act.getWindow().setNavigationBarColor(BG);
        LinearLayout root = new LinearLayout(act);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(BG);

        LinearLayout header = new LinearLayout(act);
        header.setOrientation(LinearLayout.HORIZONTAL);
        header.setGravity(Gravity.CENTER_VERTICAL);
        header.setPadding(dp(act, 8), dp(act, 10), dp(act, 12), dp(act, 6));

        TextView back = tv(act, "‹", 30, TEXT, true);
        back.setGravity(Gravity.CENTER);
        back.setLayoutParams(new LinearLayout.LayoutParams(dp(act, 44), dp(act, 44)));
        back.setOnClickListener(new View.OnClickListener() {
            @Override public void onClick(View v) { act.finish(); }
        });
        header.addView(back);

        TextView titleTv = tv(act, title, 20, TEXT, true);
        LinearLayout.LayoutParams tlp = new LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        titleTv.setLayoutParams(tlp);
        header.addView(titleTv);

        if (addAction != null) {
            TextView add = tv(act, "+", 26, Color.WHITE, true);
            add.setGravity(Gravity.CENTER);
            GradientDrawable bg = new GradientDrawable();
            bg.setShape(GradientDrawable.OVAL);
            bg.setColor(PRIMARY);
            add.setBackground(bg);
            add.setLayoutParams(new LinearLayout.LayoutParams(dp(act, 40), dp(act, 40)));
            add.setOnClickListener(addAction);
            header.addView(add);
        }
        root.addView(header);
        return root;
    }

    public static android.widget.ScrollView scrollBody(Activity act, LinearLayout root) {
        android.widget.ScrollView scroll = new android.widget.ScrollView(act);
        scroll.setBackgroundColor(BG);
        scroll.setFillViewport(true);
        LinearLayout body = new LinearLayout(act);
        body.setOrientation(LinearLayout.VERTICAL);
        body.setPadding(dp(act, 16), dp(act, 8), dp(act, 16), dp(act, 24));
        scroll.addView(body);
        root.addView(scroll, new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f));
        return scroll;
    }

    public static TextView label(Context c, String text) {
        TextView t = tv(c, text, 12, SECONDARY, true);
        t.setLayoutParams(lpTop(c, 14));
        return t;
    }

    public static EditText input(Context c, String hint, String value) {
        EditText e = new EditText(c);
        e.setHint(hint);
        e.setText(value == null ? "" : value);
        e.setTextSize(15);
        e.setTextColor(TEXT);
        e.setHintTextColor(MUTED);
        e.setSingleLine(true);
        e.setPadding(dp(c, 12), dp(c, 10), dp(c, 12), dp(c, 10));
        e.setBackground(rounded(CARD, 12, c));
        e.setLayoutParams(lpTop(c, 6));
        return e;
    }

    public static Button primaryButton(Context c, String text, int color) {
        Button b = new Button(c);
        b.setText(text);
        b.setTextSize(15);
        b.setTextColor(Color.WHITE);
        b.setTypeface(null, Typeface.BOLD);
        b.setAllCaps(false);
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(color);
        bg.setCornerRadius(dp(c, 14));
        b.setBackground(bg);
        LinearLayout.LayoutParams p = lpTop(c, 18);
        p.height = dp(c, 50);
        b.setLayoutParams(p);
        return b;
    }

    public static Button dangerButton(Context c, String text) {
        Button b = new Button(c);
        b.setText(text);
        b.setTextSize(14);
        b.setTextColor(EXPENSE);
        b.setAllCaps(false);
        b.setBackground(rounded(CARD, 14, c));
        LinearLayout.LayoutParams p = lpTop(c, 12);
        p.height = dp(c, 46);
        b.setLayoutParams(p);
        return b;
    }

    /** Dark-themed spinner adapter (framework layouts are light-on-light otherwise). */
    public static ArrayAdapter<String> spinnerAdapter(final Context c, List<String> items) {
        ArrayAdapter<String> ad = new ArrayAdapter<String>(c,
                android.R.layout.simple_spinner_item, items) {
            @Override public View getView(int pos, View cv, ViewGroup parent) {
                TextView t = (TextView) super.getView(pos, cv, parent);
                styleItem(t);
                return t;
            }
            @Override public View getDropDownView(int pos, View cv, ViewGroup parent) {
                TextView t = (TextView) super.getDropDownView(pos, cv, parent);
                styleItem(t);
                t.setBackgroundColor(CARD_ALT);
                return t;
            }
            private void styleItem(TextView t) {
                t.setTextColor(TEXT);
                t.setTextSize(15);
                t.setPadding(dp(c, 12), dp(c, 10), dp(c, 12), dp(c, 10));
            }
        };
        ad.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        return ad;
    }

    /** A toggle chip button; selected gets the filled colour. */
    public static TextView chip(Context c, String text, boolean selected, int color) {
        TextView t = tv(c, text, 13, selected ? Color.WHITE : SECONDARY, selected);
        t.setGravity(Gravity.CENTER);
        t.setPadding(dp(c, 14), dp(c, 8), dp(c, 14), dp(c, 8));
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(selected ? color : CARD);
        bg.setCornerRadius(dp(c, 20));
        bg.setStroke(1, BORDER);
        t.setBackground(bg);
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        p.rightMargin = dp(c, 8);
        t.setLayoutParams(p);
        return t;
    }

    /** Colour swatch (rounded square) with an optional selection ring. */
    public static View swatch(final Context c, long colorValue, boolean selected,
                              View.OnClickListener onClick) {
        View v = new View(c);
        GradientDrawable bg = new GradientDrawable();
        bg.setColor((int) colorValue);
        bg.setCornerRadius(dp(c, 10));
        if (selected) bg.setStroke(dp(c, 3), Color.WHITE);
        v.setBackground(bg);
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(dp(c, 38), dp(c, 38));
        p.rightMargin = dp(c, 8);
        p.topMargin = dp(c, 6);
        v.setLayoutParams(p);
        v.setOnClickListener(onClick);
        return v;
    }

    public static int withAlpha(int color, int alpha) {
        return Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color));
    }

    public static void entrance(View v, Context c, long delayMs) {
        v.setAlpha(0f);
        v.setTranslationY(dp(c, 18));
        v.animate().alpha(1f).translationY(0f)
                .setStartDelay(delayMs).setDuration(420).start();
    }

    public static String prettyDate(String iso) {
        if (iso == null || iso.length() < 10) return "";
        try {
            java.time.LocalDate d = java.time.LocalDate.parse(iso.substring(0, 10));
            return d.format(java.time.format.DateTimeFormatter.ofPattern(
                    "d MMM yyyy", java.util.Locale.ENGLISH));
        } catch (Exception e) {
            return iso.substring(0, 10);
        }
    }
}
