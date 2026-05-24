// lib/data/models/rule_model.dart

import 'dart:convert';

// ---------------------------------------------------------------------------
// Тип співставлення ключового слова з текстом транзакції
// ---------------------------------------------------------------------------
enum MatchType {
  contains,
  startsWith,
  exact,
  regex;

  /// Повертає рядкове значення для збереження в SQLite
  String toSqlValue() {
    switch (this) {
      case MatchType.contains:
        return 'contains';
      case MatchType.startsWith:
        return 'starts_with';
      case MatchType.exact:
        return 'exact';
      case MatchType.regex:
        return 'regex';
    }
  }

  /// Розбирає рядкове значення з SQLite
  static MatchType fromSqlValue(String value) {
    switch (value) {
      case 'contains':
        return MatchType.contains;
      case 'starts_with':
        return MatchType.startsWith;
      case 'exact':
        return MatchType.exact;
      case 'regex':
        return MatchType.regex;
      default:
        throw ArgumentError('Невідомий тип співставлення: $value');
    }
  }
}

// ---------------------------------------------------------------------------
// Поле транзакції, по якому виконується пошук
// ---------------------------------------------------------------------------
enum SourceField {
  description,
  bankCategory;

  /// Повертає рядкове значення для збереження в SQLite
  String toSqlValue() {
    switch (this) {
      case SourceField.description:
        return 'description';
      case SourceField.bankCategory:
        return 'bank_category';
    }
  }

  /// Розбирає рядкове значення з SQLite
  static SourceField fromSqlValue(String value) {
    switch (value) {
      case 'description':
        return SourceField.description;
      case 'bank_category':
        return SourceField.bankCategory;
      default:
        throw ArgumentError('Невідоме поле джерела: $value');
    }
  }
}

// ---------------------------------------------------------------------------
// Фільтр типу транзакції (null означає «будь-який тип»)
// ---------------------------------------------------------------------------
enum TxTypeFilter {
  income,
  expense;

  /// Повертає рядкове значення для збереження в SQLite
  String toSqlValue() {
    switch (this) {
      case TxTypeFilter.income:
        return 'income';
      case TxTypeFilter.expense:
        return 'expense';
    }
  }

  /// Розбирає рядкове значення з SQLite; повертає null якщо значення null
  static TxTypeFilter? fromSqlValue(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'income':
        return TxTypeFilter.income;
      case 'expense':
        return TxTypeFilter.expense;
      default:
        throw ArgumentError('Невідомий тип транзакції: $value');
    }
  }
}

// ---------------------------------------------------------------------------
// Модель правила автоматичної категоризації транзакцій
// ---------------------------------------------------------------------------
class RuleModel {
  /// Назва таблиці в SQLite
  static const String tableName = 'rules';

  /// Унікальний ідентифікатор
  final int? id;

  /// Ключове слово або вираз для пошуку
  final String keyword;

  /// Тип співставлення: contains, starts_with, exact, regex
  final MatchType matchType;

  /// Назва категорії (зовнішній ключ → categories.name)
  final String categoryName;

  /// Поле транзакції, по якому виконується пошук
  final SourceField sourceField;

  /// Фільтр типу транзакції (null — правило діє для будь-якого типу)
  final TxTypeFilter? txType;

  /// Пріоритет правила (1 = найвищий, 100 = найнижчий)
  final int priority;

  /// Чи активне правило
  final bool isActive;

  /// Чи є правило системним (не видаляється користувачем)
  final bool isSystem;

  /// Час створення запису
  final DateTime? createdAt;

  /// Час останнього оновлення запису
  final DateTime? updatedAt;

  const RuleModel({
    this.id,
    required this.keyword,
    this.matchType = MatchType.contains,
    required this.categoryName,
    this.sourceField = SourceField.description,
    this.txType,
    this.priority = 50,
    this.isActive = true,
    this.isSystem = false,
    this.createdAt,
    this.updatedAt,
  });

  // -------------------------------------------------------------------------
  // Фабричний конструктор з рядка SQLite
  // -------------------------------------------------------------------------
  factory RuleModel.fromMap(Map<String, dynamic> map) {
    return RuleModel(
      id: map['id'] as int?,
      keyword: map['keyword'] as String,
      matchType: MatchType.fromSqlValue(
        (map['match_type'] as String?) ?? 'contains',
      ),
      categoryName: map['category_name'] as String,
      sourceField: SourceField.fromSqlValue(
        (map['source_field'] as String?) ?? 'description',
      ),
      txType: TxTypeFilter.fromSqlValue(map['tx_type'] as String?),
      priority: (map['priority'] as int?) ?? 50,
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      isSystem: ((map['is_system'] as int?) ?? 0) == 1,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Серіалізація для збереження в SQLite.
  /// Якщо [id] == null, поле 'id' не включається.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'keyword': keyword,
      'match_type': matchType.toSqlValue(),
      'category_name': categoryName,
      'source_field': sourceField.toSqlValue(),
      'tx_type': txType?.toSqlValue(),
      'priority': priority,
      'is_active': isActive ? 1 : 0,
      'is_system': isSystem ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  // -------------------------------------------------------------------------
  // JSON-серіалізація
  // -------------------------------------------------------------------------
  factory RuleModel.fromJson(Map<String, dynamic> json) =>
      RuleModel.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  /// Декодування з JSON-рядка
  factory RuleModel.fromJsonString(String source) =>
      RuleModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// Кодування до JSON-рядка
  String toJsonString() => jsonEncode(toJson());

  // -------------------------------------------------------------------------
  // copyWith — повертає новий незмінний екземпляр зі зміненими полями
  // -------------------------------------------------------------------------
  RuleModel copyWith({
    int? id,
    String? keyword,
    MatchType? matchType,
    String? categoryName,
    SourceField? sourceField,
    TxTypeFilter? txType,
    bool clearTxType = false,
    int? priority,
    bool? isActive,
    bool? isSystem,
    DateTime? createdAt,
    bool clearCreatedAt = false,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
  }) {
    return RuleModel(
      id: id ?? this.id,
      keyword: keyword ?? this.keyword,
      matchType: matchType ?? this.matchType,
      categoryName: categoryName ?? this.categoryName,
      sourceField: sourceField ?? this.sourceField,
      txType: clearTxType ? null : (txType ?? this.txType),
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      isSystem: isSystem ?? this.isSystem,
      createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    );
  }

  // -------------------------------------------------------------------------
  // Перевірка відповідності вхідного рядка правилу
  // -------------------------------------------------------------------------
  /// Перевіряє, чи збігається [input] з [keyword] відповідно до [matchType].
  ///
  /// - [MatchType.contains]    — регістронезалежне входження підрядка
  /// - [MatchType.startsWith]  — регістронезалежний початок рядка
  /// - [MatchType.exact]       — регістронезалежне точне співпадіння
  /// - [MatchType.regex]       — перевірка за регулярним виразом (без зміни регістру)
  bool matches(String input) {
    switch (matchType) {
      case MatchType.contains:
        return input.toLowerCase().contains(keyword.toLowerCase());

      case MatchType.startsWith:
        return input.toLowerCase().startsWith(keyword.toLowerCase());

      case MatchType.exact:
        return input.toLowerCase() == keyword.toLowerCase();

      case MatchType.regex:
        // Виняток навмисно не перехоплюється — некоректний regex є помилкою
        // конфігурації і має бути виявлений під час тестування.
        final pattern = RegExp(keyword);
        return pattern.hasMatch(input);
    }
  }

  // -------------------------------------------------------------------------
  // Рівність та хеш-код визначаються за полем id
  // -------------------------------------------------------------------------
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RuleModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'RuleModel('
        'id: $id, '
        'keyword: $keyword, '
        'matchType: ${matchType.toSqlValue()}, '
        'categoryName: $categoryName, '
        'sourceField: ${sourceField.toSqlValue()}, '
        'txType: ${txType?.toSqlValue()}, '
        'priority: $priority, '
        'isActive: $isActive, '
        'isSystem: $isSystem, '
        'createdAt: $createdAt, '
        'updatedAt: $updatedAt'
        ')';
  }
}
