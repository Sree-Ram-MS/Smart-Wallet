import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Supported card & account provider networks
class CardNetworkType {
  static const String mastercard = 'Mastercard';
  static const String visa = 'Visa';
  static const String rupay = 'RuPay';
  static const String wallet = 'Wallet';
  static const String other = 'Other';

  static const List<String> all = [
    rupay,
    visa,
    mastercard,
    wallet,
    other,
  ];
}

/// Renders authentic card network logo (RuPay, Visa, Mastercard, Wallet, Other)
/// using official high-resolution transparent asset icons.
class CardNetworkBadge extends StatelessWidget {
  final String cardType;
  final bool onCard;
  final double scale;

  const CardNetworkBadge({
    super.key,
    required this.cardType,
    this.onCard = true,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use white-text variants on credit card gradients or in dark mode
    final useWhiteVariant = onCard || isDark;

    switch (cardType.trim().toLowerCase()) {
      case 'rupay':
        return Image.asset(
          useWhiteVariant
              ? 'assets/icons/rupay_white.png'
              : 'assets/icons/rupay.png',
          height: 18 * scale,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _fallbackText('RuPay', scale, onCard, isDark),
        );

      case 'visa':
        return Image.asset(
          useWhiteVariant
              ? 'assets/icons/visa_white.png'
              : 'assets/icons/visa.png',
          height: 17 * scale,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _fallbackText('VISA', scale, onCard, isDark),
        );

      case 'mastercard':
        return Image.asset(
          useWhiteVariant
              ? 'assets/icons/mastercard_white.png'
              : 'assets/icons/mastercard.png',
          height: 24 * scale,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _fallbackText('Mastercard', scale, onCard, isDark),
        );

      case 'wallet':
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 7 * scale, vertical: 3 * scale),
          decoration: BoxDecoration(
            color: onCard
                ? Colors.white.withValues(alpha: 0.18)
                : AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(7 * scale),
            border: Border.all(
              color: onCard
                  ? Colors.white.withValues(alpha: 0.3)
                  : AppColors.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                size: 13 * scale,
                color: onCard ? Colors.white : AppColors.primary,
              ),
              SizedBox(width: 4 * scale),
              Text(
                'WALLET',
                style: TextStyle(
                  color: onCard ? Colors.white : AppColors.primary,
                  fontSize: 9.5 * scale,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        );

      case 'other':
      default:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 7 * scale, vertical: 3 * scale),
          decoration: BoxDecoration(
            color: onCard
                ? Colors.white.withValues(alpha: 0.18)
                : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(7 * scale),
            border: Border.all(
              color: onCard
                  ? Colors.white.withValues(alpha: 0.3)
                  : (isDark ? Colors.white24 : AppColors.lightBorder),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.credit_card_rounded,
                size: 13 * scale,
                color: onCard ? Colors.white : (isDark ? Colors.white70 : AppColors.lightTextSecondary),
              ),
              SizedBox(width: 4 * scale),
              Text(
                'OTHER',
                style: TextStyle(
                  color: onCard ? Colors.white : (isDark ? Colors.white70 : AppColors.lightTextSecondary),
                  fontSize: 9.5 * scale,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _fallbackText(String text, double scale, bool onCard, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        color: onCard ? Colors.white : (isDark ? Colors.white : AppColors.lightText),
        fontSize: 14 * scale,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
