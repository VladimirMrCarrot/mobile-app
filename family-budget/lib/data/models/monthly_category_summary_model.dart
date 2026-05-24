// lib/data/models/monthly_category_summary_model.dart

import 'dart:convert';

// ---------------------------------------------------------------------------
// Модель місячного підсумку за категорією витрат/доходів
// ---------------------------------------------------------------------------
class MonthlyCategorySummaryModel {
  /// Назва таблиці в SQLite
  static const String tableName = 'monthly_category_summary';

  /// Унікальний ідентифікатор (null до першого збереження)
  final int? id;

  /// Рік підсумку
  final int year;

  /// Місяць підсумку (1–12)
  final int month;

  /// Назва категорії (зовнішній ключ → categories.name)
  final String categoryName;

  /// Загальна сума транзакцій за категорією
  final double total;

  /// Кількість транзакцій у категорії
  final int txCount;

  /// Час останнього перерахунку підсумку
  final DateTime calculatedAt;

  const MonthlyCategorySummaryModel({
    this.id,
    required this.year,
    required this.month,
    required this.categoryName,
    this.total = 0.0,
    this.txCount = 0,
    required this.calculatedAt,
  });

  // -------------------------------------------------------------------------
  // Обчислювані властивості
  // -------------------------------------------------------------------------

  /// Людиночитана мітка місяця у форматі 'MM.YYYY', наприклад '03.2026'.
  String get monthLabel {
    final mm = month.toString().padLeft(2, '0');
    return '$mm.$year';
  }

  // -------------------------------------------------------------------------
  // Фабричний конструктор з рядка SQLite / JSON-об'єкта
  // -------------------------------------------------------------------------
  factory MonthlyCategorySummaryModel.fromMap(Map<String, dynamic> map) {
    return MonthlyCategorySummaryModel(
      id: map['id'] as int?,
      year: map['year'] as int,
      month: map['month'] as int,
      categoryName: map['category_name'] as String,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      txCount: (map['tx_count'] as int?) ?? 0,
      calculatedAt: DateTime.parse(map['calculated_at'] as String),
    );
  }

  /// Серіалізація для збереження в SQLite.
  /// Якщо [id] == null, поле 'id' не включається (AUTOINCREMENT).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'year': year,
      'month': month,
      'category_name': categoryName,
      'total': total,
      'tx_count': txCount,
      'calculated_at': calculatedAt.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  // -------------------------------------------------------------------------
  // JSON-серіалізація
  // -------------------------------------------------------------------------
  factory MonthlyCategorySummaryModel.fromJson(Map<String, dynamic> json) =>
      MonthlyCategorySummaryModel.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  /// Декодування з JSON-рядка
  factory MonthlyCategorySummaryModel.fromJsonString(String source) =>
      MonthlyCategorySummaryModel.fromJson(
          jsonDecode(source) as Map<String, dynamic>);

  /// Кодування до JSON-рядка
  String toJsonString() => jsonEncode(toJson());

  // -------------------------------------------------------------------------
  // copyWith — повертає новий незмінний екземпляр зі зміненими полями
  // -------------------------------------------------------------------------
  MonthlyCategorySummaryModel copyWith({
    int? id,
    int? year,
    int? month,
    String? categoryName,
    double? total,
    int? txCount,
    DateTime? calculatedAt,
  }) {
    return MonthlyCategorySummaryModel(
      id: id ?? this.id,
      year: year ?? this.year,
      month: month ?? this.month,
      categoryName: categoryName ?? this.categoryName,
      total: total ?? this.total,
      txCount: txCount ?? this.txCount,
      calculatedAt: calculatedAt ?? this.calculatedAt,
    );
  }

  // -------------------------------------------------------------------------
  // Рівність та хеш-код
  // -------------------------------------------------------------------------
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MonthlyCategorySummaryModel &&
        other.id == id &&
        other.year == year &&
        other.month == month &&
        other.categoryName == categoryName &&
        other.total == total &&
        other.txCount == txCount &&
        other.calculatedAt == calculatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        year,
        month,
        categoryName,
        total,
        txCount,
        calculatedAt,
      );

  @override
  String toString() {
    return 'MonthlyCategorySummaryModel('
        'id: $id, '
        'year: $year, '
        'month: $month, '
        'categoryName: $categoryName, '
        'total: $total, '
        'txCount: $txCount, '
        'calculatedAt: $calculatedAt'
        ')';
  }
}
