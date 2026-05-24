// lib/data/models/monthly_summary_model.dart

import 'dart:convert';

// ---------------------------------------------------------------------------
// Модель місячного підсумку бюджету
// ---------------------------------------------------------------------------
class MonthlySummaryModel {
  /// Назва таблиці в SQLite
  static const String tableName = 'monthly_summary';

  /// Унікальний ідентифікатор (null до першого збереження)
  final int? id;

  /// Рік підсумку
  final int year;

  /// Місяць підсумку (1–12)
  final int month;

  /// Загальна сума доходів за місяць
  final double totalIncome;

  /// Загальна сума витрат за місяць
  final double totalExpense;

  /// Ознака міграції з попередньої версії даних
  final bool isMigrated;

  /// Час останнього перерахунку підсумку
  final DateTime calculatedAt;

  const MonthlySummaryModel({
    this.id,
    required this.year,
    required this.month,
    this.totalIncome = 0.0,
    this.totalExpense = 0.0,
    this.isMigrated = false,
    required this.calculatedAt,
  });

  // -------------------------------------------------------------------------
  // Обчислювані властивості
  // -------------------------------------------------------------------------

  /// Баланс = доходи − витрати.
  /// Обчислюється локально; не залежить від віртуальної колонки SQLite.
  double get balance => totalIncome - totalExpense;

  /// Людиночитана мітка місяця у форматі 'MM.YYYY', наприклад '01.2026'.
  String get monthLabel {
    final mm = month.toString().padLeft(2, '0');
    return '$mm.$year';
  }

  // -------------------------------------------------------------------------
  // Фабричний конструктор з рядка SQLite / JSON-об'єкта
  // -------------------------------------------------------------------------
  factory MonthlySummaryModel.fromMap(Map<String, dynamic> map) {
    return MonthlySummaryModel(
      id: map['id'] as int?,
      year: map['year'] as int,
      month: map['month'] as int,
      totalIncome: (map['total_income'] as num?)?.toDouble() ?? 0.0,
      totalExpense: (map['total_expense'] as num?)?.toDouble() ?? 0.0,
      isMigrated: ((map['is_migrated'] as int?) ?? 0) == 1,
      calculatedAt: DateTime.parse(map['calculated_at'] as String),
    );
  }

  /// Серіалізація для збереження в SQLite.
  /// Поле `balance` виключається — у базі воно є VIRTUAL GENERATED.
  /// Якщо [id] == null, поле 'id' не включається (AUTOINCREMENT).
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'year': year,
      'month': month,
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'is_migrated': isMigrated ? 1 : 0,
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
  factory MonthlySummaryModel.fromJson(Map<String, dynamic> json) =>
      MonthlySummaryModel.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  /// Декодування з JSON-рядка
  factory MonthlySummaryModel.fromJsonString(String source) =>
      MonthlySummaryModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// Кодування до JSON-рядка
  String toJsonString() => jsonEncode(toJson());

  // -------------------------------------------------------------------------
  // copyWith — повертає новий незмінний екземпляр зі зміненими полями
  // -------------------------------------------------------------------------
  MonthlySummaryModel copyWith({
    int? id,
    int? year,
    int? month,
    double? totalIncome,
    double? totalExpense,
    bool? isMigrated,
    DateTime? calculatedAt,
  }) {
    return MonthlySummaryModel(
      id: id ?? this.id,
      year: year ?? this.year,
      month: month ?? this.month,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpense: totalExpense ?? this.totalExpense,
      isMigrated: isMigrated ?? this.isMigrated,
      calculatedAt: calculatedAt ?? this.calculatedAt,
    );
  }

  // -------------------------------------------------------------------------
  // Рівність та хеш-код
  // -------------------------------------------------------------------------
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MonthlySummaryModel &&
        other.id == id &&
        other.year == year &&
        other.month == month &&
        other.totalIncome == totalIncome &&
        other.totalExpense == totalExpense &&
        other.isMigrated == isMigrated &&
        other.calculatedAt == calculatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        year,
        month,
        totalIncome,
        totalExpense,
        isMigrated,
        calculatedAt,
      );

  @override
  String toString() {
    return 'MonthlySummaryModel('
        'id: $id, '
        'year: $year, '
        'month: $month, '
        'totalIncome: $totalIncome, '
        'totalExpense: $totalExpense, '
        'balance: $balance, '
        'isMigrated: $isMigrated, '
        'calculatedAt: $calculatedAt'
        ')';
  }
}
