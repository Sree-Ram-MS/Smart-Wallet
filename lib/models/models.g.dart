// HAND-WRITTEN Hive adapters (no build_runner needed)
// ignore_for_file: type=lint
part of 'models.dart';

// ─── UserProfile Adapter ─────────────────────────────────────────────────────
class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override final int typeId = 0;
  @override UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return UserProfile(
      id: fields[0] as String,
      name: fields[1] as String,
      email: fields[2] as String,
      photoUrl: fields[3] as String? ?? '',
      baseCurrency: fields[4] as String? ?? 'INR',
      biometricEnabled: fields[5] as bool? ?? false,
      isDarkMode: fields[6] as bool? ?? true,
      dailyReminderEnabled: fields[7] as bool? ?? true,
      dailyReminderHour: fields[8] as int? ?? 20,
      dailyReminderMinute: fields[9] as int? ?? 0,
      plannedReminderEnabled: fields[10] as bool? ?? true,
      plannedReminderDaysBefore: fields[11] as int? ?? 2,
    );
  }
  @override void write(BinaryWriter writer, UserProfile obj) {
    writer.writeByte(12);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.name);
    writer.writeByte(2); writer.write(obj.email);
    writer.writeByte(3); writer.write(obj.photoUrl);
    writer.writeByte(4); writer.write(obj.baseCurrency);
    writer.writeByte(5); writer.write(obj.biometricEnabled);
    writer.writeByte(6); writer.write(obj.isDarkMode);
    writer.writeByte(7); writer.write(obj.dailyReminderEnabled);
    writer.writeByte(8); writer.write(obj.dailyReminderHour);
    writer.writeByte(9); writer.write(obj.dailyReminderMinute);
    writer.writeByte(10); writer.write(obj.plannedReminderEnabled);
    writer.writeByte(11); writer.write(obj.plannedReminderDaysBefore);
  }
}

// ─── Account Adapter ─────────────────────────────────────────────────────────
class AccountAdapter extends TypeAdapter<Account> {
  @override final int typeId = 1;
  @override Account read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return Account(
      id: fields[0] as String,
      name: fields[1] as String,
      balance: (fields[2] as num).toDouble(),
      currency: fields[3] as String? ?? 'INR',
      colorValue: fields[4] as int? ?? 0xFF6C63FF,
      emoji: fields[5] as String? ?? '💳',
      notes: fields[6] as String? ?? '',
      isEnabledForCalc: fields[7] as bool? ?? true,
      imagePath: fields[8] as String?,
    );
  }
  @override void write(BinaryWriter writer, Account obj) {
    writer.writeByte(9);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.name);
    writer.writeByte(2); writer.write(obj.balance);
    writer.writeByte(3); writer.write(obj.currency);
    writer.writeByte(4); writer.write(obj.colorValue);
    writer.writeByte(5); writer.write(obj.emoji);
    writer.writeByte(6); writer.write(obj.notes);
    writer.writeByte(7); writer.write(obj.isEnabledForCalc);
    writer.writeByte(8); writer.write(obj.imagePath);
  }
}

// ─── Category Adapter ────────────────────────────────────────────────────────
class CategoryAdapter extends TypeAdapter<Category> {
  @override final int typeId = 2;
  @override Category read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return Category(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String,
      colorValue: fields[3] as int? ?? 0xFF6C63FF,
      icon: fields[4] as String? ?? '📦',
      imagePath: fields[5] as String?,
      parentId: fields[6] as String?,
    );
  }
  @override void write(BinaryWriter writer, Category obj) {
    writer.writeByte(7);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.name);
    writer.writeByte(2); writer.write(obj.type);
    writer.writeByte(3); writer.write(obj.colorValue);
    writer.writeByte(4); writer.write(obj.icon);
    writer.writeByte(5); writer.write(obj.imagePath);
    writer.writeByte(6); writer.write(obj.parentId);
  }
}

// ─── Transaction Adapter ─────────────────────────────────────────────────────
class TransactionAdapter extends TypeAdapter<Transaction> {
  @override final int typeId = 3;
  @override Transaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return Transaction(
      id: fields[0] as String,
      type: fields[1] as String,
      amount: (fields[2] as num).toDouble(),
      accountId: fields[3] as String,
      toAccountId: fields[4] as String?,
      categoryId: fields[5] as String?,
      date: fields[6] as DateTime,
      note: fields[7] as String? ?? '',
      isSplit: fields[8] as bool? ?? false,
      splits: (fields[9] as List?)?.cast<SplitMember>(),
    );
  }
  @override void write(BinaryWriter writer, Transaction obj) {
    writer.writeByte(10);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.type);
    writer.writeByte(2); writer.write(obj.amount);
    writer.writeByte(3); writer.write(obj.accountId);
    writer.writeByte(4); writer.write(obj.toAccountId);
    writer.writeByte(5); writer.write(obj.categoryId);
    writer.writeByte(6); writer.write(obj.date);
    writer.writeByte(7); writer.write(obj.note);
    writer.writeByte(8); writer.write(obj.isSplit);
    writer.writeByte(9); writer.write(obj.splits);
  }
}

// ─── PlannedPayment Adapter ──────────────────────────────────────────────────
class PlannedPaymentAdapter extends TypeAdapter<PlannedPayment> {
  @override final int typeId = 4;
  @override PlannedPayment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return PlannedPayment(
      id: fields[0] as String,
      name: fields[1] as String,
      amount: (fields[2] as num).toDouble(),
      accountId: fields[3] as String,
      categoryId: fields[4] as String?,
      isRecurring: fields[5] as bool? ?? false,
      period: fields[6] as String?,
      nextDueDate: fields[7] as DateTime,
      note: fields[8] as String? ?? '',
      endType: fields[9] as String? ?? 'never',
      untilDate: fields[10] as DateTime?,
      totalOccurrences: fields[11] as int?,
      currentOccurrence: fields[12] as int? ?? 1,
      isCompleted: fields[13] as bool? ?? false,
      lastPaidDate: fields[14] as DateTime?,
    );
  }
  @override void write(BinaryWriter writer, PlannedPayment obj) {
    writer.writeByte(15);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.name);
    writer.writeByte(2); writer.write(obj.amount);
    writer.writeByte(3); writer.write(obj.accountId);
    writer.writeByte(4); writer.write(obj.categoryId);
    writer.writeByte(5); writer.write(obj.isRecurring);
    writer.writeByte(6); writer.write(obj.period);
    writer.writeByte(7); writer.write(obj.nextDueDate);
    writer.writeByte(8); writer.write(obj.note);
    writer.writeByte(9); writer.write(obj.endType);
    writer.writeByte(10); writer.write(obj.untilDate);
    writer.writeByte(11); writer.write(obj.totalOccurrences);
    writer.writeByte(12); writer.write(obj.currentOccurrence);
    writer.writeByte(13); writer.write(obj.isCompleted);
    writer.writeByte(14); writer.write(obj.lastPaidDate);
  }
}

// ─── DebtCredit Adapter ──────────────────────────────────────────────────────
class DebtCreditAdapter extends TypeAdapter<DebtCredit> {
  @override final int typeId = 5;
  @override DebtCredit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return DebtCredit(
      id: fields[0] as String,
      direction: fields[1] as String,
      personName: fields[2] as String,
      amount: (fields[3] as num).toDouble(),
      accountId: fields[4] as String,
      categoryId: fields[5] as String?,
      startDate: fields[6] as DateTime,
      dueDate: fields[7] as DateTime?,
      status: fields[8] as String? ?? 'active',
      notes: fields[9] as String? ?? '',
      affectsAccount: fields[10] as bool? ?? true,
    );
  }
  @override void write(BinaryWriter writer, DebtCredit obj) {
    writer.writeByte(11);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.direction);
    writer.writeByte(2); writer.write(obj.personName);
    writer.writeByte(3); writer.write(obj.amount);
    writer.writeByte(4); writer.write(obj.accountId);
    writer.writeByte(5); writer.write(obj.categoryId);
    writer.writeByte(6); writer.write(obj.startDate);
    writer.writeByte(7); writer.write(obj.dueDate);
    writer.writeByte(8); writer.write(obj.status);
    writer.writeByte(9); writer.write(obj.notes);
    writer.writeByte(10); writer.write(obj.affectsAccount);
  }
}

// ─── Template Adapter ────────────────────────────────────────────────────────
class TemplateAdapter extends TypeAdapter<Template> {
  @override final int typeId = 6;
  @override Template read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return Template(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as String,
      amount: (fields[3] as num).toDouble(),
      accountId: fields[4] as String,
      categoryId: fields[5] as String?,
      note: fields[6] as String? ?? '',
    );
  }
  @override void write(BinaryWriter writer, Template obj) {
    writer.writeByte(7);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.name);
    writer.writeByte(2); writer.write(obj.type);
    writer.writeByte(3); writer.write(obj.amount);
    writer.writeByte(4); writer.write(obj.accountId);
    writer.writeByte(5); writer.write(obj.categoryId);
    writer.writeByte(6); writer.write(obj.note);
  }
}

// ─── SplitMember Adapter ─────────────────────────────────────────────────────
class SplitMemberAdapter extends TypeAdapter<SplitMember> {
  @override final int typeId = 7;
  @override SplitMember read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return SplitMember(
      id: fields[0] as String,
      name: fields[1] as String,
      amount: (fields[2] as num).toDouble(),
      isPaid: fields[3] as bool? ?? false,
      paidDate: fields[4] as DateTime?,
      paidAccountId: fields[5] as String?,
    );
  }
  @override void write(BinaryWriter writer, SplitMember obj) {
    writer.writeByte(6);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.name);
    writer.writeByte(2); writer.write(obj.amount);
    writer.writeByte(3); writer.write(obj.isPaid);
    writer.writeByte(4); writer.write(obj.paidDate);
    writer.writeByte(5); writer.write(obj.paidAccountId);
  }
}

