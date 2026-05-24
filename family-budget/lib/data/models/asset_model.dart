// lib/data/models/asset_model.dart

import 'dart:convert';

import '../models/card_model.dart'; // CurrencyType

// ---------------------------------------------------------------------------
// Перелік типів активів
// ---------------------------------------------------------------------------
enum AssetType {
  deposit,
  realEstate,
  vehicle,
  other;

  /// Повертає рядкове значення для збереження в SQLite
  String toSqlValue() {
    switch (this) {
      case AssetType.deposit:
        return 'deposit';
      case AssetType.realEstate:
        return 'real_estate';
      case AssetType.vehicle:
        return 'vehicle';
      case AssetType.other:
        return 'other';
    }
  }

  /// Розбирає рядкове значення з SQLite
  static AssetType fromSqlValue(String value) {
    switch (value) {
      case 'deposit':
        return AssetType.deposit;
      case 'real_estate':
        return AssetType.realEstate;
      case 'vehicle':
        return AssetType.vehicle;
      case 'other':
        return AssetType.other;
      default:
        throw ArgumentError('Невідомий тип активу: $value');
    }
  }
}

// ---------------------------------------------------------------------------
// Модель активу користувача
// ---------------------------------------------------------------------------
class AssetModel {
  /// Назва таблиці в SQLite
  static const String tableName = 'assets';

  /// Унікальний ідентифікатор (null до першого збереження)
  final int? id;

  /// Назва активу, наприклад 'Депозит ПриватБанк'
  final String name;

  /// Тип активу
  final AssetType assetType;

  /// Поточна ринкова або облікова вартість активу
  final double value;

  /// Валюта оцінки активу
  final CurrencyType currency;

  /// Відсоткова ставка (актуально для депозитів)
  final double? interestRate;

  /// Дата закінчення строку дії (актуально для депозитів)
  final DateTime? maturityDate;

  /// Назва банку або установи, де обліковується актив
  final String? bank;

  /// Ознака активності запису
  final bool isActive;

  /// Час створення запису
  final DateTime createdAt;

  /// Час останнього оновлення запису
  final DateTime updatedAt;

  const AssetModel({
    this.id,
    required this.name,
    required this.assetType,
    this.value = 0.0,
    this.currency = CurrencyType.uah,
    this.interestRate,
    this.maturityDate,
    this.bank,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  // -------------------------------------------------------------------------
  // Фабричний конструктор з рядка SQLite / JSON-об'єкта
  // -------------------------------------------------------------------------
  factory AssetModel.fromMap(Map<String, dynamic> map) {
    return AssetModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      assetType: AssetType.fromSqlValue(map['asset_type'] as String),
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      currency: CurrencyType.fromSqlValue(
        (map['currency'] as String?) ?? 'UAH',
      ),
      interestRate: (map['interest_rate'] as num?)?.toDouble(),
      maturityDate: map['maturity_date'] != null
          ? DateTime.parse(map['maturity_date'] as String)
          : null,
      bank: map['bank'] as String?,
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Серіалізація для збереження в SQLite.
  /// Якщо [id] == null, поле 'id' не включається (AUTOINCREMENT).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'asset_type': assetType.toSqlValue(),
      'value': value,
      'currency': currency.toSqlValue(),
      'interest_rate': interestRate,
      'maturity_date': maturityDate?.toIso8601String(),
      'bank': bank,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  // -------------------------------------------------------------------------
  // JSON-серіалізація
  // -------------------------------------------------------------------------
  factory AssetModel.fromJson(Map<String, dynamic> json) =>
      AssetModel.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  /// Декодування з JSON-рядка
  factory AssetModel.fromJsonString(String source) =>
      AssetModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// Кодування до JSON-рядка
  String toJsonString() => jsonEncode(toJson());

  // -------------------------------------------------------------------------
  // copyWith — повертає новий незмінний екземпляр зі зміненими полями
  // -------------------------------------------------------------------------
  AssetModel copyWith({
    int? id,
    String? name,
    AssetType? assetType,
    double? value,
    CurrencyType? currency,
    double? interestRate,
    bool clearInterestRate = false,
    DateTime? maturityDate,
    bool clearMaturityDate = false,
    String? bank,
    bool clearBank = false,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AssetModel(
      id: id ?? this.id,
      name: name ?? this.name,
      assetType: assetType ?? this.assetType,
      value: value ?? this.value,
      currency: currency ?? this.currency,
      interestRate:
          clearInterestRate ? null : (interestRate ?? this.interestRate),
      maturityDate:
          clearMaturityDate ? null : (maturityDate ?? this.maturityDate),
      bank: clearBank ? null : (bank ?? this.bank),
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // -------------------------------------------------------------------------
  // Рівність та хеш-код
  // -------------------------------------------------------------------------
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AssetModel &&
        other.id == id &&
        other.name == name &&
        other.assetType == assetType &&
        other.value == value &&
        other.currency == currency &&
        other.interestRate == interestRate &&
        other.maturityDate == maturityDate &&
        other.bank == bank &&
        other.isActive == isActive &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        assetType,
        value,
        currency,
        interestRate,
        maturityDate,
        bank,
        isActive,
        createdAt,
        updatedAt,
      );

  @override
  String toString() {
    return 'AssetModel('
        'id: $id, '
        'name: $name, '
        'assetType: ${assetType.toSqlValue()}, '
        'value: $value, '
        'currency: ${currency.toSqlValue()}, '
        'interestRate: $interestRate, '
        'maturityDate: $maturityDate, '
        'bank: $bank, '
        'isActive: $isActive, '
        'createdAt: $createdAt, '
        'updatedAt: $updatedAt'
        ')';
  }
}
