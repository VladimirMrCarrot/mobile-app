// lib/ui/screens/dashboard/dashboard_screen.dart
//
// Головний екран — місячне зведення.
// Показує:
//   - Перемикач місяців (< MM YYYY >)
//   - Картка Income / Expense / Balance
//   - Кругова діаграма витрат по категоріях (fl_chart)
//   - Список категорій за витратами

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../providers/providers.dart';
import '../../../theme/app_theme.dart';
import '../../../data/models/monthly_summary_model.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final summary = ref.watch(monthlySummaryProvider);

    final monthLabel = DateFormat('LLLL yyyy', 'uk').format(month);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сімейний бюджет'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Попередній місяць',
            onPressed: () {
              ref.read(selectedMonthProvider.notifier).state =
                  DateTime(month.year, month.month - 1);
            },
          ),
          Center(
            child: Text(
              monthLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Наступний місяць',
            onPressed: () {
              final next = DateTime(month.year, month.month + 1);
              if (next.isBefore(DateTime(
                DateTime.now().year,
                DateTime.now().month + 1,
              ))) {
                ref.read(selectedMonthProvider.notifier).state = next;
              }
            },
          ),
          const Gap(8),
        ],
      ),
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Помилка: $e',
            style: const TextStyle(color: AppColors.expense),
          ),
        ),
        data: (s) => _DashboardBody(summary: s, month: month),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  final MonthlySummaryModel? summary;
  final DateTime month;

  const _DashboardBody({required this.summary, required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt =
        NumberFormat.currency(locale: 'uk', symbol: '₴', decimalDigits: 2);
    final breakdownAsync = ref.watch(categoryBreakdownProvider);

    final sm = summary;
    if (sm == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 64, color: AppColors.textDisabled),
            const Gap(16),
            Text(
              'Даних за цей місяць немає.\nІмпортуйте виписку або додайте операцію.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SummaryCard(
                label: 'Доходи',
                amount: fmt.format(sm.totalIncome),
                color: AppColors.income,
              ),
              const Gap(12),
              _SummaryCard(
                label: 'Витрати',
                amount: fmt.format(sm.totalExpense),
                color: AppColors.expense,
              ),
              const Gap(12),
              _SummaryCard(
                label: 'Баланс',
                amount: fmt.format(sm.balance),
                color: sm.balance >= 0 ? AppColors.income : AppColors.expense,
              ),
            ],
          ),
          const Gap(24),
          Text(
            'Витрати по категоріях',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Gap(12),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'fl_chart — кругова діаграма\n(реалізація у наступній ітерації)',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
          const Gap(24),
          Text(
            'Розбивка по категоріях',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Gap(12),
          breakdownAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              'Помилка: $e',
              style: const TextStyle(color: AppColors.expense),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const Text(
                  'Немає даних по категоріях за цей місяць.',
                  style: TextStyle(color: AppColors.textSecondary),
                );
              }
              return Column(
                children: rows.map((r) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r.categoryName),
                    trailing: Text(
                      fmt.format(r.total),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const Gap(6),
              Text(
                amount,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
