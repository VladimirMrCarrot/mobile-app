// lib/services/parsers/monobank_parser.dart
//
// Парсер XLS-виписки Monobank.
// Картка: 4441****4491
// IBAN: UA193220010000026209300479632
//
// Структура файлу:
//   Аркуш: «Рух коштів по картці»
//   Рядки 1-21: метадані (номер картки, IBAN, тощо)
//   Рядок 22: заголовки стовпців
//   Рядки 23+: транзакції (10 стовпців A-J)
//
// Стовпці (0-indexed):
//   A(0) = Дата і час операції    — DateTime
//   B(1) = Деталі операції        — String (опис мерчанта)
//   C(2) = MCC                    — int
//   D(3) = Валюта картки          — String ('UAH')
//   E(4) = Сума в валюті картки   — double (від'ємна = витрата)
//   F(5) = Операційна сума        — double
//   G(6) = Операційна валюта      — String
//   H(7) = Курс                   — double (або 1 якщо UAH)
//   I(8) = Сума комісій           — double
//   J(9) = Сума кешбеку           — double
//   K(10) = Залишок               — double
//
// Залежність: excel пакет (^4.0.3) для читання XLS.

import 'dart:io';

import 'package:excel/excel.dart';
import 'package:family_budget/data/models/card_model.dart';

import 'bank_parser.dart';

class MonobankParser extends BankParser {
  static const String _cardNumber = '4441****4491';
  static const String _ibanValue = 'UA193220010000026209300479632';
  static const String _sheetName = 'Рух коштів по картці';
  static const int _headerRow = 21; // 0-indexed (рядок 22 у Excel = індекс 21)
  static const int _dataStart = 22; // перший рядок даних

  final Set<String> ownCardNumbers;

  MonobankParser({required this.ownCardNumbers});

  @override
  BankSource get bank => BankSource.monobank;

  // ─── canParse ─────────────────────────────────────────────────────────────

  @override
  Future<bool> canParse(File file) async {
    final ext = file.path.toLowerCase();
    return ext.endsWith('.xls') || ext.endsWith('.xlsx');
  }

  // ─── parse ────────────────────────────────────────────────────────────────

  @override
  Future<ParseResult> parse(File file) async {
    if (!await canParse(file)) {
      throw ParseException('Файл не є XLS/XLSX', bank: bank);
    }

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    final sheet = excel.tables[_sheetName];
    if (sheet == null) {
      throw ParseException(
        'Аркуш "$_sheetName" не знайдено. '
        'Переконайтесь що це виписка Monobank.',
        bank: bank,
      );
    }

    return _parseSheet(sheet);
  }

  // ─── Парсинг аркуша ───────────────────────────────────────────────────────

  ParseResult _parseSheet(Sheet sheet) {
    final transactions = <ParsedTransaction>[];
    final errors = <ParseError>[];
    DateTime? periodStart;
    DateTime? periodEnd;

    // Зчитуємо номер картки з метаданих (рядки 1-21).
    final detectedCard = _extractCardNumber(sheet) ?? _cardNumber;

    final rows = sheet.rows;

    for (int rowIdx = _dataStart; rowIdx < rows.length; rowIdx++) {
      final row = rows[rowIdx];
      if (row.isEmpty) continue;

      // Перевіряємо що перша клітинка містить дату.
      final rawDate = _cellValue(row, 0);
      if (rawDate == null) continue;

      try {
        final txDate = _parseDateTime(rawDate);

        // Оновлюємо межі періоду.
        if (periodStart == null || txDate.isBefore(periodStart)) {
          periodStart = txDate;
        }
        if (periodEnd == null || txDate.isAfter(periodEnd)) {
          periodEnd = txDate;
        }

        final description = ParserUtils.cleanDescription(_cellStr(row, 1));
        final mcc = _cellInt(row, 2);
        final cardCurrency = _parseCurrency(_cellStr(row, 3));
        final amountCard = _cellDouble(row, 4) ?? 0.0; // від'ємна = витрата
        final amountOp = _cellDouble(row, 5) ?? amountCard;
        final opCurrency = _parseCurrency(_cellStr(row, 6));
        final rate = _cellDouble(row, 7);
        final commission = _cellDouble(row, 8) ?? 0.0;
        final cashback = _cellDouble(row, 9) ?? 0.0;
        final balanceAfter = _cellDouble(row, 10);

        // Визначаємо суму та валюту.
        // Якщо операційна валюта ≠ UAH → валютна транзакція.
        final bool isForeign = opCurrency != CurrencyType.uah &&
            opCurrency != cardCurrency;

        final double amount;
        final CurrencyType currency;
        final double amountUah;
        final double? exchangeRate;

        if (isForeign) {
          amount = amountOp;
          currency = opCurrency;
          amountUah = amountCard;
          exchangeRate = (rate != null && rate != 1.0) ? rate : null;
        } else {
          amount = amountCard;
          currency = cardCurrency;
          amountUah = amountCard;
          exchangeRate = null;
        }

        final txType = ParserUtils.txTypeFromAmount(amount);

        // Визначаємо внутрішній переказ.
        final isInternal = ParserUtils.isInternalTransfer(
          description: description,
          bankRawType: null,
          ownCardNumbers: ownCardNumbers,
        );

        final dedupHash = ParserUtils.buildDedupHash(
          date: txDate,
          amountUah: amountUah,
          bank: bank,
          cardNumber: detectedCard,
        );

        transactions.add(ParsedTransaction(
          txDate: txDate,
          amount: amount,
          currency: currency,
          amountUah: amountUah,
          exchangeRate: exchangeRate,
          txType: txType,
          description: description,
          bank: bank,
          cardNumber: detectedCard,
          iban: _ibanValue,
          mcc: mcc,
          commission: commission.abs(),
          cashback: cashback,
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
      cardNumber: detectedCard,
    );
  }

  // ─── Витягування номера картки з метаданих ────────────────────────────────

  String? _extractCardNumber(Sheet sheet) {
    // Рядки 1-21 містять рядки типу "Рахунок: UA193..." або "Картка: 4441****4491"
    for (int r = 0; r < _headerRow; r++) {
      if (r >= sheet.rows.length) break;
      final row = sheet.rows[r];
      for (final cell in row) {
        final val = cell?.value?.toString() ?? '';
        // Шукаємо маску картки типу 4441****4491
        final cardMatch = RegExp(r'\d{4}\*{4}\d{4}').firstMatch(val);
        if (cardMatch != null) return cardMatch.group(0);
      }
    }
    return null;
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
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  int? _cellInt(List<Data?> row, int col) {
    final v = _cellValue(row, col);
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  DateTime _parseDateTime(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is String) {
      // Формати: 'DD.MM.YYYY HH:MM:SS' або ISO
      final parts = raw.split(' ');
      if (parts.isNotEmpty) {
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
      }
      return DateTime.parse(raw);
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
