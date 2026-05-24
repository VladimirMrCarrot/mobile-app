// Smoke test for the real app root (BudgetApp + Riverpod).

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:family_budget/app.dart';
import 'package:family_budget/providers/database_provider.dart';

void main() {
  testWidgets('BudgetApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const BudgetApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Сімейний бюджет'), findsOneWidget);
  });
}
