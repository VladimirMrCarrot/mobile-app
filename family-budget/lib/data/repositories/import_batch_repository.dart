// lib/data/repositories/import_batch_repository.dart
//
// Репозиторій пакетів імпорту банківських виписок.
// Підтримує відкочування (rollback) із м'яким видаленням транзакцій.

import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import '../models/models.dart';
import 'transaction_repository.dart';

/// Репозиторій пакетів імпорту банківських виписок.
/// Взаємодіє з таблицею [import_batches] через [DatabaseHelper].
class ImportBatchRepository {
  final DatabaseHelper _db;

  ImportBatchRepository(this._db);

  // ---------------------------------------------------------------------------
  // Назва таблиці
  // ---------------------------------------------------------------------------

  static const String _table = 'import_batches';

  // ---------------------------------------------------------------------------
  // Запити (читання)
  // ---------------------------------------------------------------------------

  /// Повертає пакет імпорту за унікальним [id], або null якщо не знайдено.
  Future<ImportBatchModel?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ImportBatchModel.fromMap(rows.first);
  }

  /// Повертає всі пакети імпорту, впорядковані від нових до старих.
  Future<List<ImportBatchModel>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      orderBy: 'imported_at DESC',
    );
    return rows.map(ImportBatchModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // Команди (запис)
  // ---------------------------------------------------------------------------

  /// Вставляє новий запис пакету імпорту.
  Future<void> insert(ImportBatchModel batch) async {
    final db = await _db.database;
    await db.insert(
      _table,
      batch.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Оновлює статус пакету імпорту за [id].
  Future<void> updateStatus(String id, ImportStatus status) async {
    final db = await _db.database;
    await db.update(
      _table,
      {'status': status.toSqlValue()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // Відкочування (rollback)
  // ---------------------------------------------------------------------------

  /// Відкочує пакет імпорту:
  /// 1. М'яко видаляє всі транзакції з [import_batch_id] = [batchId].
  /// 2. Позначає сам пакет як [ImportStatus.rolledBack].
  ///
  /// Операція виконується атомарно в межах однієї транзакції бази даних.
  Future<void> rollback(String batchId, TransactionRepository txRepo) async {
    final db = await _db.database;

    await db.transaction((txn) async {
      // М'яко видаляємо всі транзакції цього пакету.
      final now = DateTime.now().toUtc().toIso8601String();
      await txn.update(
        'transactions',
        {'is_deleted': 1, 'updated_at': now},
        where: 'import_batch_id = ?',
        whereArgs: [batchId],
      );

      // Позначаємо пакет як відкочений.
      await txn.update(
        _table,
        {'status': ImportStatus.rolledBack.toSqlValue()},
        where: 'id = ?',
        whereArgs: [batchId],
      );
    });
  }
}
