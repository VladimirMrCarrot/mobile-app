// lib/services/parsers/privatbank_parser.dart
//
// Парсер XLSX-виписки Приватбанку.
// Картки: 5168****4428, 5169****3844, 4149****3336
//
// Структура файлу:
//   Аркуш: «Виписки»
//   Рядок 1: заголовок з датами ("Виписка за: 01.01.2026 – 12.04.2026")
//   Рядок 2: заголовки стовпців
//   Рядки 3+: транзакції
//
// Стовпці (0-indexed):
//   0  = Дата і час             — DateTime / String
//   1  = Картка                 — String  ('5168****4428')
//   2  = Категорія              — String  (власна категорія банку)
//   3  = Опис операції          — String
//   4  = Сума у валюті картки   — double  (від'ємна = витрата)
//   5  = Валюта картки          — String
//   6  = Сума в UAH             — double
//   7  = Залишок після операції — double
//
// Визначення внутрішнього переказу:
//   Приватбанк надійно позначає через bank_category:
//   'Перекази між своїми рахунками' або 'P2P' → is_internal = true
//
// Залежність: excel пакет (^4.0.3)

import 'dart:io';

import 'package:excel/excel.dart';
import 'package:family_budget/data/models/card_model.dart';

import 'bank_parser.dart';

class PrivatbankParser extends BankParser {
  static const String _sheetName = 'Виписки';
  static const int _dataStart = 2; // 0-indexed (рядок 3 у Excel)

  /// Категорії банку, що означають внутрішній переказ.
  static const Set<String> _internalCategories = {
    'Перекази між своїми рахунками',
    'P2P',
    'Переказ між рахунками',
  };

  final Set<String> ownCardNumbers;

  PrivatbankParser({required this.ownCardNumbers});

  @override
  BankSource get bank => BankSource.privatbank;

  // ─── canParse ─────────────────────────────────────────────────────────────

  @override
  Future<bool> canParse(File file) async =>
      file.path.toLowerCase().endsWith('.xlsx');

  // ─── parse ────────────────────────────────────────────────────────────────

  @override
  Future<ParseResult> parse(File file) async {
    if (!await canParse(file)) {
      throw ParseException('Файл не є XLSX', bank: bank);
    }

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    var sheet = excel.tables[_sheetName];
    if (sheet == null) {
      // Спробуємо перший доступний аркуш.
      final values = excel.tables.values;
      if (values.isEmpty) {
        throw ParseException(
          'Файл не містить аркушів. Переконайтесь що це виписка Приватбанку.',
          bank: bank,
        );
      }
      sheet = values.first;
    }

    return _parseSheet(sheet);
  }

  // ─── Парсинг аркуша ───────────────────────────────────────────────────────

  ParseResult _parseSheet(Sheet sheet) {
    final transactions = <ParsedTransaction>[];
    final errors = <ParseError>[];
    DateTime? periodStart;
    DateTime? periodEnd;

    final rows = sheet.rows;

    for (int rowIdx = _dataStart; rowIdx < rows.length; rowIdx++) {
      final row = rows[rowIdx];
      if (row.isEmpty) continue;

      // Перша клітинка повинна містити дату.
      final rawDate = _cellValue(row, 0);
      if (rawDate == null) continue;

      // Якщо це рядок-роздільник або підсумок (col 0 — рядок без дати) — пропускаємо.
      DateTime txDate;
      try {
        txDate = _parseDateTime(rawDate);
      } catch (_) {
        continue;
      }

      try {
        // Оновлюємо межі періоду.
        if (periodStart == null || txDate.isBefore(periodStart)) {
          periodStart = txDate;
        }
        if (periodEnd == null || txDate.isAfter(periodEnd)) {
          periodEnd = txDate;
        }

        final cardNumber = ParserUtils.cleanDescription(_cellStr(row, 1));
        final bankCategory = ParserUtils.cleanDescription(_cellStr(row, 2));
        final description = ParserUtils.cleanDescription(_cellStr(row, 3));
        final amountOrig = _cellDouble(row, 4) ?? 0.0;
        final currency = _parseCurrency(_cellStr(row, 5));
        final amountUah = _cellDouble(row, 6) ?? amountOrig;
        final balanceAfter = _cellDouble(row, 7);

        // Визначаємо курс конвертації.
        double? exchangeRate;
        if (currency != CurrencyType.uah && amountOrig.abs() > 0) {
          exchangeRate = amountUah.abs() / amountOrig.abs();
        }

        final txType = ParserUtils.txTypeFromAmount(amountUah);

        // Визначаємо внутрішній переказ через категорію банку.
        final isInternal = _isInternalTransfer(bankCategory, description);

        // Нормалізуємо номер картки (може бути у різних форматах).
        final normalizedCard = _normalizeCard(cardNumber);

        final dedupHash = ParserUtils.buildDedupHash(
          date: txDate,
          amountUah: amountUah,
          bank: bank,
          cardNumber: normalizedCard,
        );

        transactions.add(ParsedTransaction(
          txDate: txDate,
          amount: amountOrig,
          currency: currency,
          amountUah: amountUah,
          exchangeRate: exchangeRate,
          txType: txType,
          description: description.isEmpty ? bankCategory : description,
          bankCategory: bankCategory.isEmpty ? null : bankCategory,
          bank: bank,
          cardNumber: normalizedCard,
          balanceAfter: balanceAfter,
          isInternal: isInternal,
          dedupHash: dedupHash,
        ));
      } catch (e) {
        errors.add(ParseError(
          rowIndex: rowIdx + 1,
          rawValue: row.map((c) => c?.value?.toString() ?? '').join(' | '),
          reason: e.toString(),
        ));
      }
    }

    return ParseResult(
      transactions: transactions,
      errors: errors,
      periodStart: periodStart,
      periodEnd: periodEnd,
      cardNumber: null, // Файл містить кілька карток
    );
  }

  // ─── Визначення внутрішнього переказу ─────────────────────────────────────

  bool _isInternalTransfer(String bankCategory, String description) {
    // Надійний метод: категорія банку
    for (final cat in _internalCategories) {
      if (bankCategory.contains(cat)) return true;
    }
    // Резервний: власний номер картки в описі
    return ParserUtils.isInternalTransfer(
      description: description,
      bankRawType: bankCategory,
      ownCardNumbers: ownCardNumbers,
    );
  }

  // ─── Нормалізація номера картки ───────────────────────────────────────────

  /// Приводить номер картки до формату '5168****4428'.
  String _normalizeCard(String raw) {
    if (raw.isEmpty) return 'unknown';
    // Вже у форматі з зірочками — повертаємо як є.
    if (raw.contains('*')) return raw;
    // Повний номер: маскуємо середні 8 цифр.
    if (raw.length == 16) {
      return '${raw.substring(0, 4)}****${raw.substring(12)}';
    }
    return raw;
  }

  // ─── Допоміжні методи ─────────────────────────────────────────────────────

  dynamic _cellValue(List<Data?> row, int col) =>
      col < row.length ? row[col]?.value : null;

  String _cellStr(List<Data?> row, int col) =>
      col < row.length ? (row[col]?.value?.toString() ?? '') : '';

  double? _cellDouble(List<Data?> row, int col) {
    final v = _cellValue(row, col);
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.replaceAll(',', '.').replaceAll(' ', ''));
    }
    return null;
  }

  DateTime _parseDateTime(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is int) {
      // Excel serial date
      return DateTime(1899, 12, 30).add(Duration(days: raw));
    }
    if (raw is String) {
      final s = raw.trim();
      // 'DD.MM.YYYY HH:MM:SS'
      final parts = s.split(' ');
      final dateParts = parts[0].split('.');
      if (dateParts.length == 3) {
        final timeParts =
            parts.length > 1 ? parts[1].split(':') : ['0', '0', '0'];
        return DateTime(
          int.parse(dateParts[2]),
          int.parse(dateParts[1]),
          int.parse(dateParts[0]),
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
          timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
        );
      }
      return DateTime.parse(s);
    }
    throw FormatException('Не вдалося розпарсити дату: $raw');
  }

  CurrencyType _parseCurrency(String raw) {
    switch (raw.trim().toUpperCase()) {
      case 'USD':
        return CurrencyType.usd;
      case 'EUR':
        return CurrencyType.eur;
      default:
        return CurrencyType.uah;
    }
  }
}
