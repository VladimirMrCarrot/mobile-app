// lib/ui/screens/import/import_screen.dart
//
// Екран імпорту банківської виписки.
// Функціональність:
//   - Кнопка "Обрати файл" (FilePicker)
//   - Індикатор прогресу під час імпорту
//   - Картка з результатами ImportReport
//   - Кнопка "Скасувати імпорт" (rollback)
//   - Список останніх імпортів

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../data/models/import_batch_model.dart';
import '../../../providers/providers.dart';
import '../../../services/import_service.dart';
import '../../../theme/app_theme.dart';

class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importState = ref.watch(importFileProvider);
    final historyAsync = ref.watch(importHistoryProvider);
    final isLoading = importState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Імпорт виписки')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: isLoading
                  ? null
                  : () => ref.read(importFileProvider.notifier).pickAndImport(),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Обрати файл (PDF / XLS / XLSX)'),
            ),
            const Gap(16),
            if (isLoading) ...[
              const LinearProgressIndicator(),
              const Gap(8),
              const Text(
                'Обробка файлу...',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
            if (importState.hasError)
              _ErrorCard(message: importState.error.toString()),
            if (importState.hasValue && importState.value != null)
              _ImportReportCard(
                report: importState.value!,
                onRollback: () => ref
                    .read(importFileProvider.notifier)
                    .rollback(importState.value!.batchId),
              ),
            const Gap(24),
            Text(
              'Історія імпортів',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Gap(12),
            historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorCard(message: e.toString()),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Text(
                      'Імпортів ще не було',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return Column(
                  children: list
                      .map((batch) => _ImportBatchTile(batch: batch))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportReportCard extends StatelessWidget {
  final ImportReport report;
  final VoidCallback onRollback;

  const _ImportReportCard({required this.report, required this.onRollback});

  @override
  Widget build(BuildContext context) {
    final hasWarnings = report.hasWarnings;

    return Card(
      color: hasWarnings
          ? AppColors.transfer.withValues(alpha: 0.1)
          : AppColors.income.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasWarnings
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_rounded,
                  color: hasWarnings ? AppColors.transfer : AppColors.income,
                ),
                const Gap(8),
                Text(
                  hasWarnings ? 'Імпорт з попередженнями' : 'Імпорт успішний',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const Gap(12),
            _ReportRow('Банк', report.bank.toSqlValue()),
            _ReportRow('Файл', report.fileName),
            _ReportRow('Розпізнано', '${report.parsedTotal}'),
            _ReportRow('Імпортовано', '${report.imported}'),
            _ReportRow('Дублікати', '${report.skippedDup}'),
            _ReportRow('Внутр. перекази', '${report.skippedInternal}'),
            _ReportRow('Без категорії', '${report.uncategorized}'),
            _ReportRow('Тривалість', '${report.duration.inMilliseconds} мс'),
            const Gap(12),
            OutlinedButton.icon(
              onPressed: onRollback,
              icon: const Icon(Icons.undo, color: AppColors.expense),
              label: const Text(
                'Скасувати імпорт',
                style: TextStyle(color: AppColors.expense),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.expense),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReportRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ImportBatchTile extends StatelessWidget {
  final ImportBatchModel batch;

  const _ImportBatchTile({required this.batch});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy HH:mm', 'uk');

    return ListTile(
      leading: const Icon(Icons.history, color: AppColors.textSecondary),
      title: Text(
        batch.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        fmt.format(batch.importedAt),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: Text(
        batch.status.toSqlValue(),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.expense.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.expense),
            const Gap(12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.expense),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
