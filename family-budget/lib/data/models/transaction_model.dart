// lib/data/models/transaction_model.dart

import 'dart:math';

import 'package:family_budget/data/models/card_model.dart';

// ---------------------------------------------------------------------------
// Модель транзакції
// ---------------------------------------------------------------------------

/// Незмінна модель транзакції, яка відповідає таблиці `transactions`.
///
/// Від'ємне значення [amount] означає витрату, додатне — дохід або поповнення.
/// Поле [amountUah] завжди містить еквівалент у гривнях.
class TransactionModel {
  // -------------------------------------------------------------------------
  // Константи
  // -------------------------------------------------------------------------

  /// Назва таблиці в SQLite.
  static const String tableName = 'transactions';

  // -------------------------------------------------------------------------
  // Поля
  // -------------------------------------------------------------------------

  /// Унікальний ідентифікатор транзакції (UUID v4).
  final String id;

  /// Дата і час проведення транзакції (з боку банку або користувача).
  final DateTime txDate;

  /// Дата валютування (може бути відсутньою).
  final DateTime? postingDate;

  /// Сума в оригінальній валюті; від'ємна — витрата, додатна — дохід.
  final double amount;

  /// Валюта транзакції.
  final CurrencyType currency;

  /// Сума, конвертована в гривні.
  final double amountUah;

  /// Обмінний курс на момент транзакції (якщо валюта не UAH).
  final double? exchangeRate;

  /// Тип транзакції.
  final TxType txType;

  /// Опис або призначення платежу.
  final String description;

  /// Назва категорії (FK → categories.name; ON UPDATE CASCADE, ON DELETE SET NULL).
  final String? categoryName;

  /// Категорія, отримана від банку (необроблена).
  final String? bankCategory;

  /// Банк або джерело транзакції.
  final BankSource bank;

  /// Ідентифікатор картки (FK → cards.id; ON DELETE SET NULL).
  final int? cardId;

  /// IBAN рахунку (для банківських переказів).
  final String? iban;

  /// Код МСС (Merchant Category Code).
  final int? mcc;

  /// Розмір комісії за транзакцію.
  final double commission;

  /// Розмір кешбеку за транзакцію.
  final double cashback;

  /// Залишок на рахунку після проведення транзакції.
  final double? balanceAfter;

  /// Ідентифікатор батьківської транзакції (для транзакцій-кешбеку).
  final String? parentTxId;

  /// Джерело імпорту (наприклад, назва файлу або API-ендпоінт).
  final String? importSource;

  /// Ідентифікатор пакету імпорту (для групування).
  final String? importBatchId;

  /// Дата і час імпорту транзакції.
  final DateTime importDate;

  /// Хеш для дедублікації; NULL для транзакцій, введених вручну.
  final String? dedupHash;

  /// Чи введена транзакція вручну.
  final bool isManual;

  /// Чи є транзакція внутрішнім переказом (виключається зі статистики).
  final bool isInternal;

  /// М'яке видалення: транзакція прихована, але не видалена з бази.
  final bool isDeleted;

  /// Дата і час створення запису.
  final DateTime createdAt;

  /// Дата і час останнього оновлення запису.
  final DateTime updatedAt;

  // -------------------------------------------------------------------------
  // Конструктор
  // -------------------------------------------------------------------------

  const TransactionModel({
    required this.id,
    required this.txDate,
    this.postingDate,
    required this.amount,
    this.currency = CurrencyType.uah,
    required this.amountUah,
    this.exchangeRate,
    required this.txType,
    this.description = '',
    this.categoryName,
    this.bankCategory,
    required this.bank,
    this.cardId,
    this.iban,
    this.mcc,
    this.commission = 0.0,
    this.cashback = 0.0,
    this.balanceAfter,
    this.parentTxId,
    this.importSource,
    this.importBatchId,
    required this.importDate,
    this.dedupHash,
    this.isManual = false,
    this.isInternal = false,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // -------------------------------------------------------------------------
  // Допоміжні геттери
  // -------------------------------------------------------------------------

  /// Чи є транзакція витратою.
  bool get isExpense => txType == TxType.expense;

  /// Чи є транзакція доходом.
  bool get isIncome => txType == TxType.income;

  /// Чи є транзакція кешбеком (має посилання на батьківську транзакцію).
  bool get isCashback => parentTxId != null;

  /// Чи проведена транзакція в іноземній валюті.
  bool get isForeignCurrency => currency != CurrencyType.uah;

  /// Абсолютне значення суми (без знаку).
  double get absoluteAmount => amount.abs();

  // -------------------------------------------------------------------------
  // Статичні помічники
  // -------------------------------------------------------------------------

  /// Генерує унікальний ідентифікатор у форматі UUID v4 без зовнішніх пакетів.
  static String generateId() {
    final random = Random.secure();

    // Генеруємо 16 випадкових байтів
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Встановлюємо біти версії (4) та варіанту (RFC 4122)
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10xx

    // Перетворюємо на шістнадцятковий рядок з дефісами: 8-4-4-4-12
    String hex(List<int> b) =>
        b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

    return '${hex(bytes.sublist(0, 4))}-'
        '${hex(bytes.sublist(4, 6))}-'
        '${hex(bytes.sublist(6, 8))}-'
        '${hex(bytes.sublist(8, 10))}-'
        '${hex(bytes.sublist(10, 16))}';
  }

  /// Будує хеш для дедублікації на основі ключових полів транзакції.
  ///
  /// Повертає шістнадцятковий рядок, обчислений із конкатенації дати,
  /// суми в UAH, банку та ідентифікатора картки.
  static String buildDedupHash(
    DateTime date,
    double amountUah,
    String bank,
    int? cardId,
  ) {
    final raw =
        '${date.toIso8601String().substring(0, 10)}|$amountUah|$bank|${cardId ?? 0}';
    return raw.hashCode.toRadixString(16);
  }

  // -------------------------------------------------------------------------
  // Десеріалізація з SQLite (Map<String, dynamic>)
  // -------------------------------------------------------------------------

  /// Створює [TransactionModel] із рядка SQLite-таблиці.
  ///
  /// SQLite зберігає булеві значення як INTEGER (0/1),
  /// а DateTime — як рядки ISO 8601.
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      txDate: DateTime.parse(map['tx_date'] as String),
      postingDate: map['posting_date'] != null
          ? DateTime.parse(map['posting_date'] as String)
          : null,
      amount: (map['amount'] as num).toDouble(),
      currency: CurrencyType.fromSqlValue(
        map['currency'] as String? ?? 'UAH',
      ),
      amountUah: (map['amount_uah'] as num).toDouble(),
      exchangeRate: map['exchange_rate'] != null
          ? (map['exchange_rate'] as num).toDouble()
          : null,
      txType: TxType.fromSqlValue(map['tx_type'] as String),
      description: map['description'] as String? ?? '',
      categoryName: map['category_name'] as String?,
      bankCategory: map['bank_category'] as String?,
      bank: BankSource.fromSqlValue(map['bank'] as String),
      cardId: map['card_id'] as int?,
      iban: map['iban'] as String?,
      mcc: map['mcc'] as int?,
      commission: (map['commission'] as num?)?.toDouble() ?? 0.0,
      cashback: (map['cashback'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: map['balance_after'] != null
          ? (map['balance_after'] as num).toDouble()
          : null,
      parentTxId: map['parent_tx_id'] as String?,
      importSource: map['import_source'] as String?,
      importBatchId: map['import_batch_id'] as String?,
      importDate: DateTime.parse(map['import_date'] as String),
      dedupHash: map['dedup_hash'] as String?,
      isManual: (map['is_manual'] as int? ?? 0) != 0,
      isInternal: (map['is_internal'] as int? ?? 0) != 0,
      isDeleted: (map['is_deleted'] as int? ?? 0) != 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // -------------------------------------------------------------------------
  // Серіалізація в SQLite (Map<String, dynamic>)
  // -------------------------------------------------------------------------

  /// Перетворює модель на Map для збереження в SQLite.
  ///
  /// Булеві значення кодуються як INTEGER (0/1),
  /// DateTime — як рядки ISO 8601, enum-и — через [toSqlValue()].
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tx_date': txDate.toIso8601String(),
      'posting_date': postingDate?.toIso8601String(),
      'amount': amount,
      'currency': currency.toSqlValue(),
      'amount_uah': amountUah,
      'exchange_rate': exchangeRate,
      'tx_type': txType.toSqlValue(),
      'description': description,
      'category_name': categoryName,
      'bank_category': bankCategory,
      'bank': bank.toSqlValue(),
      'card_id': cardId,
      'iban': iban,
      'mcc': mcc,
      'commission': commission,
      'cashback': cashback,
      'balance_after': balanceAfter,
      'parent_tx_id': parentTxId,
      'import_source': importSource,
      'import_batch_id': importBatchId,
      'import_date': importDate.toIso8601String(),
      'dedup_hash': dedupHash,
      'is_manual': isManual ? 1 : 0,
      'is_internal': isInternal ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // -------------------------------------------------------------------------
  // Десеріалізація з JSON (Map<String, dynamic>)
  // -------------------------------------------------------------------------

  /// Створює [TransactionModel] із JSON-відповіді API.
  ///
  /// JSON використовує camelCase і зберігає булеві значення як bool,
  /// а DateTime — як рядки ISO 8601.
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      txDate: DateTime.parse(json['txDate'] as String),
      postingDate: json['postingDate'] != null
          ? DateTime.parse(json['postingDate'] as String)
          : null,
      amount: (json['amount'] as num).toDouble(),
      currency: CurrencyType.fromSqlValue(
        json['currency'] as String? ?? 'UAH',
      ),
      amountUah: (json['amountUah'] as num).toDouble(),
      exchangeRate: json['exchangeRate'] != null
          ? (json['exchangeRate'] as num).toDouble()
          : null,
      txType: TxType.fromSqlValue(json['txType'] as String),
      description: json['description'] as String? ?? '',
      categoryName: json['categoryName'] as String?,
      bankCategory: json['bankCategory'] as String?,
      bank: BankSource.fromSqlValue(json['bank'] as String),
      cardId: json['cardId'] as int?,
      iban: json['iban'] as String?,
      mcc: json['mcc'] as int?,
      commission: (json['commission'] as num?)?.toDouble() ?? 0.0,
      cashback: (json['cashback'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: json['balanceAfter'] != null
          ? (json['balanceAfter'] as num).toDouble()
          : null,
      parentTxId: json['parentTxId'] as String?,
      importSource: json['importSource'] as String?,
      importBatchId: json['importBatchId'] as String?,
      importDate: DateTime.parse(json['importDate'] as String),
      dedupHash: json['dedupHash'] as String?,
      isManual: json['isManual'] as bool? ?? false,
      isInternal: json['isInternal'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  // -------------------------------------------------------------------------
  // Серіалізація в JSON (Map<String, dynamic>)
  // -------------------------------------------------------------------------

  /// Перетворює модель на Map для JSON-відповіді або запиту до API.
  ///
  /// Використовує camelCase, булеві значення — як bool,
  /// DateTime — як рядки ISO 8601.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'txDate': txDate.toIso8601String(),
      'postingDate': postingDate?.toIso8601String(),
      'amount': amount,
      'currency': currency.toSqlValue(),
      'amountUah': amountUah,
      'exchangeRate': exchangeRate,
      'txType': txType.toSqlValue(),
      'description': description,
      'categoryName': categoryName,
      'bankCategory': bankCategory,
      'bank': bank.toSqlValue(),
      'cardId': cardId,
      'iban': iban,
      'mcc': mcc,
      'commission': commission,
      'cashback': cashback,
      'balanceAfter': balanceAfter,
      'parentTxId': parentTxId,
      'importSource': importSource,
      'importBatchId': importBatchId,
      'importDate': importDate.toIso8601String(),
      'dedupHash': dedupHash,
      'isManual': isManual,
      'isInternal': isInternal,
      'isDeleted': isDeleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // -------------------------------------------------------------------------
  // copyWith
  // -------------------------------------------------------------------------

  /// Повертає нову копію моделі з вибірково заміненими полями.
  ///
  /// Для скидання nullable-поля до null використовуйте обгортку [_Wrap]:
  /// передайте `_Wrap(null)` через відповідний параметр типу `Object?`.
  /// Спрощена версія: усі nullable-поля скидаються напряму через sentinel-об'єкт.
  TransactionModel copyWith({
    String? id,
    DateTime? txDate,
    Object? postingDate = _sentinel,
    double? amount,
    CurrencyType? currency,
    double? amountUah,
    Object? exchangeRate = _sentinel,
    TxType? txType,
    String? description,
    Object? categoryName = _sentinel,
    Object? bankCategory = _sentinel,
    BankSource? bank,
    Object? cardId = _sentinel,
    Object? iban = _sentinel,
    Object? mcc = _sentinel,
    double? commission,
    double? cashback,
    Object? balanceAfter = _sentinel,
    Object? parentTxId = _sentinel,
    Object? importSource = _sentinel,
    Object? importBatchId = _sentinel,
    DateTime? importDate,
    Object? dedupHash = _sentinel,
    bool? isManual,
    bool? isInternal,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      txDate: txDate ?? this.txDate,
      postingDate:
          postingDate == _sentinel ? this.postingDate : postingDate as DateTime?,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      amountUah: amountUah ?? this.amountUah,
      exchangeRate: exchangeRate == _sentinel
          ? this.exchangeRate
          : exchangeRate as double?,
      txType: txType ?? this.txType,
      description: description ?? this.description,
      categoryName: categoryName == _sentinel
          ? this.categoryName
          : categoryName as String?,
      bankCategory: bankCategory == _sentinel
          ? this.bankCategory
          : bankCategory as String?,
      bank: bank ?? this.bank,
      cardId: cardId == _sentinel ? this.cardId : cardId as int?,
      iban: iban == _sentinel ? this.iban : iban as String?,
      mcc: mcc == _sentinel ? this.mcc : mcc as int?,
      commission: commission ?? this.commission,
      cashback: cashback ?? this.cashback,
      balanceAfter: balanceAfter == _sentinel
          ? this.balanceAfter
          : balanceAfter as double?,
      parentTxId:
          parentTxId == _sentinel ? this.parentTxId : parentTxId as String?,
      importSource: importSource == _sentinel
          ? this.importSource
          : importSource as String?,
      importBatchId: importBatchId == _sentinel
          ? this.importBatchId
          : importBatchId as String?,
      importDate: importDate ?? this.importDate,
      dedupHash:
          dedupHash == _sentinel ? this.dedupHash : dedupHash as String?,
      isManual: isManual ?? this.isManual,
      isInternal: isInternal ?? this.isInternal,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // -------------------------------------------------------------------------
  // Рівність та хеш
  // -------------------------------------------------------------------------

  /// Дві транзакції вважаються однаковими, якщо їхні [id] збігаються.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionModel && other.id == id;
  }

  /// Хеш-код базується виключно на [id].
  @override
  int get hashCode => id.hashCode;

  // -------------------------------------------------------------------------
  // Рядкове представлення
  // -------------------------------------------------------------------------

  @override
  String toString() {
    return 'TransactionModel('
        'id: $id, '
        'txDate: ${txDate.toIso8601String()}, '
        'postingDate: ${postingDate?.toIso8601String()}, '
        'amount: $amount, '
        'currency: ${currency.toSqlValue()}, '
        'amountUah: $amountUah, '
        'exchangeRate: $exchangeRate, '
        'txType: ${txType.toSqlValue()}, '
        'description: "$description", '
        'categoryName: $categoryName, '
        'bankCategory: $bankCategory, '
        'bank: ${bank.toSqlValue()}, '
        'cardId: $cardId, '
        'iban: $iban, '
        'mcc: $mcc, '
        'commission: $commission, '
        'cashback: $cashback, '
        'balanceAfter: $balanceAfter, '
        'parentTxId: $parentTxId, '
        'importSource: $importSource, '
        'importBatchId: $importBatchId, '
        'importDate: ${importDate.toIso8601String()}, '
        'dedupHash: $dedupHash, '
        'isManual: $isManual, '
        'isInternal: $isInternal, '
        'isDeleted: $isDeleted, '
        'createdAt: ${createdAt.toIso8601String()}, '
        'updatedAt: ${updatedAt.toIso8601String()}'
        ')';
  }
}

// ---------------------------------------------------------------------------
// Внутрішній sentinel-об'єкт для розрізнення null і «не передано»
// ---------------------------------------------------------------------------

/// Внутрішній маркер для [TransactionModel.copyWith]:
/// дозволяє відрізнити явно передане `null` від відсутнього аргументу.
const Object _sentinel = Object();
