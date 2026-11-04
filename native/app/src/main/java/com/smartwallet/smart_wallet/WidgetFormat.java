package com.smartwallet.smart_wallet;

import java.util.Locale;

/**
 * Pure formatting for the home-screen widget (Phase 5), split out of
 * QuickAddWidgetProvider so it is JVM-testable. Mirrors Flutter's
 * WidgetService._updateWidget: optional '-' + currency symbol +
 * absolute value with 2 decimals and NO grouping (toStringAsFixed).
 */
public final class WidgetFormat {

    private WidgetFormat() {}

    public static String formatBalance(double net, String currency) {
        String symbol = currencySymbol(currency);
        String sign = net < 0 ? "-" : "";
        return sign + symbol + String.format(Locale.US, "%.2f", Math.abs(net));
    }

    public static String currencySymbol(String currency) {
        if (currency == null) return "₹";
        switch (currency) {
            case "INR": return "₹";
            case "USD": return "$";
            case "EUR": return "€";
            case "GBP": return "£";
            case "AED": return "د.إ ";
            case "JPY": return "¥";
            default: return currency + " ";
        }
    }
}
