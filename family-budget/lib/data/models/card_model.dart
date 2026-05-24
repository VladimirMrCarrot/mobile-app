// lib/data/models/card_model.dart

import 'dart:convert';

// ---------------------------------------------------------------------------
// Перелік банків, що підтримуються
// ---------------------------------------------------------------------------
enum BankType {
  pumb,
  monobank,
  privatbank,
  other;

  /// Повертає рядкове значення для збереження в SQLite
  String toSqlValue() {
    switch (this) {
      case BankType.pumb:
        return 'ПУМБ';
      case BankType.monobank:
        return 'Monobank';
      case BankType.privatbank:
        return 'Приватбанк';
      case BankType.other:
        return 'Інший';
    }
  }

  /// Розбирає рядкове значення з SQLite
  static BankType fromSqlValue(String value) {
    switch (value) {
      case 'ПУМБ':
        return BankType.pumb;
      case 'Monobank':
        return BankType.monobank;
      case 'Приватбанк':
        return BankType.privatbank;
      case 'Інший':
        return BankType.other;
      default:
        throw ArgumentError('Невідомий тип банку: $value');
    }
  }
}

// ---------------------------------------------------------------------------
// Перелік валют
// ---------------------------------------------------------------------------
enum CurrencyType {
  uah,
  usd,
  eur;

  /// Повертає рядкове значення для збереження в SQLite
  String toSqlValue() {
    switch (this) {
      case CurrencyType.uah:
        return 'UAH';
      case CurrencyType.usd:
        return 'USD';
      case CurrencyType.eur:
        return 'EUR';
    }
  }

  /// Розбирає рядкове значення з SQLite
  static CurrencyType fromSqlValue(String value) {
    switch (value) {
      case 'UAH':
        return CurrencyType.uah;
      case 'USD':
        return CurrencyType.usd;
      case 'EUR':
        return CurrencyType.eur;
      default:
        throw ArgumentError('Невідома валюта: $value');
    }
  }
}

// ---------------------------------------------------------------------------
// Перелік джерел / банків
// ---------------------------------------------------------------------------
enum BankSource {
  pumb,
  monobank,
  privatbank,
  manual;

  /// Повертає рядкове значення для збереження в SQLite / API.
  String toSqlValue() {
    switch (this) {
      case BankSource.pumb:
        return 'ПУМБ';
      case BankSource.monobank:
        return 'Monobank';
      case BankSource.privatbank:
        return 'Приватбанк';
      case BankSource.manual:
        return 'Ручний ввід';
    }
  }

  /// Створює [BankSource] із рядкового значення бази даних або API.
  static BankSource fromSqlValue(String value) {
    switch (value) {
      case 'ПУМБ':
        return BankSource.pumb;
      case 'Monobank':
        return BankSource.monobank;
      case 'Приватбанк':
        return BankSource.privatbank;
      case 'Ручний ввід':
        return BankSource.manual;
      default:
        throw ArgumentError('Невідоме джерело банку: $value');
    }
  }
}

// ---------------------------------------------------------------------------
// Перелік типів транзакцій
// ---------------------------------------------------------------------------
enum TxType {
  income,
  expense,
  transfer;

  /// Повертає рядкове значення для збереження в SQLite / API.
  String toSqlValue() {
    switch (this) {
      case TxType.income:
        return 'income';
      case TxType.expense:
        return 'expense';
      case TxType.transfer:
        return 'transfer';
    }
  }

  /// Створює [TxType] із рядкового значення бази даних або API.
  static TxType fromSqlValue(String value) {
    switch (value) {
      case 'income':
        return TxType.income;
      case 'expense':
        return TxType.expense;
      case 'transfer':
        return TxType.transfer;
      default:
        throw ArgumentError('Невідомий тип транзакції: $value');
    }
  }
}

// ---------------------------------------------------------------------------
// Перелік статусів пакету імпорту
// ---------------------------------------------------------------------------
enum ImportStatus {
  completed,
  rolledBack;

  /// Повертає рядкове значення для збереження в SQLite
  String toSqlValue() {
    switch (this) {
      case ImportStatus.completed:
        return 'completed';
      case ImportStatus.rolledBack:
        return 'rolled_back';
    }
  }

  /// Розбирає рядкове значення з SQLite
  static ImportStatus fromSqlValue(String value) {
    switch (value) {
      case 'completed':
        return ImportStatus.completed;
      case 'rolled_back':
        return ImportStatus.rolledBack;
      default:
        throw ArgumentError('Невідомий статус імпорту: $value');
    }
  }
}

// ---------------------------------------------------------------------------
// Модель картки
// ---------------------------------------------------------------------------
class CardModel {
  /// Назва таблиці в SQLite
  static const String tableName = 'cards';

  /// Унікальний ідентифікатор (null до першого збереження)
  final int? id;

  /// Банк, якому належить картка
  final BankType bank;

  /// Маскований номер картки, наприклад '42065200****7875'
  final String cardNumber;

  /// IBAN рахунку (може бути відсутній)
  final String? iban;

  /// Валюта рахунку
  final CurrencyType currency;

  /// Відображуване ім'я картки (може бути відсутнє)
  final String? displayName;

  /// Поточний залишок
  final double balance;

  /// Час останнього оновлення залишку
  final DateTime? balanceUpdatedAt;

  /// Чи активна картка
  final bool isActive;

  /// Порядок відображення у списку
  final int sortOrder;

  /// Час створення запису
  final DateTime createdAt;

  /// Час останнього оновлення запису
  final DateTime updatedAt;

  const CardModel({
    this.id,
    required this.bank,
    required this.cardNumber,
    this.iban,
    this.currency = CurrencyType.uah,
    this.displayName,
    this.balance = 0.0,
    this.balanceUpdatedAt,
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  // -------------------------------------------------------------------------
  // Фабричний конструктор з рядка SQLite
  // -------------------------------------------------------------------------
  factory CardModel.fromMap(Map<String, dynamic> map) {
    return CardModel(
      id: map['id'] as int?,
      bank: BankType.fromSqlValue(map['bank'] as String),
      cardNumber: map['card_number'] as String,
      iban: map['iban'] as String?,
      currency: CurrencyType.fromSqlValue(
        (map['currency'] as String?) ?? 'UAH',
      ),
      displayName: map['display_name'] as String?,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      balanceUpdatedAt: map['balance_updated_at'] != null
          ? DateTime.parse(map['balance_updated_at'] as String)
          : null,
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Серіалізація для збереження в SQLite.
  /// Якщо [id] == null, поле 'id' не включається (AUTOINCREMENT).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'bank': bank.toSqlValue(),
      'card_number': cardNumber,
      'iban': iban,
      'currency': currency.toSqlValue(),
      'display_name': displayName,
      'balance': balance,
      'balance_updated_at': balanceUpdatedAt?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  // -------------------------------------------------------------------------
  // JSON-серіалізація (дати зберігаються як ISO 8601 рядки)
  // -------------------------------------------------------------------------
  factory CardModel.fromJson(Map<String, dynamic> json) =>
      CardModel.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  /// Декодування з JSON-рядка
  factory CardModel.fromJsonString(String source) =>
      CardModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// Кодування до JSON-рядка
  String toJsonString() => jsonEncode(toJson());

  // -------------------------------------------------------------------------
  // copyWith — повертає новий незмінний екземпляр зі зміненими полями
  // -------------------------------------------------------------------------
  CardModel copyWith({
    int? id,
    BankType? bank,
    String? cardNumber,
    String? iban,
    bool clearIban = false,
    CurrencyType? currency,
    String? displayName,
    bool clearDisplayName = false,
    double? balance,
    DateTime? balanceUpdatedAt,
    bool clearBalanceUpdatedAt = false,
    bool? isActive,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CardModel(
      id: id ?? this.id,
      bank: bank ?? this.bank,
      cardNumber: cardNumber ?? this.cardNumber,
      iban: clearIban ? null : (iban ?? this.iban),
      currency: currency ?? this.currency,
      displayName: clearDisplayName ? null : (displayName ?? this.displayName),
      balance: balance ?? this.balance,
      balanceUpdatedAt: clearBalanceUpdatedAt
          ? null
          : (balanceUpdatedAt ?? this.balanceUpdatedAt),
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // -------------------------------------------------------------------------
  // Рівність та хеш-код визначаються за полем id
  // -------------------------------------------------------------------------
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CardModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CardModel('
        'id: $id, '
        'bank: ${bank.toSqlValue()}, '
        'cardNumber: $cardNumber, '
        'iban: $iban, '
        'currency: ${currency.toSqlValue()}, '
        'displayName: $displayName, '
        'balance: $balance, '
        'balanceUpdatedAt: $balanceUpdatedAt, '
        'isActive: $isActive, '
        'sortOrder: $sortOrder, '
        'createdAt: $createdAt, '
        'updatedAt: $updatedAt'
        ')';
  }

  // -------------------------------------------------------------------------
  // Попередньо заповнений список відомих карток
  // -------------------------------------------------------------------------
  static List<CardModel> defaults() {
    // Базовий час для полів created_at / updated_at у дефолтних записах
    final now = DateTime.utc(2024, 1, 1);

    return [
      CardModel(
        bank: BankType.pumb,
        cardNumber: '42065200****7875',
        iban: 'UA14348510000026208117398264',
        currency: CurrencyType.uah,
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      ),
      CardModel(
        bank: BankType.monobank,
        cardNumber: '4441****4491',
        iban: 'UA193220010000026209300479632',
        currency: CurrencyType.uah,
        sortOrder: 2,
        createdAt: now,
        updatedAt: now,
      ),
      CardModel(
        bank: BankType.privatbank,
        cardNumber: '5168****4428',
        displayName: 'Приват 4428',
        currency: CurrencyType.uah,
        sortOrder: 3,
        createdAt: now,
        updatedAt: now,
      ),
      CardModel(
        bank: BankType.privatbank,
        cardNumber: '5169****3844',
        displayName: 'Приват 3844',
        currency: CurrencyType.uah,
        sortOrder: 4,
        createdAt: now,
        updatedAt: now,
      ),
      CardModel(
        bank: BankType.privatbank,
        cardNumber: '4149****3336',
        displayName: 'Приват 3336',
        currency: CurrencyType.uah,
        sortOrder: 5,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}
