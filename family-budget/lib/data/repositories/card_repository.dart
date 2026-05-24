// lib/data/repositories/card_repository.dart
//
// Репозиторій для роботи з банківськими картками.
// Надає повний CRUD + upsert + оновлення балансу.

import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import '../models/models.dart';

/// Репозиторій банківських карток.
/// Взаємодіє з таблицею [cards] через [DatabaseHelper].
class CardRepository {
  final DatabaseHelper _db;

  CardRepository(this._db);

  // ---------------------------------------------------------------------------
  // Назва таблиці
  // ---------------------------------------------------------------------------

  static const String _table = 'cards';

  // ---------------------------------------------------------------------------
  // Запити (читання)
  // ---------------------------------------------------------------------------

  /// Повертає всі картки, впорядковані за [sort_order], потім за активністю.
  Future<List<CardModel>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      orderBy: 'sort_order ASC, is_active DESC',
    );
    return rows.map(CardModel.fromMap).toList();
  }

  /// Повертає картку за її унікальним [id], або null якщо не знайдено.
  Future<CardModel?> getById(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CardModel.fromMap(rows.first);
  }

  /// Повертає картку за типом банку та номером картки, або null якщо не знайдено.
  Future<CardModel?> getByBankAndNumber(BankType bank, String cardNumber) async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'bank = ? AND card_number = ?',
      whereArgs: [bank.toSqlValue(), cardNumber],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CardModel.fromMap(rows.first);
  }

  // ---------------------------------------------------------------------------
  // Команди (запис)
  // ---------------------------------------------------------------------------

  /// Вставляє нову картку та повертає її автоматично згенерований [id].
  Future<int> insert(CardModel card) async {
    final db = await _db.database;
    return await db.insert(
      _table,
      card.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Оновлює існуючу картку та повертає кількість змінених рядків.
  Future<int> update(CardModel card) async {
    final db = await _db.database;
    return await db.update(
      _table,
      card.toMap(),
      where: 'id = ?',
      whereArgs: [card.id],
    );
  }

  /// М'яко деактивує картку (встановлює [is_active]=0).
  /// Повертає кількість змінених рядків.
  Future<int> softDeactivate(int id) async {
    final db = await _db.database;
    final now = DateTime.now().toUtc().toIso8601String();
    return await db.update(
      _table,
      {'is_active': 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Вставляє картку, або оновлює її якщо вже існує за (bank, card_number).
  /// Повертає модель з актуальним [id].
  Future<CardModel> upsert(CardModel card) async {
    final db = await _db.database;

    // Перевіряємо наявність існуючого запису.
    final existing = await getByBankAndNumber(
      card.bank,
      card.cardNumber,
    );

    if (existing == null) {
      // Картка не існує — виконуємо INSERT.
      final newId = await db.insert(
        _table,
        card.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return card.copyWith(id: newId);
    } else {
      // Картка існує — виконуємо UPDATE з актуальними даними.
      final updated = card.copyWith(
        id: existing.id,
        updatedAt: DateTime.now().toUtc(),
      );
      await db.update(
        _table,
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return updated;
    }
  }

  /// Оновлює баланс картки та час останнього оновлення балансу.
  Future<void> updateBalance(int id, double balance) async {
    final db = await _db.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      _table,
      {
        'balance': balance,
        'balance_updated_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
