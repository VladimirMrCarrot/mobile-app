// lib/data/repositories/category_repository.dart
//
// Репозиторій для роботи з категоріями транзакцій.
// Системні категорії (is_system=1) не можна видаляти.

import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import '../models/models.dart';

/// Репозиторій категорій транзакцій.
/// Взаємодіє з таблицею [categories] через [DatabaseHelper].
class CategoryRepository {
  final DatabaseHelper _db;

  CategoryRepository(this._db);

  // ---------------------------------------------------------------------------
  // Назва таблиці
  // ---------------------------------------------------------------------------

  static const String _table = 'categories';

  // ---------------------------------------------------------------------------
  // Запити (читання)
  // ---------------------------------------------------------------------------

  /// Повертає всі категорії. Якщо [visibleOnly]=true — лише видимі (is_visible=1).
  /// Впорядковані за [sort_order], потім за назвою.
  Future<List<CategoryModel>> getAll({bool visibleOnly = false}) async {
    final db = await _db.database;

    final String? whereClause = visibleOnly ? 'is_visible = 1' : null;

    final rows = await db.query(
      _table,
      where: whereClause,
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(CategoryModel.fromMap).toList();
  }

  /// Повертає категорію за унікальною назвою, або null якщо не знайдено.
  Future<CategoryModel?> getByName(String name) async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'name = ?',
      whereArgs: [name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CategoryModel.fromMap(rows.first);
  }

  /// Повертає всі категорії заданого типу ([CategoryType.income] або [CategoryType.expense]).
  Future<List<CategoryModel>> getByType(CategoryType type) async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'type = ?',
      whereArgs: [type.toSqlValue()],
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(CategoryModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // Команди (запис)
  // ---------------------------------------------------------------------------

  /// Вставляє нову категорію та повертає її автоматично згенерований [id].
  Future<int> insert(CategoryModel cat) async {
    final db = await _db.database;
    return await db.insert(
      _table,
      cat.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Оновлює існуючу категорію та повертає кількість змінених рядків.
  Future<int> update(CategoryModel cat) async {
    final db = await _db.database;
    return await db.update(
      _table,
      cat.toMap(),
      where: 'name = ?',
      whereArgs: [cat.name],
    );
  }

  /// Видаляє категорію за назвою.
  /// Повертає [false] якщо категорія є системною (is_system=1) — видалення заборонено.
  /// Повертає [true] після успішного видалення.
  Future<bool> delete(String name) async {
    // Спочатку перевіряємо, чи є категорія системною.
    final existing = await getByName(name);
    if (existing == null) {
      // Категорія не існує — нічого видаляти.
      return false;
    }
    if (existing.isSystem) {
      // Системні категорії не можна видаляти.
      return false;
    }

    final db = await _db.database;
    final affected = await db.delete(
      _table,
      where: 'name = ? AND is_system = 0',
      whereArgs: [name],
    );
    return affected > 0;
  }
}
