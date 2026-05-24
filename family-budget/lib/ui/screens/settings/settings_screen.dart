// lib/ui/screens/settings/settings_screen.dart
//
// Екран налаштувань.
//   - Міграція Nash-biudzhet.xlsx (перемикач)
//   - Картки
//   - Категорії

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/providers.dart';
import '../../../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final migrationDone = ref.watch(migrationCompletedProvider);
    final cardsAsync = ref.watch(cardsListProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Налаштування')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: Icon(
              migrationDone ? Icons.check_circle : Icons.hourglass_empty,
              color: migrationDone ? AppColors.income : AppColors.textSecondary,
            ),
            title: const Text('Міграція Nash-biudzhet.xlsx'),
            subtitle: Text(
              migrationDone ? 'Завершена' : 'Не виконана',
              style: TextStyle(
                color:
                    migrationDone ? AppColors.income : AppColors.textSecondary,
              ),
            ),
            value: migrationDone,
            onChanged: (v) async {
              final prefs = ref.read(sharedPreferencesProvider);
              await prefs.setBool('migration_completed', v);
              ref.invalidate(migrationCompletedProvider);
            },
          ),
          const Divider(),
          _SectionHeader('Картки'),
          cardsAsync.when(
            loading: () => const ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Завантаження карток…'),
            ),
            error: (e, _) => ListTile(
              leading: const Icon(Icons.error_outline, color: AppColors.expense),
              title: Text('Помилка: $e'),
            ),
            data: (cards) {
              if (cards.isEmpty) {
                return const ListTile(
                  title: Text('Карток ще немає'),
                  subtitle: Text('З’являться після імпорту виписок'),
                );
              }
              return Column(
                children: cards
                    .map(
                      (c) => ListTile(
                        leading: const Icon(Icons.credit_card_outlined),
                        title: Text(c.displayName ?? c.cardNumber),
                        subtitle: Text('${c.bank.toSqlValue()} · ${c.cardNumber}'),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.credit_card_outlined),
            title: const Text('Управління картками'),
            subtitle: const Text('ПУМБ, Monobank, Приватбанк'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Буде реалізовано в наступній ітерації'),
                ),
              );
            },
          ),
          const Divider(),
          _SectionHeader('Категоризація'),
          categoriesAsync.when(
            loading: () => const ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Завантаження категорій…'),
            ),
            error: (e, _) => ListTile(
              leading: const Icon(Icons.error_outline, color: AppColors.expense),
              title: Text('Помилка: $e'),
            ),
            data: (cats) => Column(
              children: cats
                  .map(
                    (c) => ListTile(
                      leading: Icon(
                        c.isVisible ? Icons.label : Icons.label_outline,
                        color: AppColors.textSecondary,
                      ),
                      title: Text(c.name),
                      subtitle: Text(c.type.toSqlValue()),
                    ),
                  )
                  .toList(),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.rule_outlined),
            title: const Text('Правила категоризації'),
            subtitle: const Text('Автоматичне призначення категорій'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Буде реалізовано в наступній ітерації'),
                ),
              );
            },
          ),
          const Divider(),
          _SectionHeader('Про застосунок'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Сімейний бюджет'),
            subtitle: Text('v1.0.0 · Flutter · SQLite · Riverpod'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}
