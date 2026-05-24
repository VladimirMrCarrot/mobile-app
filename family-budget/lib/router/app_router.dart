// lib/router/app_router.dart
//
// Конфігурація навігації через GoRouter.
//
// Маршрути:
//   /            → DashboardScreen   (головна — зведення по місяцю)
//   /transactions → TransactionsScreen (список операцій)
//   /import      → ImportScreen      (імпорт файлу виписки)
//   /settings    → SettingsScreen    (налаштування, картки, правила)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/screens/dashboard/dashboard_screen.dart';
import '../ui/screens/import/import_screen.dart';
import '../ui/screens/settings/settings_screen.dart';
import '../ui/screens/transactions/transactions_screen.dart';
import '../ui/widgets/common/app_shell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Іменовані константи маршрутів
// ─────────────────────────────────────────────────────────────────────────────

abstract final class AppRoutes {
  static const String dashboard = '/';
  static const String transactions = '/transactions';
  static const String import = '/import';
  static const String settings = '/settings';
}

// ─────────────────────────────────────────────────────────────────────────────
// Провайдер роутера
// ─────────────────────────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    debugLogDiagnostics: false,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (context, state) => const NoTransitionPage<void>(
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.transactions,
            pageBuilder: (context, state) => const NoTransitionPage<void>(
              child: TransactionsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.import,
            pageBuilder: (context, state) => const NoTransitionPage<void>(
              child: ImportScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) => const NoTransitionPage<void>(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});
