// lib/data/repositories/monthly_summary_repository.dart
//
// Репозиторій щомісячних підсумків: доходи, витрати та розбивка по категоріях.
// Підтримує перерахунок із транзакцій та міграцію історичних даних.

import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import '../models/models.dart';

/// Репозиторій щомісячних підсумків.
/// Взаємодіє з таблицями [monthly_summary] та [monthly_category_summary].
class MonthlySummaryRepository {
  final DatabaseHelper _db;

  MonthlySummaryRepository(this._db);

  // ---------------------------------------------------------------------------
  // Назви таблиць
  // ---------------------------------------------------------------------------

  static const String _summaryTable  = 'monthly_summary';
  static const String _categoryTable = 'monthly_category_summary';

  // ---------------------------------------------------------------------------
  // Запити (читання)
  // ---------------------------------------------------------------------------

  /// Повертає підсумок за вказаний місяць, або null якщо запис відсутній.
  Future<MonthlySummaryModel?> getByMonth(int year, int month) async {
    final db = await _db.database;
    final rows = await db.query(
      _summaryTable,
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MonthlySummaryModel.fromMap(rows.first);
  }

  /// Повертає всі підсумки за вказаний рік, впорядковані за місяцем (зростання).
  Future<List<MonthlySummaryModel>> getByYear(int year) async {
    final db = await _db.database;
    final rows = await db.query(
      _summaryTable,
      where: 'year = ?',
      whereArgs: [year],
      orderBy: 'month ASC',
    );
    return rows.map(MonthlySummaryModel.fromMap).toList();
  }

  /// Повертає всі наявні щомісячні підсумки, від нових до старих.
  Future<List<MonthlySummaryModel>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(
      _summaryTable,
      orderBy: 'year DESC, month DESC',
    );
    return rows.map(MonthlySummaryModel.fromMap).toList();
  }

  /// Повертає збережені підсумки по категоріях за місяць ([monthly_category_summary]).
  /// Впорядковано за [total] спадно.
  Future<List<MonthlyCategorySummaryModel>> getCategoryBreakdown(
    int year,
    int month,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      _categoryTable,
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
      orderBy: 'total DESC',
    );
    return rows.map(MonthlyCategorySummaryModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // Перерахунок
  // ---------------------------------------------------------------------------

  /// Перераховує підсумок доходів і витрат за місяць із таблиці [transactions]
  /// та зберігає результат у [monthly_summary] (INSERT OR REPLACE).
  ///
  /// Враховуються лише не видалені, не внутрішні транзакції.
  /// Повертає оновлену або щойно створену модель.
  Future<MonthlySummaryModel> recalculate(int year, int month) async {
    final db = await _db.database;

    final yearStr  = year.toString().padLeft(4, '0');
    final monthStr = month.toString().padLeft(2, '0');

    // Підраховуємо суми з таблиці транзакцій за вказаний місяць.
    final rows = await db.rawQuery(
      '''
      SELECT
        SUM(CASE WHEN tx_type = 'income'  THEN amount_uah ELSE 0 END) AS income,
        SUM(CASE WHEN tx_type = 'expense' THEN amount_uah ELSE 0 END) AS expense
      FROM transactions
      WHERE strftime('%Y', tx_date) = ?
        AND strftime('%m', tx_date) = ?
        AND is_deleted  = 0
        AND is_internal = 0
      ''',
      [yearStr, monthStr],
    );

    final totalIncome  = (rows.first['income']  as num?)?.toDouble() ?? 0.0;
    final totalExpense = (rows.first['expense'] as num?)?.toDouble() ?? 0.0;
    final calculatedAt = DateTime.now().toUtc().toIso8601String();

    // Формуємо модель із розрахованими значеннями.
    final summary = MonthlySummaryModel(
      year: year,
      month: month,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      isMigrated: false,
      calculatedAt: DateTime.now().toUtc(),
    );

    // Вставляємо або замінюємо існуючий запис.
    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO $_summaryTable
        (year, month, total_income, total_expense, is_migrated, calculated_at)
      VALUES (?, ?, ?, ?, 0, ?)
      ''',
      [year, month, totalIncome, totalExpense, calculatedAt],
    );

    return summary;
  }

  /// Вставляє мігрований підсумок із зовнішнього джерела (наприклад, xlsx).
  /// Позначає запис як мігрований ([is_migrated]=1).
  Future<void> insertMigrated(MonthlySummaryModel summary) async {
    final db = await _db.database;
    await db.rawInsert(
      '''
      INSERT OR REPLACE INTO $_summaryTable
        (year, month, total_income, total_expense, is_migrated, calculated_at)
      VALUES (?, ?, ?, ?, 1, ?)
      ''',
      [
        summary.year,
        summary.month,
        summary.totalIncome,
        summary.totalExpense,
        summary.calculatedAt.toUtc().toIso8601String(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Розбивка по категоріях
  // ---------------------------------------------------------------------------

  /// Перераховує та зберігає підсумки витрат по категоріях за вказаний місяць.
  ///
  /// Видаляє попередні записи за цей місяць та вставляє свіжі дані
  /// з таблиці [transactions].
  Future<void> recalculateCategoryBreakdown(int year, int month) async {
    final db = await _db.database;

    final yearStr  = year.toString().padLeft(4, '0');
    final monthStr = month.toString().padLeft(2, '0');
    final calculatedAt = DateTime.now().toUtc().toIso8601String();

    // Отримуємо агреговані суми по категоріях.
    final rows = await db.rawQuery(
      '''
      SELECT
        COALESCE(category_name, 'Без категорії') AS category_name,
        SUM(amount_uah)                           AS total,
        COUNT(*)                                  AS tx_count
      FROM transactions
      WHERE strftime('%Y', tx_date) = ?
        AND strftime('%m', tx_date) = ?
        AND is_deleted  = 0
        AND is_internal = 0
      GROUP BY category_name
      ''',
      [yearStr, monthStr],
    );

    // Оновлення виконуємо в одній транзакції бази даних.
    await db.transaction((txn) async {
      // Видаляємо старі записи за цей місяць.
      await txn.delete(
        _categoryTable,
        where: 'year = ? AND month = ?',
        whereArgs: [year, month],
      );

      // Вставляємо свіжі агреговані дані.
      for (final row in rows) {
        final categoryName = row['category_name'] as String;
        final total    = (row['total']    as num?)?.toDouble() ?? 0.0;
        final txCount  = (row['tx_count'] as int?) ?? 0;

        await txn.insert(
          _categoryTable,
          {
            'year':          year,
            'month':         month,
            'category_name': categoryName,
            'total':         total,
            'tx_count':      txCount,
            'calculated_at': calculatedAt,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
