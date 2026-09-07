// Data models (manual, no codegen)
// All Hive typeIds are unique across the app.
import 'package:hive/hive.dart';

part 'models.g.dart';

// ─── UserProfile ────────────────────────────────────────────────────────────

@HiveType(typeId: 0)
class UserProfile extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) String email;
  @HiveField(3) String photoUrl;
  @HiveField(4) String baseCurrency;
  @HiveField(5) bool biometricEnabled;
  @HiveField(6) bool isDarkMode;
  @HiveField(7) bool dailyReminderEnabled;
  @HiveField(8) int dailyReminderHour;
  @HiveField(9) int dailyReminderMinute;
  @HiveField(10) bool plannedReminderEnabled;
  @HiveField(11) int plannedReminderDaysBefore;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl = '',
    this.baseCurrency = 'INR',
    this.biometricEnabled = false,
    this.isDarkMode = true,
    this.dailyReminderEnabled = true,
    this.dailyReminderHour = 20,
    this.dailyReminderMinute = 0,
    this.plannedReminderEnabled = true,
    this.plannedReminderDaysBefore = 2,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? photoUrl,
    String? baseCurrency,
    bool? biometricEnabled,
    bool? isDarkMode,
    bool? dailyReminderEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
    bool? plannedReminderEnabled,
    int? plannedReminderDaysBefore,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
      plannedReminderEnabled: plannedReminderEnabled ?? this.plannedReminderEnabled,
      plannedReminderDaysBefore: plannedReminderDaysBefore ?? this.plannedReminderDaysBefore,
    );
  }

  bool get isGuest => id == 'guest_user' || id == 'guest_001' || email.startsWith('guest@');
}

// ─── Account ────────────────────────────────────────────────────────────────

@HiveType(typeId: 1)
class Account extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) double balance;
  @HiveField(3) String currency;
  @HiveField(4) int colorValue;
  @HiveField(5) String emoji;
  @HiveField(6) String notes;
  @HiveField(7) bool isEnabledForCalc;
  @HiveField(8) String? imagePath;
  @HiveField(9) String cardType;

  Account({
    required this.id,
    required this.name,
    required this.balance,
    this.currency = 'INR',
    this.colorValue = 0xFF6C63FF,
    this.emoji = '💳',
    this.notes = '',
    this.isEnabledForCalc = true,
    this.imagePath,
    this.cardType = 'Mastercard',
  });
}

// ─── Category ───────────────────────────────────────────────────────────────

@HiveType(typeId: 2)
class Category extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) String type; // 'income' | 'expense'
  @HiveField(3) int colorValue;
  @HiveField(4) String icon; // emoji
  @HiveField(5) String? imagePath;
  @HiveField(6) String? parentId; // null = top-level category

  Category({
    required this.id,
    required this.name,
    required this.type,
    this.colorValue = 0xFF6C63FF,
    this.icon = '📦',
    this.imagePath,
    this.parentId,
  });
}

// ─── Transaction ─────────────────────────────────────────────────────────────

@HiveType(typeId: 3)
class Transaction extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String type; // 'income' | 'expense' | 'transfer'
  @HiveField(2) double amount;
  @HiveField(3) String accountId;
  @HiveField(4) String? toAccountId;
  @HiveField(5) String? categoryId;
  @HiveField(6) DateTime date;
  @HiveField(7) String note;
  @HiveField(8) bool isSplit;
  @HiveField(9) List<SplitMember>? splits;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    required this.date,
    this.note = '',
    this.isSplit = false,
    this.splits,
  });
}

// ─── PlannedPayment ──────────────────────────────────────────────────────────

@HiveType(typeId: 4)
class PlannedPayment extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) double amount;
  @HiveField(3) String accountId;
  @HiveField(4) String? categoryId;
  @HiveField(5) bool isRecurring;
  @HiveField(6) String? period; // 'daily'|'weekly'|'monthly'|'yearly'
  @HiveField(7) DateTime nextDueDate;
  @HiveField(8) String note;
  @HiveField(9) String endType; // 'never' | 'until_date' | 'occurrences'
  @HiveField(10) DateTime? untilDate;
  @HiveField(11) int? totalOccurrences;
  @HiveField(12) int currentOccurrence;
  @HiveField(13) bool isCompleted;
  @HiveField(14) DateTime? lastPaidDate;
  @HiveField(15) bool isSplit;
  @HiveField(16) List<SplitMember>? splits;

  PlannedPayment({
    required this.id,
    required this.name,
    required this.amount,
    required this.accountId,
    this.categoryId,
    this.isRecurring = false,
    this.period,
    required this.nextDueDate,
    this.note = '',
    this.endType = 'never',
    this.untilDate,
    this.totalOccurrences,
    this.currentOccurrence = 1,
    this.isCompleted = false,
    this.lastPaidDate,
    this.isSplit = false,
    this.splits,
  });
}

// ─── DebtCredit ──────────────────────────────────────────────────────────────

@HiveType(typeId: 5)
class DebtCredit extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String direction; // 'lent' | 'borrowed'
  @HiveField(2) String personName;
  @HiveField(3) double amount;
  @HiveField(4) String accountId;
  @HiveField(5) String? categoryId;
  @HiveField(6) DateTime startDate;
  @HiveField(7) DateTime? dueDate;
  @HiveField(8) String status; // 'active' | 'closed'
  @HiveField(9) String notes;
  @HiveField(10) bool affectsAccount; // false = opening balance / historical record only
  @HiveField(11) String? transactionId;
  @HiveField(12) String? settlementTransactionId;

  DebtCredit({
    required this.id,
    required this.direction,
    required this.personName,
    required this.amount,
    required this.accountId,
    this.categoryId,
    required this.startDate,
    this.dueDate,
    this.status = 'active',
    this.notes = '',
    this.affectsAccount = true,
    this.transactionId,
    this.settlementTransactionId,
  });
}

// ─── Template ────────────────────────────────────────────────────────────────

@HiveType(typeId: 6)
class Template extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) String type; // 'income' | 'expense' | 'transfer'
  @HiveField(3) double amount;
  @HiveField(4) String accountId;
  @HiveField(5) String? categoryId;
  @HiveField(6) String note;

  Template({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.accountId,
    this.categoryId,
    this.note = '',
  });
}

// ─── SplitMember ────────────────────────────────────────────────────────────

@HiveType(typeId: 7)
class SplitMember extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) double amount;
  @HiveField(3) bool isPaid;
  @HiveField(4) DateTime? paidDate;
  @HiveField(5) String? paidAccountId;

  SplitMember({
    required this.id,
    required this.name,
    required this.amount,
    this.isPaid = false,
    this.paidDate,
    this.paidAccountId,
  });

  SplitMember copyWith({
    String? id,
    String? name,
    double? amount,
    bool? isPaid,
    DateTime? paidDate,
    String? paidAccountId,
  }) {
    return SplitMember(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      isPaid: isPaid ?? this.isPaid,
      paidDate: paidDate ?? this.paidDate,
      paidAccountId: paidAccountId ?? this.paidAccountId,
    );
  }
}

