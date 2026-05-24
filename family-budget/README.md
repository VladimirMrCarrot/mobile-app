# family_budget

Flutter-застосунок для ведення сімейного бюджету: імпорт банківських виписок (Monobank, ПУМБ, Приватбанк), SQLite, дашборд, транзакції, налаштування.

## Init artifact

Початкова специфікація та scaffold згенеровані з **`MASTER.md`** (локальний init-артефакт, ~828 KB, не в репозиторії). Містить PRD, DDL, парсери та Flutter scaffold v1.0 (12.04.2026).

## Stack

- Flutter / Dart ^3.11
- Riverpod, go_router, sqflite
- file_picker, excel, syncfusion_flutter_pdf

## Run

```bash
cd family-budget
flutter pub get
flutter run
```

iOS: `cd ios && pod install && cd ..`
