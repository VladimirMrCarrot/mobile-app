// lib/providers/database_provider.dart
//
// Riverpod-провайдери для DatabaseHelper та всіх репозиторіїв.
//
// Ієрархія залежностей:
//   sharedPreferencesProvider  (override у main.dart)
//   databaseHelperProvider
//       ├─ cardRepositoryProvider
//       ├─ categoryRepositoryProvider
//       ├─ ruleRepositoryProvider
//       ├─ transactionRepositoryProvider
//       ├─ monthlySummaryRepositoryProvider
//       └─ importBatchRepositoryProvider

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database_helper.dart';
import '../data/models/card_model.dart';
import '../data/repositories/card_repository.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/rule_repository.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repositories/monthly_summary_repository.dart';
import '../data/repositories/import_batch_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SharedPreferences — overrideWithValue у main.dart
// ─────────────────────────────────────────────────────────────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main.dart'),
);

// ─────────────────────────────────────────────────────────────────────────────
// DatabaseHelper — єдиний синглтон
// ─────────────────────────────────────────────────────────────────────────────

/// Провайдер синглтона DatabaseHelper.
/// БД вже відкрита до запуску застосунку (в main.dart).
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

// ─────────────────────────────────────────────────────────────────────────────
// Репозиторії
// ─────────────────────────────────────────────────────────────────────────────

/// Репозиторій карток (cards).
final cardRepositoryProvider = Provider<CardRepository>((ref) {
  final db = ref.watch(databaseHelperProvider);
  return CardRepository(db);
});

/// Репозиторій категорій (categories).
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final db = ref.watch(databaseHelperProvider);
  return CategoryRepository(db);
});

/// Репозиторій правил категоризації (rules).
final ruleRepositoryProvider = Provider<RuleRepository>((ref) {
  final db = ref.watch(databaseHelperProvider);
  return RuleRepository(db);
});

/// Репозиторій транзакцій (transactions).
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(databaseHelperProvider);
  return TransactionRepository(db);
});

/// Репозиторій місячних зведень (monthly_summary + monthly_category_summary).
final monthlySummaryRepositoryProvider = Provider<MonthlySummaryRepository>((ref) {
  final db = ref.watch(databaseHelperProvider);
  return MonthlySummaryRepository(db);
});

/// Репозиторій пакетів імпорту (import_batches).
final importBatchRepositoryProvider = Provider<ImportBatchRepository>((ref) {
  final db = ref.watch(databaseHelperProvider);
  return ImportBatchRepository(db);
});

/// Усі картки (для екрана налаштувань).
final cardsListProvider = FutureProvider.autoDispose<List<CardModel>>((ref) async {
  return ref.watch(cardRepositoryProvider).getAll();
});
