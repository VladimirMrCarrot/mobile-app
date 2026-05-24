# Статус проєкту «Сімейний бюджет»

**Оновлено:** 24.05.2026  
**Репозиторій:** `family_budget`  
**Специфікація:** [MASTER.md](./MASTER.md)

---

## 1. Що вже зроблено

### 1.1 Каркас застосунку (Flutter scaffold)

- **Точка входу** — `lib/main.dart`: ініціалізація `SharedPreferences`, відкриття SQLite через `DatabaseHelper`, запуск `ProviderScope` + `BudgetApp`.
- **Кореневий віджет** — `lib/app.dart`: `BudgetApp` (`ConsumerWidget`) з `MaterialApp.router`, темною темою, локалізацією `uk_UA`.
- **Навігація** — `lib/router/app_router.dart`: GoRouter + `ShellRoute`, 4 маршрути:
  - `/` — Dashboard
  - `/transactions` — Операції
  - `/import` — Імпорт виписки
  - `/settings` — Налаштування
- **Тема** — `lib/theme/app_theme.dart`: `AppColors`, `CategoryColors`, light/dark теми.
- **Оболонка UI** — `lib/ui/widgets/common/app_shell.dart`: нижня навігація.

### 1.2 Data layer

- **SQLite** — `lib/data/database_helper.dart` (singleton `DatabaseHelper.instance`), DDL у `schema_statements.dart`.
- **Моделі** — 8 моделей у `lib/data/models/` (транзакції, картки, категорії, правила, активи, імпорт-батчі, місячні зведення).
- **Репозиторії** — CRUD і аналітика в `lib/data/repositories/`.

### 1.3 Сервіси та парсери

- **ImportService** — `lib/services/import_service.dart`.
- **Парсери банків:**
  - ПУМБ PDF — `pumb_parser.dart`
  - Monobank XLS/XLSX — `monobank_parser.dart`
  - Приватбанк XLSX — `privatbank_parser.dart`
- **Виправлення PUMB-парсера:** дата проведення (`YYYY-MM-DD`) більше не трактується як початок нового блоку транзакції; старт блоку — `date` + наступний рядок з `time`. Перевірено на 3 тестових транзакціях (`transactions=3`, `errors=0`).

### 1.4 Riverpod-провайдери

- `database_provider.dart` — БД, `SharedPreferences`.
- `transaction_provider.dart`, `import_provider.dart`, `summary_provider.dart`.
- `migrationCompletedProvider` — читає прапорець `migration_completed` з `SharedPreferences`.

### 1.5 UI-екрани (базова реалізація)

| Екран | Файл | Стан |
|-------|------|------|
| Dashboard | `dashboard_screen.dart` | Перемикач місяця, картки дохід/витрата/баланс, розбивка по категоріях; placeholder для діаграми |
| Операції | `transactions_screen.dart` | Список транзакцій |
| Імпорт | `import_screen.dart` | Вибір файлу, прев'ю, імпорт |
| Налаштування | `settings_screen.dart` | Міграція xlsx, картки, правила (частина — заглушки/навігація) |

### 1.6 Виправлення багів з MASTER.md §12.1 (частково закрито)

| # | Проблема | Статус |
|---|----------|--------|
| 1 | `ImportStatus.rolledBack.value` → `.toSqlValue()` | ✅ Виправлено |
| 2 | Імпорт неіснуючого `enums.dart` у репозиторіях | ✅ Enum-и в model-файлах |
| 3 | `DatabaseHelper.instance` відсутній | ✅ Додано singleton |
| 4 | `.value` замість `.toSqlValue()` у repo | ✅ Виправлено в згаданих місцях |
| 5 | `migrationCompletedProvider` відсутній | ✅ Реалізовано в `summary_provider.dart` |

### 1.7 Тести (останнє — widget smoke test)

**Проблема:** шаблонний `test/widget_test.dart` посилався на `MyApp`, якого в проєкті немає → помилка компіляції *«The name 'MyApp' isn't a class.»*

**Виправлення** (лише `test/widget_test.dart`):

- Імпорт `BudgetApp` з `package:family_budget/app.dart`.
- Обгортка `ProviderScope` + override `sharedPreferencesProvider`.
- `SharedPreferences.setMockInitialValues({})` у тесті.
- Smoke assertion: на екрані є заголовок **«Сімейний бюджет»** (початковий маршрут Dashboard).

**Результат:**

```text
flutter test test/widget_test.dart
00:01 +1: All tests passed!
```

---

## 2. Що виявили під час роботи

### 2.1 Архітектура тестів vs production

- У `main.dart` перед `runApp` відкривається реальна БД (`await db.database`). У widget-тесті це **не викликається** — тест pump-ить лише `BudgetApp` + Riverpod overrides.
- Для smoke-тесту достатньо `sharedPreferencesProvider`; dashboard рендериться навіть без явної ініціалізації БД у тесті.
- Якщо тести почнуть перевіряти дані з SQLite, знадобляться додаткові overrides або in-memory БД (поки не реалізовано).

### 2.2 Flutter-only залежності в парсерах

- `dart test` напряму не підходить для парсерів з `syncfusion_flutter_pdf` — потрібен `flutter test`.
- Тимчасовий `test/pumb_parser_test.dart` використовувався для відладки PUMB і був видалений після фіксу; **постійного unit-тест шару для парсерів немає**.

### 2.3 Незавершені / stub-файли

| Файл | Стан |
|------|------|
| `lib/services/xlsx_migration_service.dart` | Лише `// TODO` — логіка міграції Nash-biudzhet.xlsx не реалізована |
| `lib/data/database_helper.dart` | TODO: `ALTER TABLE` при bump версії БД |
| `README.md` | Стандартний Flutter template, не описує проєкт |

### 2.4 Технічний борг (з MASTER.md §12.3, актуальний)

- `dynamic` у частині UI (`import_screen`, `dashboard_screen`, `transactions_screen`).
- Моделі без `freezed` / `build_runner` (свідомо відкладено).
- **Тестовий шар мінімальний** — один widget smoke test; unit/integration тестів немає.
- Placeholder для `fl_chart` на Dashboard.

---

## 3. Заплановано далі

### 3.1 UI / функціональність (v1.1+, з MASTER.md §12.2)

- [ ] Кругова діаграма витрат (`fl_chart`) на Dashboard
- [ ] `CardsScreen` — CRUD карток
- [ ] `RulesScreen` — CRUD правил категоризації
- [ ] Форма ручного додавання транзакції
- [ ] Редагування категорії транзакції (tap у списку)
- [ ] `XlsxMigrationService` + кнопка міgraції в Settings
- [ ] `AssetsScreen` — активи та депозити
- [ ] Валютний калькулятор для ручного введення курсу
- [ ] Фільтр транзакцій по картці (ChipRow)
- [ ] UI для річного огляду (`yearSummaryProvider` уже є)

### 3.2 Технічні покращення

- [ ] Замінити `dynamic` на конкретні моделі в UI
- [ ] Пагінація в `MonthlySummaryRepository.recalculate()` при >10k транзакцій
- [ ] Міграції схеми БД (`onUpgrade` з ALTER TABLE)
- [ ] Розширити тестовий шар:
  - unit-тести парсерів (PUMB, Monobank, Приватбанк) через `flutter test`
  - widget-тести ключових екранів (Import, Transactions)
  - integration-тести з in-memory SQLite (за потреби)

### 3.3 Найближчі практичні кроки (рекомендований порядок)

1. **Закріпити парсери** — постійні тест-файли в `test/parsers/` з фікстурами з MASTER.md (Додаток D).
2. **Реалізувати `XlsxMigrationService`** — blocker для повноцінного Settings → «Міграція Nash-biudzhet.xlsx».
3. **Додати `fl_chart`** на Dashboard — закрити найпомітніший UI-placeholder.
4. **CardsScreen + RulesScreen** — завершити CRUD, на який уже є навігація з Settings.
5. **Оновити README.md** — короткий опис проєкту, запуск, тести, підтримувані банки.

---

## 4. Як запускати

```bash
# Застосунок
flutter run

# Widget smoke test
flutter test test/widget_test.dart

# Аналіз коду
dart analyze lib/
```

---

## 5. Контекст (коротко)

- Приватний сімейний бюджет для **2 користувачів**; дані **лише локально** (SQLite).
- Банки: **ПУМБ (PDF)**, **Monobank (XLS/XLSX)**, **Приватбанк (XLSX)**.
- 22 фіксовані категорії; детальна специфікація — у [MASTER.md](./MASTER.md), розділи 1–12.
