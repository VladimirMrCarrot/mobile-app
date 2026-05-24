// lib/data/repositories/rule_repository.dart
//
// Репозиторій правил автоматичної категоризації транзакцій.
// Містить логіку застосування правил та набір вбудованих системних правил.

import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import '../models/models.dart';

/// Репозиторій правил категоризації транзакцій.
/// Взаємодіє з таблицею [rules] через [DatabaseHelper].
class RuleRepository {
  final DatabaseHelper _db;

  RuleRepository(this._db);

  // ---------------------------------------------------------------------------
  // Назва таблиці
  // ---------------------------------------------------------------------------

  static const String _table = 'rules';

  // ---------------------------------------------------------------------------
  // Запити (читання)
  // ---------------------------------------------------------------------------

  /// Повертає всі правила. Якщо [activeOnly]=true — лише активні (is_active=1).
  /// Впорядковані за пріоритетом (від вищого до нижчого).
  Future<List<RuleModel>> getAll({bool activeOnly = true}) async {
    final db = await _db.database;

    final String? whereClause = activeOnly ? 'is_active = 1' : null;

    final rows = await db.query(
      _table,
      where: whereClause,
      orderBy: 'priority DESC, id ASC',
    );
    return rows.map(RuleModel.fromMap).toList();
  }

  /// Повертає активні правила для конкретного поля джерела ([SourceField]).
  Future<List<RuleModel>> getBySourceField(SourceField field) async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'source_field = ? AND is_active = 1',
      whereArgs: [field.toSqlValue()],
      orderBy: 'priority DESC, id ASC',
    );
    return rows.map(RuleModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // Команди (запис)
  // ---------------------------------------------------------------------------

  /// Вставляє нове правило та повертає його автоматично згенерований [id].
  Future<int> insert(RuleModel rule) async {
    final db = await _db.database;
    return await db.insert(
      _table,
      rule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  /// Оновлює існуюче правило та повертає кількість змінених рядків.
  Future<int> update(RuleModel rule) async {
    final db = await _db.database;
    return await db.update(
      _table,
      rule.toMap(),
      where: 'id = ?',
      whereArgs: [rule.id],
    );
  }

  /// Вмикає або вимикає правило за [id].
  /// Повертає кількість змінених рядків.
  Future<int> toggleActive(int id, bool active) async {
    final db = await _db.database;
    final now = DateTime.now().toUtc().toIso8601String();
    return await db.update(
      _table,
      {'is_active': active ? 1 : 0, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Видаляє правило за [id].
  /// Повертає [false] якщо правило є системним (is_system=1).
  /// Повертає [true] після успішного видалення.
  Future<bool> delete(int id) async {
    final db = await _db.database;

    // Перевіряємо, чи правило є системним.
    final rows = await db.query(
      _table,
      columns: ['is_system'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    if ((rows.first['is_system'] as int) == 1) return false;

    final affected = await db.delete(
      _table,
      where: 'id = ? AND is_system = 0',
      whereArgs: [id],
    );
    return affected > 0;
  }

  // ---------------------------------------------------------------------------
  // Логіка категоризації
  // ---------------------------------------------------------------------------

  /// Визначає категорію транзакції на основі активних правил.
  ///
  /// Алгоритм:
  /// 1. Завантажує активні правила, впорядковані за пріоритетом (DESC).
  /// 2. Для правил з source_field='description' перевіряє відповідність [description].
  /// 3. Для правил з source_field='bank_category' перевіряє відповідність [bankCategory].
  /// 4. Враховує обмеження типу транзакції ([txType]) якщо воно задане у правилі.
  /// 5. Повертає назву першої відповідної категорії, або null якщо нічого не знайдено.
  Future<String?> categorize({
    required String description,
    required TxType txType,
    String? bankCategory,
  }) async {
    // Завантажуємо усі активні правила, відсортовані за пріоритетом.
    final rules = await getAll(activeOnly: true);

    // Опрацьовуємо опис у верхньому регістрі для порівняння.
    final descUpper = description.toUpperCase();

    final txFilter = _txTypeToFilter(txType);

    for (final rule in rules) {
      // Перевіряємо відповідність типу транзакції (якщо задано у правилі).
      if (rule.txType != null && rule.txType != txFilter) {
        continue;
      }

      if (rule.sourceField == SourceField.description) {
        // Застосовуємо правило до поля [description].
        if (rule.matches(descUpper)) {
          return rule.categoryName;
        }
      } else if (rule.sourceField == SourceField.bankCategory) {
        // Застосовуємо правило до поля [bank_category].
        if (bankCategory != null && rule.matches(bankCategory)) {
          return rule.categoryName;
        }
      }
    }

    // Жодне правило не спрацювало — категорія не визначена.
    return null;
  }

  // ---------------------------------------------------------------------------
  // Початкові системні правила (seed)
  // ---------------------------------------------------------------------------

  /// Вставляє вбудований набір системних правил категоризації.
  /// Викликається з [DatabaseHelper._seedDefaults] при першому запуску.
  Future<void> seedDefaults(Database db) async {
    final now = DateTime.now().toUtc().toIso8601String();

    // Допоміжна функція для формування рядка правила.
    Map<String, dynamic> rule({
      required String keyword,
      required String categoryName,
      String matchType = 'contains',
      String sourceField = 'description',
      String? txType,
      int priority = 50,
    }) {
      return {
        'keyword': keyword,
        'match_type': matchType,
        'category_name': categoryName,
        'source_field': sourceField,
        'tx_type': txType,
        'priority': priority,
        'is_active': 1,
        'is_system': 1,
        'created_at': now,
        'updated_at': now,
      };
    }

    final rules = <Map<String, dynamic>>[
      // ----- Продукти -----
      rule(keyword: 'VARUS',      categoryName: 'Продукти'),
      rule(keyword: 'ATB',        categoryName: 'Продукти'),
      rule(keyword: 'ATB-MARKET', categoryName: 'Продукти'),
      rule(keyword: 'SILPO',      categoryName: 'Продукти'),
      rule(keyword: 'NOVUS',      categoryName: 'Продукти'),
      rule(keyword: 'METRO',      categoryName: 'Продукти'),
      rule(keyword: 'AUCHAN',     categoryName: 'Продукти'),
      rule(keyword: 'FORA',       categoryName: 'Продукти'),
      rule(keyword: 'TAVRIAV',    categoryName: 'Продукти'),
      rule(keyword: 'FOZZY',      categoryName: 'Продукти'),

      // ----- Комуналка -----
      rule(keyword: 'YASNO',               categoryName: 'Комуналка'),
      rule(keyword: 'Нафтогаз',            categoryName: 'Комуналка'),
      rule(keyword: 'Дніпроводоканал',     categoryName: 'Комуналка'),
      rule(keyword: 'Дніпротеплоенерго',   categoryName: 'Комуналка'),
      rule(keyword: 'Укртелеком',          categoryName: 'Комуналка'),
      rule(keyword: 'Київстар',            categoryName: 'Комуналка'),
      rule(keyword: 'Vodafone',            categoryName: 'Комуналка'),
      rule(keyword: 'Lifecell',            categoryName: 'Комуналка'),
      // bank_category → Комуналка
      rule(
        keyword: 'Комуналка та Інтернет',
        categoryName: 'Комуналка',
        matchType: 'exact',
        sourceField: 'bank_category',
      ),

      // ----- Таксі -----
      rule(keyword: 'UKLON',        categoryName: 'Таксі'),
      rule(keyword: 'IPAY.UA*UKLON',categoryName: 'Таксі'),
      rule(keyword: 'Bolt',         categoryName: 'Таксі'),
      rule(keyword: 'Uber',         categoryName: 'Таксі'),
      rule(keyword: 'PLATON',       categoryName: 'Таксі'),

      // ----- Здоров'я -----
      rule(keyword: 'iHerb',       categoryName: "Здоров'я"),
      rule(keyword: 'Med-Magazin', categoryName: "Здоров'я"),
      rule(keyword: 'АПТЕКА',      categoryName: "Здоров'я"),
      rule(keyword: 'APTEKA',      categoryName: "Здоров'я"),

      // ----- Косметика -----
      rule(keyword: 'BARPHEROMONES', categoryName: 'Косметика'),
      rule(keyword: 'BROCARD',       categoryName: 'Косметика'),
      rule(keyword: 'EVA',           categoryName: 'Косметика', matchType: 'exact'),
      rule(keyword: 'WATSONS',       categoryName: 'Косметика'),

      // ----- Відпочинок -----
      rule(keyword: 'Steam',       categoryName: 'Відпочинок'),
      rule(keyword: 'Netflix',     categoryName: 'Відпочинок'),
      rule(keyword: 'Megogo',      categoryName: 'Відпочинок'),
      rule(keyword: 'Spotify',     categoryName: 'Відпочинок'),
      rule(keyword: 'SWEET.TV',    categoryName: 'Відпочинок'),
      rule(keyword: 'PlayStation', categoryName: 'Відпочинок'),
      rule(keyword: 'Google Play', categoryName: 'Відпочинок'),
      // bank_category → Відпочинок
      rule(
        keyword: 'Кіно',
        categoryName: 'Відпочинок',
        matchType: 'exact',
        sourceField: 'bank_category',
      ),
      rule(
        keyword: 'Розваги',
        categoryName: 'Відпочинок',
        matchType: 'exact',
        sourceField: 'bank_category',
      ),

      // ----- Освіта -----
      rule(keyword: 'Perplexity', categoryName: 'Освіта'),
      rule(keyword: 'ChatGPT',    categoryName: 'Освіта'),
      rule(keyword: 'Chat GPT',   categoryName: 'Освіта'),
      rule(keyword: 'OPENAI',     categoryName: 'Освіта'),
      rule(keyword: 'Coursera',   categoryName: 'Освіта'),
      rule(keyword: 'Udemy',      categoryName: 'Освіта'),
      rule(keyword: 'Prometheus', categoryName: 'Освіта'),
      rule(keyword: 'Duolingo',   categoryName: 'Освіта'),

      // ----- Кредит -----
      rule(keyword: 'WAYFORPAY',          categoryName: 'Кредит'),
      rule(keyword: 'Кредит ПриватБанк',  categoryName: 'Кредит'),
      rule(
        keyword: 'Кредити',
        categoryName: 'Кредит',
        matchType: 'exact',
        sourceField: 'bank_category',
      ),

      // ----- ЗП (зарахування заробітної плати) -----
      rule(
        keyword: 'FUIB MoneyTransfer',
        categoryName: 'ЗП',
        txType: 'income',
      ),
      rule(
        keyword: 'Зарахування переказу',
        categoryName: 'ЗП',
        matchType: 'exact',
        sourceField: 'bank_category',
        txType: 'income',
        priority: 30,
      ),
    ];

    // Вставляємо всі правила з ігноруванням дублікатів.
    for (final r in rules) {
      await db.insert(
        _table,
        r,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }
}

/// Відповідність [TxType] до [TxTypeFilter] у правилах (transfer → немає фільтра).
TxTypeFilter? _txTypeToFilter(TxType txType) {
  switch (txType) {
    case TxType.income:
      return TxTypeFilter.income;
    case TxType.expense:
      return TxTypeFilter.expense;
    case TxType.transfer:
      return null;
  }
}
