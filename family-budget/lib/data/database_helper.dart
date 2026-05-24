// lib/data/database_helper.dart
//
// Singleton-клас для управління SQLite базою даних бюджетного додатку.
// Використовує пакет sqflite. Без кодогенерації.
//
// Повна DDL (таблиці, seed INSERT OR IGNORE, індекси, тригери, views) —
// див. `schema_statements.dart` (РОЗДІЛ 2 `schema.sql` у MASTER.md).

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'schema_statements.dart';

/// Singleton для відкриття та управління SQLite базою даних `family_budget.db`.
class DatabaseHelper {
  /// Єдиний екземпляр класу (singleton pattern).
  static final DatabaseHelper instance = DatabaseHelper._internal();

  /// Фабричний конструктор повертає єдиний екземпляр.
  factory DatabaseHelper() => instance;

  DatabaseHelper._internal();

  // Кешований об'єкт бази даних.
  Database? _database;

  /// Назва файлу бази даних.
  static const String _dbName = 'family_budget.db';

  /// Поточна версія схеми.
  static const int _dbVersion = 1;

  // ---------------------------------------------------------------------------
  // Публічний геттер бази даних
  // ---------------------------------------------------------------------------

  /// Повертає відкриту базу даних, ліниво ініціалізуючи її при першому зверненні.
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  // ---------------------------------------------------------------------------
  // Ініціалізація
  // ---------------------------------------------------------------------------

  /// Відкриває або створює файл бази даних і виконує міграції.
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final filePath = p.join(dbPath, _dbName);

    return openDatabase(
      filePath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      singleInstance: true,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
    );
  }

  // ---------------------------------------------------------------------------
  // onCreate — повне створення схеми
  // ---------------------------------------------------------------------------

  /// Виконується при першому створенні бази даних.
  /// Створює всі таблиці, індекси, тригери, views та початкові дані (seed).
  Future<void> _onCreate(Database db, int version) async {
    for (final stmt in kSchemaStatements) {
      await db.execute(stmt);
    }
  }

  // ---------------------------------------------------------------------------
  // onUpgrade — заглушка для майбутніх міграцій
  // ---------------------------------------------------------------------------

  /// Виконується при оновленні версії схеми.
  /// Наразі є заглушкою — конкретні міграції додаються при збільшенні [_dbVersion].
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // TODO(dev): Додати ALTER TABLE / нові таблиці при переході між версіями.
    // Наприклад:
    // if (oldVersion < 2) { await db.execute('ALTER TABLE cards ADD COLUMN ...'); }
  }

  // ---------------------------------------------------------------------------
  // Службові методи
  // ---------------------------------------------------------------------------

  /// Повністю видаляє та перестворює базу даних.
  /// Використовується лише під час розробки та тестування.
  Future<void> clearAndReset() async {
    final db = await database;

    await db.execute('PRAGMA foreign_keys = OFF;');

    // Views залежать від таблиць — прибираємо перед DROP TABLE.
    await db.execute('DROP VIEW IF EXISTS v_transactions;');
    await db.execute('DROP VIEW IF EXISTS v_monthly_totals;');

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';",
    );

    for (final row in tables) {
      final tableName = row['name'] as String;
      await db.execute('DROP TABLE IF EXISTS "$tableName";');
    }

    final indexes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%';",
    );
    for (final row in indexes) {
      final indexName = row['name'] as String;
      await db.execute('DROP INDEX IF EXISTS "$indexName";');
    }

    await db.execute('PRAGMA foreign_keys = ON;');
    await _onCreate(db, _dbVersion);
  }

  /// Повертає поточну версію схеми з PRAGMA user_version.
  Future<int> getSchemaVersion() async {
    final db = await database;
    final result = await db.rawQuery('PRAGMA user_version;');
    return result.first['user_version'] as int? ?? 0;
  }
}
