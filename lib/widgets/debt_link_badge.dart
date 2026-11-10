import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../models/models.dart';

/// Small "Lent" / "Borrowed" chip shown on transactions that belong to a
/// Lent/Borrowed record.
class DebtLinkBadge extends StatelessWidget {
  final DebtCredit debt;
  const DebtLinkBadge({super.key, required this.debt});

  @override
  Widget build(BuildContext context) {
    final isLent = debt.direction == 'lent';
    const color = AppColors.savings;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isLent ? Icons.call_made_rounded : Icons.call_received_rounded, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            isLent ? 'Lent' : 'Borrowed',
            style: const TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
