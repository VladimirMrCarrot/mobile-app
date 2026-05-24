// lib/data/repositories/transaction_repository.dart
//
// Репозиторій транзакцій: запити, пакетний імпорт із дедублікацією, агрегати.

import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import '../models/models.dart';

// ---------------------------------------------------------------------------
// Допоміжний клас результату пакетного імпорту
// ---------------------------------------------------------------------------

/// Результат пакетного імпорту транзакцій.
class ImportResult {
  /// Кількість успішно імпортованих транзакцій.
  final int imported;

  /// Кількість пропущених дублікатів (знайдено збіг по dedup_hash).
  final int skippedDup;

  /// Кількість пропущених внутрішніх переказів (is_internal=1).
  final int skippedInternal;

  /// Кількість транзакцій, що призвели до помилки під час вставки.
  final int errors;

  const ImportResult({
    required this.imported,
    required this.skippedDup,
    required this.skippedInternal,
    required this.errors,
  });

  /// Загальна кількість оброблених транзакцій.
  int get total => imported + skippedDup + skippedInternal + errors;

  @override
  String toString() =>
      'ImportResult(imported: $imported, skippedDup: $skippedDup, '
      'skippedInternal: $skippedInternal, errors: $errors, total: $total)';
}

// ---------------------------------------------------------------------------
// TransactionRepository
// ---------------------------------------------------------------------------

/// Репозиторій транзакцій.
/// Взаємодіє з таблицею [transactions] через [DatabaseHelper].
class TransactionRepository {
  final DatabaseHelper _db;

  TransactionRepository(this._db);

  // ---------------------------------------------------------------------------
  // Назва таблиці
  // ---------------------------------------------------------------------------

  static const String _table = 'transactions';

  // ---------------------------------------------------------------------------
  // Запити (читання)
  // ---------------------------------------------------------------------------

  /// Повертає всі не видалені, не внутрішні транзакції за вказаний місяць.
  /// Впорядковані за датою транзакції (від новіших до старіших).
  Future<List<TransactionModel>> getByMonth(int year, int month) async {
    final db = await _db.database;

    // Форматуємо рік та місяць для порівняння з strftime.
    final yearStr = year.toString().padLeft(4, '0');
    final monthStr = month.toString().padLeft(2, '0');

    final rows = await db.rawQuery(
      '''
      SELECT * FROM $_table
      WHERE strftime('%Y', tx_date) = ?
        AND strftime('%m', tx_date) = ?
        AND is_deleted  = 0
        AND is_internal = 0
      ORDER BY tx_date DESC
      ''',
      [yearStr, monthStr],
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  /// Повертає транзакції за категорією.
  /// Опційно можна обмежити рік та місяць.
  Future<List<TransactionModel>> getByCategory(
    String categoryName, {
    int? year,
    int? month,
  }) async {
    final db = await _db.database;

    // Базові умови фільтрації.
    final conditions = <String>[
      'category_name = ?',
      'is_deleted = 0',
    ];
    final args = <dynamic>[categoryName];

    // Додаємо фільтр за роком якщо задано.
    if (year != null) {
      conditions.add("strftime('%Y', tx_date) = ?");
      args.add(year.toString().padLeft(4, '0'));
    }

    // Додаємо фільтр за місяцем якщо задано.
    if (month != null) {
      conditions.add("strftime('%m', tx_date) = ?");
      args.add(month.toString().padLeft(2, '0'));
    }

    final rows = await db.query(
      _table,
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'tx_date DESC',
    );
    return rows.map(TransactionModel.fromMap).toList();
  }

  /// Повертає транзакцію за унікальним [id], або null якщо не знайдено.
  Future<TransactionModel?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TransactionModel.fromMap(rows.first);
  }

  /// Перевіряє наявність транзакції за хешем дедублікації.
  /// Повертає [true] якщо хеш вже існує серед не видалених записів.
  Future<bool> dedupExists(String hash) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT 1 FROM $_table WHERE dedup_hash = ? AND is_deleted = 0 LIMIT 1',
      [hash],
    );
    return rows.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Команди (запис)
  // ---------------------------------------------------------------------------

  /// Вставляє одну транзакцію. Кидає [DatabaseException] при конфлікті dedup_hash.
  Future<void> insert(TransactionModel tx) async {
    final db = await _db.database;
    await db.insert(
      _table,
      tx.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Пакетний імпорт транзакцій із автоматичною дедублікацією.
  ///
  /// Для кожної транзакції:
  /// - Якщо [is_internal]=true — пропускається як внутрішній переказ.
  /// - Якщо [dedup_hash] вже існує — пропускається як дублікат.
  /// - Інакше вставляється в базу; помилки записуються в лічильник [errors].
  ///
  /// Повертає [ImportResult] із детальною статистикою.
  Future<ImportResult> insertBatch(
    List<TransactionModel> txs,
    String batchId,
  ) async {
    int imported = 0;
    int skippedDup = 0;
    int skippedInternal = 0;
    int errors = 0;

    final db = await _db.database;

    // Виконуємо всі операції в межах однієї транзакції бази даних.
    await db.transaction((txn) async {
      for (final tx in txs) {
        try {
          // Пропускаємо внутрішні перекази.
          if (tx.isInternal) {
            skippedInternal++;
            continue;
          }

          // Перевіряємо дублікат за хешем дедублікації.
          if (tx.dedupHash != null) {
            final rows = await txn.rawQuery(
              'SELECT 1 FROM $_table WHERE dedup_hash = ? AND is_deleted = 0 LIMIT 1',
              [tx.dedupHash],
            );
            if (rows.isNotEmpty) {
              skippedDup++;
              continue;
            }
          }

          // Вставляємо транзакцію.
          await txn.insert(
            _table,
            tx.toMap(),
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
          imported++;
        } catch (_) {
          // Фіксуємо помилку та продовжуємо обробку наступних транзакцій.
          errors++;
        }
      }
    });

    return ImportResult(
      imported: imported,
      skippedDup: skippedDup,
      skippedInternal: skippedInternal,
      errors: errors,
    );
  }

  /// Оновлює категорію транзакції за [id].
  /// Повертає кількість змінених рядків.
  Future<int> updateCategory(String id, String? categoryName) async {
    final db = await _db.database;
    final now = DateTime.now().toUtc().toIso8601String();
    return await db.update(
      _table,
      {'category_name': categoryName, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// М'яко видаляє транзакцію (встановлює [is_deleted]=1).
  /// Повертає кількість змінених рядків.
  Future<int> softDelete(String id) async {
    final db = await _db.database;
    final now = DateTime.now().toUtc().toIso8601String();
    return await db.update(
      _table,
      {'is_deleted': 1, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Відкочує (скасовує) пакет імпорту: встановлює [is_deleted]=1 для всіх
  /// транзакцій, що належать до вказаного [importBatchId].
  /// Повертає кількість змінених рядків.
  Future<int> restoreBatch(String importBatchId) async {
    final db = await _db.database;
    final now = DateTime.now().toUtc().toIso8601String();
    return await db.update(
      _table,
      {'is_deleted': 1, 'updated_at': now},
      where: 'import_batch_id = ?',
      whereArgs: [importBatchId],
    );
  }

  // ---------------------------------------------------------------------------
  // Агрегати
  // ---------------------------------------------------------------------------

  /// Повертає суму витрат по категоріях за вказаний місяць.
  /// Ключ — назва категорії, значення — сума в гривнях ([amount_uah]).
  Future<Map<String, double>> getCategoryTotals(int year, int month) async {
    final db = await _db.database;

    final yearStr = year.toString().padLeft(4, '0');
    final monthStr = month.toString().padLeft(2, '0');

    final rows = await db.rawQuery(
      '''
      SELECT category_name, SUM(amount_uah) AS total
      FROM $_table
      WHERE strftime('%Y', tx_date) = ?
        AND strftime('%m', tx_date) = ?
        AND tx_type    = 'expense'
        AND is_deleted  = 0
        AND is_internal = 0
      GROUP BY category_name
      ''',
      [yearStr, monthStr],
    );

    // Перетворюємо результат у Map<String, double>.
    final result = <String, double>{};
    for (final row in rows) {
      final categoryName = row['category_name'] as String? ?? 'Без категорії';
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      result[categoryName] = total;
    }
    return result;
  }

  /// Повертає загальну суму надходжень за вказаний місяць (у гривнях).
  Future<double> getMonthIncome(int year, int month) async {
    final db = await _db.database;

    final yearStr = year.toString().padLeft(4, '0');
    final monthStr = month.toString().padLeft(2, '0');

    final rows = await db.rawQuery(
      '''
      SELECT SUM(amount_uah) AS total
      FROM $_table
      WHERE strftime('%Y', tx_date) = ?
        AND strftime('%m', tx_date) = ?
        AND tx_type    = 'income'
        AND is_deleted  = 0
        AND is_internal = 0
      ''',
      [yearStr, monthStr],
    );

    return (rows.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Повертає загальну суму витрат за вказаний місяць (у гривнях).
  Future<double> getMonthExpense(int year, int month) async {
    final db = await _db.database;

    final yearStr = year.toString().padLeft(4, '0');
    final monthStr = month.toString().padLeft(2, '0');

    final rows = await db.rawQuery(
      '''
      SELECT SUM(amount_uah) AS total
      FROM $_table
      WHERE strftime('%Y', tx_date) = ?
        AND strftime('%m', tx_date) = ?
        AND tx_type    = 'expense'
        AND is_deleted  = 0
        AND is_internal = 0
      ''',
      [yearStr, monthStr],
    );

    return (rows.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
