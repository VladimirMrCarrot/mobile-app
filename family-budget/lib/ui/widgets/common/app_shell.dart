// lib/ui/widgets/common/app_shell.dart
//
// Shell-контейнер із BottomNavigationBar.
// Відображається на всіх основних екранах (dashboard, transactions, import, settings).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../router/app_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  // Список вкладок у тому ж порядку, що й маршрути в GoRouter
  static const _tabs = [
    _TabItem(
      icon: Icons.dashboard_rounded,
      label: 'Зведення',
      path: AppRoutes.dashboard,
    ),
    _TabItem(
      icon: Icons.list_alt_rounded,
      label: 'Операції',
      path: AppRoutes.transactions,
    ),
    _TabItem(
      icon: Icons.upload_file_rounded,
      label: 'Імпорт',
      path: AppRoutes.import,
    ),
    _TabItem(
      icon: Icons.settings_rounded,
      label: 'Налаштування',
      path: AppRoutes.settings,
    ),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _tabs.length; i++) {
      if (location == _tabs[i].path) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIdx = _currentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIdx,
        onTap: (idx) {
          if (idx != currentIdx) {
            context.go(_tabs[idx].path);
          }
        },
        items: _tabs
            .map(
              (tab) => BottomNavigationBarItem(
                icon: Icon(tab.icon),
                label: tab.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  final String path;
  const _TabItem({
    required this.icon,
    required this.label,
    required this.path,
  });
}
