import 'package:intl/intl.dart';

class CurrencyUtil {
  static const Map<String, String> symbols = {
    'INR': '₹',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'AUD': 'A\$',
    'CAD': 'C\$',
    'CHF': 'Fr',
    'CNY': '¥',
    'SGD': 'S\$',
    'AED': 'د.إ',
  };

  // Static FX rates relative to INR (1 INR = x unit)
  static const Map<String, double> _ratesFromINR = {
    'INR': 1.0,
    'USD': 0.012,
    'EUR': 0.011,
    'GBP': 0.0095,
    'JPY': 1.78,
    'AUD': 0.018,
    'CAD': 0.016,
    'CHF': 0.011,
    'CNY': 0.087,
    'SGD': 0.016,
    'AED': 0.044,
  };

  static String symbol(String currency) => symbols[currency] ?? currency;

  static String format(double amount, String currency) {
    final sym = symbol(currency);
    final formatted = NumberFormat('#,##0.##').format(amount.abs());
    final sign = amount < 0 ? '-' : '';
    return '$sign$sym$formatted';
  }

  static String formatSigned(double amount, String currency, {bool showPositive = false}) {
    final sym = symbol(currency);
    final formatted = NumberFormat('#,##0.##').format(amount.abs());
    if (amount < 0) return '-$sym$formatted';
    if (showPositive && amount > 0) return '+$sym$formatted';
    return '$sym$formatted';
  }

  static double convert(double amount, String fromCurrency, String toCurrency) {
    if (fromCurrency == toCurrency) return amount;
    final fromRate = _ratesFromINR[fromCurrency] ?? 1.0;
    final toRate = _ratesFromINR[toCurrency] ?? 1.0;
    // Convert to INR first, then to target
    final inINR = amount / fromRate;
    return inINR * toRate;
  }

  static List<String> get supportedCurrencies => symbols.keys.toList();
}

class DateUtil {
  static String formatDate(DateTime dt) => DateFormat('d MMM yyyy').format(dt);
  static String formatDateTime(DateTime dt) => DateFormat('d MMM yyyy, h:mm a').format(dt);
  static String formatMonthYear(DateTime dt) => DateFormat('MMM yyyy').format(dt);
  static String formatShort(DateTime dt) => DateFormat('d MMM').format(dt);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return formatDate(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
