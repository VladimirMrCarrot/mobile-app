// lib/ui/screens/transactions/transactions_screen.dart
//
// Екран списку операцій за місяць.
// Функціональність:
//   - Фільтр за категорією (ChipRow)
//   - Пошуковий рядок
//   - ListView транзакцій із датою, описом, сумою, банком
//   - Діалог редагування категорії

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../data/models/card_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../providers/providers.dart';
import '../../../theme/app_theme.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionListProvider);
    final query = ref.watch(transactionSearchQueryProvider);
    final selectedCategoryId = ref.watch(selectedCategoryIdProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Операції'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: categoriesAsync.when(
                  loading: () => const SizedBox(height: 40),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (cats) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('Усі'),
                          selected: selectedCategoryId == null,
                          onSelected: (_) {
                            ref.read(selectedCategoryIdProvider.notifier).state =
                                null;
                          },
                        ),
                        const Gap(8),
                        ...cats.map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(c.name),
                              selected: selectedCategoryId == c.id,
                              onSelected: (_) {
                                ref
                                    .read(selectedCategoryIdProvider.notifier)
                                    .state = c.id;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Пошук за описом...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => ref
                      .read(transactionSearchQueryProvider.notifier)
                      .state = v,
                ),
              ),
            ],
          ),
        ),
      ),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Помилка: $e',
            style: const TextStyle(color: AppColors.expense),
          ),
        ),
        data: (txList) {
          if (txList.isEmpty) {
            return Center(
              child: Text(
                query.isEmpty ? 'Немає операцій за цей місяць' : 'Нічого не знайдено',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          return ListView.separated(
            itemCount: txList.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, idx) {
              final tx = txList[idx];
              final fmt = NumberFormat.currency(locale: 'uk', symbol: '₴');
              final isIncome = tx.txType == TxType.income;

              return ListTile(
                onTap: () => _showEditCategoryDialog(context, ref, tx),
                leading: CircleAvatar(
                  backgroundColor: isIncome
                      ? AppColors.income.withValues(alpha: 0.15)
                      : AppColors.expense.withValues(alpha: 0.15),
                  child: Icon(
                    isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isIncome ? AppColors.income : AppColors.expense,
                    size: 18,
                  ),
                ),
                title: Text(
                  tx.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text(
                  DateFormat('dd.MM.yyyy', 'uk').format(tx.txDate),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Text(
                  '${isIncome ? '+' : '-'}${fmt.format(tx.amountUah.abs())}',
                  style: TextStyle(
                    color: isIncome ? AppColors.income : AppColors.expense,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

Future<void> _showEditCategoryDialog(
  BuildContext context,
  WidgetRef ref,
  TransactionModel tx,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return Consumer(
        builder: (ctx, ref, _) {
          final async = ref.watch(categoriesListProvider);
          return async.when(
            loading: () => const AlertDialog(
              content: SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, _) => AlertDialog(
              title: const Text('Помилка'),
              content: Text('$e'),
            ),
            data: (categories) {
              final names = categories.map((c) => c.name).toList();
              final current = tx.categoryName;
              final value = current != null && names.contains(current)
                  ? current
                  : (names.isNotEmpty ? names.first : null);

              return AlertDialog(
                title: const Text('Змінити категорію'),
                content: DropdownButton<String>(
                  value: value,
                  isExpanded: true,
                  items: categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.name,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    await ref
                        .read(transactionRepositoryProvider)
                        .updateCategory(tx.id, v);
                    ref.invalidate(transactionListProvider);
                    ref.invalidate(transactionsByMonthProvider);
                    ref.invalidate(filteredTransactionsProvider);
                    ref.invalidate(categoryTotalsProvider);
                    ref.invalidate(monthlySummaryProvider);
                    ref.invalidate(categoryBreakdownProvider);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              );
            },
          );
        },
      );
    },
  );
}
