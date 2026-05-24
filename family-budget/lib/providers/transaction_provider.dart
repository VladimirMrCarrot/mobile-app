// lib/providers/transaction_provider.dart
//
// Riverpod-провайдери для транзакцій.
//
// selectedMonthProvider        — поточно вибраний місяць (DateTime, day=1)
// selectedCategoryIdProvider   — фільтр за категорією (nullable)
// transactionsByMonthProvider  — список TransactionModel за місяць
// transactionListProvider      — той самий список + пошук за описом
// transactionStatsProvider     — дохід / витрати / баланс за місяць
// categoryTotalsProvider       — Map<int, double> categoryId→sumUah за місяць

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/category_model.dart';
import '../data/models/transaction_model.dart';
import 'database_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Фільтри
// ─────────────────────────────────────────────────────────────────────────────

/// Поточно вибраний місяць для відображення (перший день місяця).
/// За замовчуванням — поточний місяць.
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// Вибрана категорія для фільтрації транзакцій (null = всі категорії).
final selectedCategoryIdProvider = StateProvider<int?>((ref) => null);

/// Усі категорії (фільтри, діалог редагування).
final categoriesListProvider =
    FutureProvider.autoDispose<List<CategoryModel>>((ref) async {
  return ref.watch(categoryRepositoryProvider).getAll();
});

// ─────────────────────────────────────────────────────────────────────────────
// Список транзакцій за місяць
// ─────────────────────────────────────────────────────────────────────────────

/// Транзакції за вибраний місяць (з урахуванням фільтру за категорією).
final transactionsByMonthProvider =
    FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  final month = ref.watch(selectedMonthProvider);
  final categoryId = ref.watch(selectedCategoryIdProvider);
  final txRepo = ref.watch(transactionRepositoryProvider);
  final catRepo = ref.watch(categoryRepositoryProvider);

  if (categoryId != null) {
    final cats = await catRepo.getAll();
    CategoryModel? match;
    for (final c in cats) {
      if (c.id == categoryId) {
        match = c;
        break;
      }
    }
    if (match != null) {
      return txRepo.getByCategory(
        match.name,
        year: month.year,
        month: month.month,
      );
    }
  }

  return txRepo.getByMonth(month.year, month.month);
});

// ─────────────────────────────────────────────────────────────────────────────
// Суми по категоріях за місяць
// ─────────────────────────────────────────────────────────────────────────────

/// Суми витрат по кожній категорії за вибраний місяць.
/// Ключ — categoryId, значення — сума UAH (тільки expense).
final categoryTotalsProvider =
    FutureProvider.autoDispose<Map<int, double>>((ref) async {
  final month = ref.watch(selectedMonthProvider);
  final txRepo = ref.watch(transactionRepositoryProvider);
  final catRepo = ref.watch(categoryRepositoryProvider);

  final raw = await txRepo.getCategoryTotals(month.year, month.month);
  final cats = await catRepo.getAll();

  final byName = {for (final c in cats) c.name: c};
  final result = <int, double>{};

  for (final e in raw.entries) {
    final cat = byName[e.key];
    if (cat?.id != null) {
      result[cat!.id!] = e.value;
    }
  }
  return result;
});

// ─────────────────────────────────────────────────────────────────────────────
// Пошук транзакцій
// ─────────────────────────────────────────────────────────────────────────────

/// Рядок пошуку для фільтрації транзакцій за описом.
final transactionSearchQueryProvider = StateProvider<String>((ref) => '');

/// Список транзакцій за місяць/категорію з урахуванням пошуку за [description].
final transactionListProvider =
    FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  final query = ref.watch(transactionSearchQueryProvider).trim().toLowerCase();
  final all = await ref.watch(transactionsByMonthProvider.future);

  if (query.isEmpty) return all;

  return all
      .where((tx) => tx.description.toLowerCase().contains(query))
      .toList();
});

/// Транзакції відфільтровані за рядком пошуку (autoDispose).
/// Еквівалент [transactionListProvider].
final filteredTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  return ref.watch(transactionListProvider.future);
});

// ─────────────────────────────────────────────────────────────────────────────
// Статистика за місяць
// ─────────────────────────────────────────────────────────────────────────────

/// Агреговані суми доходів і витрат за вибраний місяць.
class TransactionStats {
  final double totalIncome;
  final double totalExpense;

  const TransactionStats({
    required this.totalIncome,
    required this.totalExpense,
  });

  double get balance => totalIncome - totalExpense;
}

final transactionStatsProvider =
    FutureProvider.autoDispose<TransactionStats>((ref) async {
  final month = ref.watch(selectedMonthProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  final income = await repo.getMonthIncome(month.year, month.month);
  final expense = await repo.getMonthExpense(month.year, month.month);
  return TransactionStats(totalIncome: income, totalExpense: expense);
});
