// lib/providers/summary_provider.dart
//
// Riverpod-провайдери для місячних та річних зведень.
//
// monthlySummaryProvider       — MonthlySummaryModel? за вибраний місяць
// yearSummaryProvider          — список MonthlySummaryModel за рік
// selectedYearProvider         — поточно вибраний рік (для річного огляду)
// categoryBreakdownProvider    — список MonthlyCategorySummaryModel за місяць
// migrationCompletedProvider   — чи завершена міграція з Nash-biudzhet.xlsx

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/monthly_summary_model.dart';
import '../data/models/monthly_category_summary_model.dart';
import 'database_provider.dart';
import 'transaction_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Міграція (SharedPreferences)
// ─────────────────────────────────────────────────────────────────────────────

/// Чи завершена міграція даних з Nash-biudzhet.xlsx.
final migrationCompletedProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool('migration_completed') ?? false;
});

// ─────────────────────────────────────────────────────────────────────────────
// Вибраний рік
// ─────────────────────────────────────────────────────────────────────────────

/// Поточно вибраний рік для річного огляду.
final selectedYearProvider = StateProvider<int>((ref) => DateTime.now().year);

// ─────────────────────────────────────────────────────────────────────────────
// Місячне зведення
// ─────────────────────────────────────────────────────────────────────────────

/// Зведення (income/expense/balance) за вибраний місяць.
/// Може бути null, якщо даних ще немає.
final monthlySummaryProvider =
    FutureProvider.autoDispose<MonthlySummaryModel?>((ref) async {
  final month = ref.watch(selectedMonthProvider);
  final repo = ref.watch(monthlySummaryRepositoryProvider);

  return repo.getByMonth(month.year, month.month);
});

// ─────────────────────────────────────────────────────────────────────────────
// Зведення по категоріях за місяць
// ─────────────────────────────────────────────────────────────────────────────

/// Список [MonthlyCategorySummaryModel] за вибраний місяць,
/// відсортований за total DESC.
final categoryBreakdownProvider =
    FutureProvider.autoDispose<List<MonthlyCategorySummaryModel>>((ref) async {
  final month = ref.watch(selectedMonthProvider);
  final repo = ref.watch(monthlySummaryRepositoryProvider);

  return repo.getCategoryBreakdown(month.year, month.month);
});

// ─────────────────────────────────────────────────────────────────────────────
// Річне зведення
// ─────────────────────────────────────────────────────────────────────────────

/// Список місячних зведень за весь вибраний рік (12 або менше елементів).
final yearSummaryProvider =
    FutureProvider.autoDispose<List<MonthlySummaryModel>>((ref) async {
  final year = ref.watch(selectedYearProvider);
  final repo = ref.watch(monthlySummaryRepositoryProvider);

  return repo.getByYear(year);
});

/// Загальний дохід за рік.
final yearTotalIncomeProvider = FutureProvider.autoDispose<double>((ref) async {
  final summaries = await ref.watch(yearSummaryProvider.future);
  return summaries.fold<double>(
    0.0,
    (sum, MonthlySummaryModel s) => sum + s.totalIncome,
  );
});

/// Загальні витрати за рік.
final yearTotalExpenseProvider = FutureProvider.autoDispose<double>((ref) async {
  final summaries = await ref.watch(yearSummaryProvider.future);
  return summaries.fold<double>(
    0.0,
    (sum, MonthlySummaryModel s) => sum + s.totalExpense,
  );
});

/// Баланс за рік (дохід − витрати).
final yearBalanceProvider = FutureProvider.autoDispose<double>((ref) async {
  final income = await ref.watch(yearTotalIncomeProvider.future);
  final expense = await ref.watch(yearTotalExpenseProvider.future);
  return income - expense;
});
