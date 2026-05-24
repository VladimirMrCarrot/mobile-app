// lib/app.dart
//
// Кореневий віджет застосунку.
// Налаштовує MaterialApp.router з:
//   - GoRouter (визначений у router/app_router.dart)
//   - темною темою (AppTheme.dark)
//   - локалізацією uk_UA

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class BudgetApp extends ConsumerWidget {
  const BudgetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Сімейний бюджет',
      debugShowCheckedModeBanner: false,

      // ── Тема ───────────────────────────────────────────────────────────────
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,

      // ── Навігація ──────────────────────────────────────────────────────────
      routerConfig: router,

      // ── Локалізація ────────────────────────────────────────────────────────
      locale: const Locale('uk', 'UA'),
      supportedLocales: const [
        Locale('uk', 'UA'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
