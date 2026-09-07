import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import 'hive_service.dart';

class BackupPreviewInfo {
  final DateTime createdAt;
  final bool isEncrypted;
  final int accountsCount;
  final int categoriesCount;
  final int transactionsCount;
  final int plannedCount;
  final int debtsCount;
  final int templatesCount;
  final String userName;
  final String currency;
  final Map<String, dynamic> rawData;

  const BackupPreviewInfo({
    required this.createdAt,
    required this.isEncrypted,
    required this.accountsCount,
    required this.categoriesCount,
    required this.transactionsCount,
    required this.plannedCount,
    required this.debtsCount,
    required this.templatesCount,
    required this.userName,
    required this.currency,
    required this.rawData,
  });
}

class BackupService {
  static const String _magicHeaderEncrypted = 'smartwallet_encrypted';
  static const String _magicHeaderPlain = 'smartwallet_backup';
  static const int _currentVersion = 1;

  // ─── Export & Backup Creation ───────────────────────────────────────────────

  /// Generates the full database JSON map
  static Map<String, dynamic> createDatabaseSnapshot() {
    final user = HiveService.getUser();
    final accounts = HiveService.getAccounts();
    final categories = HiveService.getCategories();
    final transactions = HiveService.transactionsBox.values.toList();
    final planned = HiveService.getPlanned();
    final debts = HiveService.getDebtCredits();
    final templates = HiveService.templatesBox.values.toList();
    final cardOrder = HiveService.getAnalyticsCardOrder();

    return {
      'version': _currentVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'appName': 'Smart Wallet',
      'user': user != null
          ? {
              'id': user.id,
              'name': user.name,
              'email': user.email,
              'photoUrl': user.photoUrl,
              'baseCurrency': user.baseCurrency,
              'biometricEnabled': user.biometricEnabled,
              'isDarkMode': user.isDarkMode,
              'dailyReminderEnabled': user.dailyReminderEnabled,
              'dailyReminderHour': user.dailyReminderHour,
              'dailyReminderMinute': user.dailyReminderMinute,
              'plannedReminderEnabled': user.plannedReminderEnabled,
              'plannedReminderDaysBefore': user.plannedReminderDaysBefore,
            }
          : null,
      'accounts': accounts
          .map((a) => {
                'id': a.id,
                'name': a.name,
                'balance': a.balance,
                'currency': a.currency,
                'colorValue': a.colorValue,
                'emoji': a.emoji,
                'notes': a.notes,
                'isEnabledForCalc': a.isEnabledForCalc,
                'imagePath': a.imagePath,
                'cardType': a.cardType,
              })
          .toList(),
      'categories': categories
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'type': c.type,
                'colorValue': c.colorValue,
                'icon': c.icon,
                'imagePath': c.imagePath,
                'parentId': c.parentId,
              })
          .toList(),
      'transactions': transactions
          .map((t) => {
                'id': t.id,
                'type': t.type,
                'amount': t.amount,
                'accountId': t.accountId,
                'toAccountId': t.toAccountId,
                'categoryId': t.categoryId,
                'date': t.date.toIso8601String(),
                'note': t.note,
                'isSplit': t.isSplit,
                'splits': t.splits
                    ?.map((s) => {
                          'id': s.id,
                          'name': s.name,
                          'amount': s.amount,
                          'isPaid': s.isPaid,
                          'paidDate': s.paidDate?.toIso8601String(),
                          'paidAccountId': s.paidAccountId,
                        })
                    .toList(),
              })
          .toList(),
      'plannedPayments': planned
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'amount': p.amount,
                'accountId': p.accountId,
                'categoryId': p.categoryId,
                'isRecurring': p.isRecurring,
                'period': p.period,
                'nextDueDate': p.nextDueDate.toIso8601String(),
                'note': p.note,
                'endType': p.endType,
                'untilDate': p.untilDate?.toIso8601String(),
                'totalOccurrences': p.totalOccurrences,
                'currentOccurrence': p.currentOccurrence,
                'isCompleted': p.isCompleted,
                'lastPaidDate': p.lastPaidDate?.toIso8601String(),
                'isSplit': p.isSplit,
                'splits': p.splits
                    ?.map((s) => {
                          'id': s.id,
                          'name': s.name,
                          'amount': s.amount,
                          'isPaid': s.isPaid,
                          'paidDate': s.paidDate?.toIso8601String(),
                          'paidAccountId': s.paidAccountId,
                        })
                    .toList(),
              })
          .toList(),
      'debtCredits': debts
          .map((d) => {
                'id': d.id,
                'direction': d.direction,
                'personName': d.personName,
                'amount': d.amount,
                'accountId': d.accountId,
                'categoryId': d.categoryId,
                'startDate': d.startDate.toIso8601String(),
                'dueDate': d.dueDate?.toIso8601String(),
                'status': d.status,
                'notes': d.notes,
                'affectsAccount': d.affectsAccount,
                'transactionId': d.transactionId,
                'settlementTransactionId': d.settlementTransactionId,
              })
          .toList(),
      'templates': templates
          .map((tp) => {
                'id': tp.id,
                'name': tp.name,
                'type': tp.type,
                'amount': tp.amount,
                'accountId': tp.accountId,
                'categoryId': tp.categoryId,
                'note': tp.note,
              })
          .toList(),
      'analyticsCardOrder': cardOrder,
    };
  }

  /// Exports database to a `.smartwallet` or `.json` file with optional encryption
  static Future<File> createBackupFile({String? password, String format = 'smartwallet'}) async {
    final snapshot = createDatabaseSnapshot();
    final jsonString = jsonEncode(snapshot);
    final checksum = sha256.convert(utf8.encode(jsonString)).toString();

    final isJson = format.toLowerCase() == 'json';
    String fileContent;

    if (password != null && password.trim().isNotEmpty) {
      // Encrypt with password
      final encryptedData = _encryptPayload(jsonString, password.trim());
      final map = {
        'format': _magicHeaderEncrypted,
        'version': _currentVersion,
        'createdAt': DateTime.now().toIso8601String(),
        'checksum': checksum,
        ...encryptedData,
      };
      fileContent = isJson ? const JsonEncoder.withIndent('  ').convert(map) : jsonEncode(map);
    } else {
      // Plain backup container
      final map = {
        'format': _magicHeaderPlain,
        'version': _currentVersion,
        'createdAt': DateTime.now().toIso8601String(),
        'checksum': checksum,
        'data': snapshot,
        ...snapshot,
      };
      fileContent = isJson ? const JsonEncoder.withIndent('  ').convert(map) : jsonEncode(map);
    }

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = isJson ? 'json' : 'smartwallet';
    final fileName = 'smart_wallet_backup_$timestamp.$ext';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(fileContent);

    // Save last backup timestamp
    try {
      await HiveService.settingsBox.put('last_backup_time', DateTime.now().toIso8601String());
    } catch (_) {}

    return file;
  }

  /// 1-Tap Google Drive & Cloud Share
  static Future<void> shareBackup({String? password, String format = 'smartwallet'}) async {
    final file = await createBackupFile(password: password, format: format);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: format.toLowerCase() == 'json' ? 'Smart Wallet JSON Backup' : 'Smart Wallet Encrypted Backup',
        text: 'Smart Wallet Backup • ${DateTime.now().toString().split('.').first}',
      ),
    );
  }

  // ─── Import & Inspection ───────────────────────────────────────────────────

  /// Inspects a `.smartwallet` file to check whether it is encrypted or plain
  static Future<({bool isEncrypted, String createdAt})> inspectFile(File file) async {
    final raw = await file.readAsString();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final format = json['format']?.toString() ?? '';
    final isEncrypted = format == _magicHeaderEncrypted;
    final createdAt = json['createdAt']?.toString() ?? '';
    return (isEncrypted: isEncrypted, createdAt: createdAt);
  }

  /// Decodes and previews backup data (with password if encrypted)
  static Future<BackupPreviewInfo> loadBackupPreview(File file, {String? password}) async {
    final raw = await file.readAsString();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final format = json['format']?.toString() ?? '';

    Map<String, dynamic> data;

    if (format == _magicHeaderEncrypted) {
      if (password == null || password.trim().isEmpty) {
        throw const FormatException('Password is required for encrypted backup.');
      }
      final decrypted = _decryptPayload(json, password.trim());
      data = jsonDecode(decrypted) as Map<String, dynamic>;
    } else if (format == _magicHeaderPlain) {
      data = json['data'] as Map<String, dynamic>;
    } else if (json.containsKey('accounts') || json.containsKey('transactions')) {
      // Legacy or raw snapshot
      data = json;
    } else {
      throw const FormatException('Unrecognized Smart Wallet backup file format.');
    }

    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? data['createdAt']?.toString() ?? '') ??
        DateTime.now();
    final userMap = data['user'] as Map<String, dynamic>?;
    final accounts = data['accounts'] as List? ?? [];
    final categories = data['categories'] as List? ?? [];
    final transactions = data['transactions'] as List? ?? [];
    final planned = data['plannedPayments'] as List? ?? [];
    final debts = data['debtCredits'] as List? ?? [];
    final templates = data['templates'] as List? ?? [];

    return BackupPreviewInfo(
      createdAt: createdAt,
      isEncrypted: format == _magicHeaderEncrypted,
      accountsCount: accounts.length,
      categoriesCount: categories.length,
      transactionsCount: transactions.length,
      plannedCount: planned.length,
      debtsCount: debts.length,
      templatesCount: templates.length,
      userName: userMap?['name']?.toString() ?? 'User',
      currency: userMap?['baseCurrency']?.toString() ?? 'INR',
      rawData: data,
    );
  }

  /// Restores data from the validated backup payload into local Hive storage
  static Future<void> restoreDatabase(Map<String, dynamic> data, {bool replaceAll = true}) async {
    if (replaceAll) {
      await HiveService.accountsBox.clear();
      await HiveService.categoriesBox.clear();
      await HiveService.transactionsBox.clear();
      await HiveService.plannedBox.clear();
      await HiveService.debtCreditBox.clear();
      await HiveService.templatesBox.clear();
    }

    // 1. User Profile
    final userMap = data['user'] as Map<String, dynamic>?;
    if (userMap != null) {
      final user = UserProfile(
        id: userMap['id'] ?? 'guest_user',
        name: userMap['name'] ?? 'User',
        email: userMap['email'] ?? '',
        photoUrl: userMap['photoUrl'] ?? '',
        baseCurrency: userMap['baseCurrency'] ?? 'INR',
        biometricEnabled: userMap['biometricEnabled'] ?? false,
        isDarkMode: userMap['isDarkMode'] ?? true,
        dailyReminderEnabled: userMap['dailyReminderEnabled'] ?? true,
        dailyReminderHour: userMap['dailyReminderHour'] ?? 20,
        dailyReminderMinute: userMap['dailyReminderMinute'] ?? 0,
        plannedReminderEnabled: userMap['plannedReminderEnabled'] ?? true,
        plannedReminderDaysBefore: userMap['plannedReminderDaysBefore'] ?? 2,
      );
      await HiveService.saveUser(user);
    }

    // 2. Accounts
    final accountsList = data['accounts'] as List? ?? [];
    for (final raw in accountsList) {
      final a = raw as Map<String, dynamic>;
      final acc = Account(
        id: a['id'] ?? '',
        name: a['name'] ?? '',
        balance: (a['balance'] as num?)?.toDouble() ?? 0.0,
        currency: a['currency'] ?? 'INR',
        colorValue: a['colorValue'] ?? 0xFF6C63FF,
        emoji: a['emoji'] ?? '💳',
        notes: a['notes'] ?? '',
        isEnabledForCalc: a['isEnabledForCalc'] ?? true,
        imagePath: a['imagePath'],
        cardType: a['cardType'] as String? ?? 'Mastercard',
      );
      if (!replaceAll) {
        final exists = HiveService.accountsBox.values.any((x) => x.id == acc.id);
        if (!exists) await HiveService.accountsBox.add(acc);
      } else {
        await HiveService.accountsBox.add(acc);
      }
    }

    // 3. Categories
    final categoriesList = data['categories'] as List? ?? [];
    for (final raw in categoriesList) {
      final c = raw as Map<String, dynamic>;
      final cat = Category(
        id: c['id'] ?? '',
        name: c['name'] ?? '',
        type: c['type'] ?? 'expense',
        colorValue: c['colorValue'] ?? 0xFF6C63FF,
        icon: c['icon'] ?? '📦',
        imagePath: c['imagePath'],
        parentId: c['parentId'],
      );
      if (!replaceAll) {
        final exists = HiveService.categoriesBox.values.any((x) => x.id == cat.id);
        if (!exists) await HiveService.categoriesBox.add(cat);
      } else {
        await HiveService.categoriesBox.add(cat);
      }
    }

    // 4. Transactions
    final transactionsList = data['transactions'] as List? ?? [];
    for (final raw in transactionsList) {
      final t = raw as Map<String, dynamic>;
      final splitsRaw = t['splits'] as List?;
      final splits = splitsRaw
          ?.map((s) => SplitMember(
                id: s['id'] ?? '',
                name: s['name'] ?? '',
                amount: (s['amount'] as num?)?.toDouble() ?? 0.0,
                isPaid: s['isPaid'] ?? false,
                paidDate: s['paidDate'] != null ? DateTime.tryParse(s['paidDate']) : null,
                paidAccountId: s['paidAccountId'],
              ))
          .toList();

      final txn = Transaction(
        id: t['id'] ?? '',
        type: t['type'] ?? 'expense',
        amount: (t['amount'] as num?)?.toDouble() ?? 0.0,
        accountId: t['accountId'] ?? '',
        toAccountId: t['toAccountId'],
        categoryId: t['categoryId'],
        date: DateTime.tryParse(t['date']?.toString() ?? '') ?? DateTime.now(),
        note: t['note'] ?? '',
        isSplit: t['isSplit'] ?? false,
        splits: splits,
      );

      if (!replaceAll) {
        final exists = HiveService.transactionsBox.values.any((x) => x.id == txn.id);
        if (!exists) await HiveService.transactionsBox.add(txn);
      } else {
        await HiveService.transactionsBox.add(txn);
      }
    }

    // 5. Planned Payments
    final plannedList = data['plannedPayments'] as List? ?? [];
    for (final raw in plannedList) {
      final p = raw as Map<String, dynamic>;
      final splitsRaw = p['splits'] as List?;
      final splits = splitsRaw
          ?.map((s) => SplitMember(
                id: s['id'] ?? '',
                name: s['name'] ?? '',
                amount: (s['amount'] as num?)?.toDouble() ?? 0.0,
                isPaid: s['isPaid'] ?? false,
                paidDate: s['paidDate'] != null ? DateTime.tryParse(s['paidDate']) : null,
                paidAccountId: s['paidAccountId'],
              ))
          .toList();

      final pl = PlannedPayment(
        id: p['id'] ?? '',
        name: p['name'] ?? '',
        amount: (p['amount'] as num?)?.toDouble() ?? 0.0,
        accountId: p['accountId'] ?? '',
        categoryId: p['categoryId'],
        isRecurring: p['isRecurring'] ?? false,
        period: p['period'],
        nextDueDate: DateTime.tryParse(p['nextDueDate']?.toString() ?? '') ?? DateTime.now(),
        note: p['note'] ?? '',
        endType: p['endType'] ?? 'never',
        untilDate: p['untilDate'] != null ? DateTime.tryParse(p['untilDate']) : null,
        totalOccurrences: p['totalOccurrences'],
        currentOccurrence: p['currentOccurrence'] ?? 1,
        isCompleted: p['isCompleted'] ?? false,
        lastPaidDate: p['lastPaidDate'] != null ? DateTime.tryParse(p['lastPaidDate']) : null,
        isSplit: p['isSplit'] ?? false,
        splits: splits,
      );
      if (!replaceAll) {
        final exists = HiveService.plannedBox.values.any((x) => x.id == pl.id);
        if (!exists) await HiveService.plannedBox.add(pl);
      } else {
        await HiveService.plannedBox.add(pl);
      }
    }

    // 6. Debt / Credits
    final debtList = data['debtCredits'] as List? ?? [];
    for (final raw in debtList) {
      final d = raw as Map<String, dynamic>;
      final dc = DebtCredit(
        id: d['id'] ?? '',
        direction: d['direction'] ?? 'lent',
        personName: d['personName'] ?? '',
        amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
        accountId: d['accountId'] ?? '',
        categoryId: d['categoryId'],
        startDate: DateTime.tryParse(d['startDate']?.toString() ?? '') ?? DateTime.now(),
        dueDate: d['dueDate'] != null ? DateTime.tryParse(d['dueDate']) : null,
        status: d['status'] ?? 'active',
        notes: d['notes'] ?? '',
        affectsAccount: d['affectsAccount'] ?? true,
        transactionId: d['transactionId'],
        settlementTransactionId: d['settlementTransactionId'],
      );
      if (!replaceAll) {
        final exists = HiveService.debtCreditBox.values.any((x) => x.id == dc.id);
        if (!exists) await HiveService.debtCreditBox.add(dc);
      } else {
        await HiveService.debtCreditBox.add(dc);
      }
    }

    // 7. Templates
    final templateList = data['templates'] as List? ?? [];
    for (final raw in templateList) {
      final tp = raw as Map<String, dynamic>;
      final tpl = Template(
        id: tp['id'] ?? '',
        name: tp['name'] ?? '',
        type: tp['type'] ?? 'expense',
        amount: (tp['amount'] as num?)?.toDouble() ?? 0.0,
        accountId: tp['accountId'] ?? '',
        categoryId: tp['categoryId'],
        note: tp['note'] ?? '',
      );
      if (!replaceAll) {
        final exists = HiveService.templatesBox.values.any((x) => x.id == tpl.id);
        if (!exists) await HiveService.templatesBox.add(tpl);
      } else {
        await HiveService.templatesBox.add(tpl);
      }
    }

    // 8. Analytics Card Order
    final cardOrder = data['analyticsCardOrder'] as List?;
    if (cardOrder != null) {
      await HiveService.saveAnalyticsCardOrder(List<String>.from(cardOrder));
    }
  }

  // ─── Cryptographic Helpers ──────────────────────────────────────────────────

  /// Derives a 256-bit key from password + salt via PBKDF2/SHA-256 (10,000 iterations)
  static Uint8List _deriveKey(String password, Uint8List salt) {
    var key = utf8.encode(password);
    var hmac = Hmac(sha256, key);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    var result = List<int>.from(u);

    for (int i = 1; i < 10000; i++) {
      u = hmac.convert(u).bytes;
      for (int k = 0; k < result.length; k++) {
        result[k] ^= u[k];
      }
    }
    return Uint8List.fromList(result);
  }

  /// Encrypts plaintext string using PBKDF2 key derivation, keystream cipher, and HMAC-SHA256
  static Map<String, dynamic> _encryptPayload(String plainText, String password) {
    final rng = Random.secure();
    final salt = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
    final iv = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
    final key = _deriveKey(password, salt);

    final plainBytes = gzip.encode(utf8.encode(plainText));
    final cipherBytes = Uint8List(plainBytes.length);

    // Keystream generation using HMAC-SHA256 in counter mode
    var blockIndex = 0;
    var blockKey = Hmac(sha256, key).convert([...iv, ...utf8.encode('enc')]).bytes;

    for (int i = 0; i < plainBytes.length; i++) {
      if (i % 32 == 0) {
        blockKey = Hmac(sha256, key).convert([
          ...iv,
          (blockIndex >> 24) & 0xFF,
          (blockIndex >> 16) & 0xFF,
          (blockIndex >> 8) & 0xFF,
          blockIndex & 0xFF,
        ]).bytes;
        blockIndex++;
      }
      cipherBytes[i] = plainBytes[i] ^ blockKey[i % 32];
    }

    final mac = Hmac(sha256, key).convert([...salt, ...iv, ...cipherBytes]).bytes;

    return {
      'salt': base64Encode(salt),
      'iv': base64Encode(iv),
      'ciphertext': base64Encode(cipherBytes),
      'mac': base64Encode(mac),
    };
  }

  /// Decrypts ciphertext and verifies HMAC-SHA256
  static String _decryptPayload(Map<String, dynamic> json, String password) {
    final salt = base64Decode(json['salt'] as String);
    final iv = base64Decode(json['iv'] as String);
    final cipherBytes = base64Decode(json['ciphertext'] as String);
    final expectedMac = json['mac'] as String;

    final key = _deriveKey(password, salt);
    final actualMac = base64Encode(Hmac(sha256, key).convert([...salt, ...iv, ...cipherBytes]).bytes);

    if (actualMac != expectedMac) {
      throw const FormatException('Incorrect password or corrupted backup file.');
    }

    final plainBytes = Uint8List(cipherBytes.length);
    var blockIndex = 0;
    var blockKey = Hmac(sha256, key).convert([...iv, ...utf8.encode('enc')]).bytes;

    for (int i = 0; i < cipherBytes.length; i++) {
      if (i % 32 == 0) {
        blockKey = Hmac(sha256, key).convert([
          ...iv,
          (blockIndex >> 24) & 0xFF,
          (blockIndex >> 16) & 0xFF,
          (blockIndex >> 8) & 0xFF,
          blockIndex & 0xFF,
        ]).bytes;
        blockIndex++;
      }
      plainBytes[i] = cipherBytes[i] ^ blockKey[i % 32];
    }

    final decompressed = gzip.decode(plainBytes);
    return utf8.decode(decompressed);
  }
}
