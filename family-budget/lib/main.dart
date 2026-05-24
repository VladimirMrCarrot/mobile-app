// lib/main.dart
//
// Точка входу застосунку.
// Порядок ініціалізації:
//   1. WidgetsFlutterBinding.ensureInitialized()
//   2. SharedPreferences — зчитати флаг migration_completed
//   3. DatabaseHelper.instance.database — відкрити / мігрувати БД
//   4. ProviderScope — увесь застосунок загорнутий у провайдер

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/database_helper.dart';
import 'providers/database_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  final db = DatabaseHelper.instance;
  await db.database;

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const BudgetApp(),
    ),
  );
}
