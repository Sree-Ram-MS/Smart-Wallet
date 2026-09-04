import 'package:flutter_test/flutter_test.dart';
import 'package:smart_wallet/core/utils/utils.dart';
import 'package:smart_wallet/models/models.dart';
import 'package:smart_wallet/services/hive_service.dart';
import 'package:smart_wallet/services/backup_service.dart';

void main() {
  group('CurrencyUtil tests', () {
    test('format currency correctly', () {
      expect(CurrencyUtil.format(1500, 'INR'), '₹1,500');
      expect(CurrencyUtil.format(99.5, 'USD'), '\$99.5');
    });

    test('symbol lookup', () {
      expect(CurrencyUtil.symbol('INR'), '₹');
      expect(CurrencyUtil.symbol('USD'), '\$');
      expect(CurrencyUtil.symbol('EUR'), '€');
    });
  });

  group('DateUtil tests', () {
    test('formatDate', () {
      final dt = DateTime(2026, 9, 1);
      expect(DateUtil.formatDate(dt), '1 Sep 2026');
    });

    test('isSameDay', () {
      final a = DateTime(2026, 9, 1, 10, 30);
      final b = DateTime(2026, 9, 1, 20, 0);
      final c = DateTime(2026, 9, 2, 10, 30);
      expect(DateUtil.isSameDay(a, b), isTrue);
      expect(DateUtil.isSameDay(a, c), isFalse);
    });
  });

  group('UserProfile model tests', () {
    test('copyWith updates isDarkMode and other fields', () {
      final u = UserProfile(
        id: 'u1',
        name: 'John',
        email: 'john@example.com',
        isDarkMode: true,
      );

      final toggled = u.copyWith(isDarkMode: !u.isDarkMode);
      expect(toggled.isDarkMode, isFalse);
      expect(toggled.name, 'John');
      expect(identical(u, toggled), isFalse);
    });

    test('isGuest returns true for guest user and false for authenticated', () {
      final guest1 = UserProfile(id: 'guest_user', name: 'Guest', email: 'guest@smartwallet.local');
      final guest2 = UserProfile(id: 'guest_001', name: 'Guest', email: 'guest@smartwallet.app');
      final auth = UserProfile(id: 'google_123', name: 'Alice', email: 'alice@gmail.com');

      expect(guest1.isGuest, isTrue);
      expect(guest2.isGuest, isTrue);
      expect(auth.isGuest, isFalse);
    });
  });

  group('Analytics card ordering tests', () {
    test('default cards list has 5 distinct cards', () {
      expect(HiveService.defaultAnalyticsCardOrder.length, 5);
      expect(HiveService.defaultAnalyticsCardOrder.toSet().length, 5);
      expect(HiveService.defaultAnalyticsCardOrder, contains('period_comparison'));
      expect(HiveService.defaultAnalyticsCardOrder, contains('cash_flow'));
      expect(HiveService.defaultAnalyticsCardOrder, contains('nature_of_spending'));
      expect(HiveService.defaultAnalyticsCardOrder, contains('income_expense_book'));
      expect(HiveService.defaultAnalyticsCardOrder, contains('net_balance'));
    });
  });

  group('BackupPreviewInfo model tests', () {
    test('constructs preview info correctly', () {
      final preview = BackupPreviewInfo(
        createdAt: DateTime(2026, 9, 1),
        isEncrypted: true,
        accountsCount: 3,
        categoriesCount: 12,
        transactionsCount: 150,
        plannedCount: 4,
        debtsCount: 2,
        templatesCount: 5,
        userName: 'John Doe',
        currency: 'INR',
        rawData: {'version': 1},
      );

      expect(preview.accountsCount, 3);
      expect(preview.isEncrypted, isTrue);
      expect(preview.transactionsCount, 150);
      expect(preview.userName, 'John Doe');
      expect(preview.currency, 'INR');
    });
  });
}

