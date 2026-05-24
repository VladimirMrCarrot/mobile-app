// lib/services/parsers/pumb_parser.dart
//
// Парсер PDF-виписки ПУМБ.
// Картка: 42065200****7875
// Формат: текстовий PDF, 8 стовпців на сторінку.
//
// Залежність: syncfusion_flutter_pdf або pdfx — для вилучення тексту.
// У продакшні замінити _extractText() на реальний виклик бібліотеки.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:family_budget/data/models/card_model.dart';

import 'bank_parser.dart';

/// Парсер PDF-виписки ПУМБ.
///
/// Структура рядка після вилучення тексту:
/// ```
/// <дата операції> <дата постінгу> <опис> <MCC> <сума> <валюта> <сума UAH> <залишок>
/// ```
/// Типи операцій: Покупка / Списання / Надходження / Заблоковано / Перевірка рахунку
/// Пропускаємо: Заблоковано, Перевірка рахунку (не фінальні операції).
class PumbParser extends BankParser {
  static const String _cardNumber = '42065200****7875';
  static const String _ibanValue = 'UA14348510000026208117398264';

  /// Набір власних карток для визначення внутрішніх переказів.
  /// Передається з CardRepository при ініціалізації ImportService.
  final Set<String> ownCardNumbers;

  PumbParser({required this.ownCardNumbers});

  @override
  BankSource get bank => BankSource.pumb;

  // ─── canParse ─────────────────────────────────────────────────────────────

  @override
  Future<bool> canParse(File file) async {
    if (!file.path.toLowerCase().endsWith('.pdf')) return false;
    try {
      // Перевіряємо PDF magic bytes: %PDF
      final bytes = await file.openRead(0, 4).first;
      return bytes.length >= 4 &&
          bytes[0] == 0x25 && // %
          bytes[1] == 0x50 && // P
          bytes[2] == 0x44 && // D
          bytes[3] == 0x46; // F
    } catch (_) {
      return false;
    }
  }

  // ─── parse ────────────────────────────────────────────────────────────────

  @override
  Future<ParseResult> parse(File file) async {
    if (!await canParse(file)) {
      throw ParseException('Файл не є PDF', bank: bank);
    }

    // Вилучаємо текст із PDF.
    final rawText = await _extractText(file);

    return _parseText(rawText);
  }

  // ─── Вилучення тексту з PDF ───────────────────────────────────────────────

  /// Вилучає текст із PDF-файлу.
  /// Заглушка — у продакшні інтегрується з PDF-бібліотекою.
  @visibleForTesting
  Future<String> extractText(File file) => _extractText(file);

  Future<String> _extractText(File file) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    debugPrint('=== PDF RAW TEXT START ===');
    debugPrint(text);
    debugPrint('=== PDF RAW TEXT END ===');
    document.dispose();
    return text;
  }

  // ─── Парсинг тексту ───────────────────────────────────────────────────────

  /// Парсить сирий текст PDF і повертає [ParseResult].
  @visibleForTesting
  ParseResult parseText(String rawText) => _parseText(rawText);

  ParseResult _parseText(String rawText) {
    final transactions = <ParsedTransaction>[];
    final errors = <ParseError>[];
    final lines = rawText.split('\n').map((l) => l.trim()).toList();
    debugPrint('=== PARSE START: total lines: ${lines.length} ===');

    final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    final timeRegex = RegExp(r'^\d{2}:\d{2}:\d{2}$');
    final amountRegex = RegExp(r'^-?\d+[.,]\d+$');
    final cardRegex = RegExp(r'^\d{8}\*{4}\d{4}$');
    const currencies = {'UAH', 'USD', 'EUR'};

    DateTime? periodStart;
    DateTime? periodEnd;
    for (var i = 0; i < lines.length; i++) {
      if (!_isBlockStart(lines, i, dateRegex, timeRegex)) continue;
      debugPrint('BLOCK FOUND at line $i: ${lines[i]}');

      final blockStart = i;
      final buffer = <String>[lines[i]];
      var j = i + 1;
      while (j < lines.length && !_isBlockStart(lines, j, dateRegex, timeRegex)) {
        if (lines[j].isNotEmpty) buffer.add(lines[j]);
        j++;
      }

      try {
        if (buffer.isEmpty) {
          i = j - 1;
          continue;
        }

        final txDatePart = _parseDate(buffer[0]);

        final timeIdx = buffer.indexWhere((l) => timeRegex.hasMatch(l));
        if (timeIdx == -1) {
          throw FormatException('Не знайдено час транзакції');
        }
        final txDate = _withTime(txDatePart, buffer[timeIdx]);

        final amountIdx = buffer.indexWhere(
          (l) => amountRegex.hasMatch(l),
          timeIdx + 1,
        );
        if (amountIdx == -1) {
          throw FormatException('Не знайдено суму транзакції');
        }
        final amountAbs = _parseAmount(buffer[amountIdx]).abs();

        final currencyIdx = buffer.indexWhere(
          (l) => currencies.contains(l.toUpperCase()),
          amountIdx + 1,
        );
        if (currencyIdx == -1) {
          throw FormatException('Не знайдено валюту транзакції');
        }
        final currency = _parseCurrency(buffer[currencyIdx]);

        final postingDateIdx = buffer.indexWhere(
          (l) => dateRegex.hasMatch(l),
          currencyIdx + 1,
        );
        if (postingDateIdx == -1) {
          throw FormatException('Не знайдено posting date');
        }
        final postingDate = _parseDate(buffer[postingDateIdx]);

        final amountUahIdx = buffer.indexWhere(
          (l) => amountRegex.hasMatch(l),
          postingDateIdx + 1,
        );
        if (amountUahIdx == -1) {
          throw FormatException('Не знайдено суму у UAH');
        }
        final amountUahAbs = _parseAmount(buffer[amountUahIdx]).abs();

        final commissionIdx = buffer.indexWhere(
          (l) => amountRegex.hasMatch(l),
          amountUahIdx + 1,
        );
        final commission = commissionIdx == -1
            ? 0.0
            : _parseAmount(buffer[commissionIdx]).abs();

        final cardIdx = buffer.indexWhere((l) => cardRegex.hasMatch(l));
        final opIdx = _lastIndexWhere(buffer, _isOperationTypeLine);
        if (opIdx == -1) {
          throw FormatException('Не знайдено тип операції');
        }
        final opType = buffer[opIdx];

        if (_isSkippable(opType)) {
          i = j - 1;
          continue;
        }

        final descStart = cardIdx != -1 ? cardIdx + 1 : commissionIdx + 1;
        final descriptionParts = <String>[];
        for (var k = descStart; k < opIdx; k++) {
          if (buffer[k].isNotEmpty) descriptionParts.add(buffer[k]);
        }
        final description = ParserUtils.cleanDescription(descriptionParts.join(' '));

        final txType = _txTypeFromOperation(opType);
        final signedAmount = txType == TxType.income ? amountAbs : -amountAbs;
        final signedAmountUah =
            txType == TxType.income ? amountUahAbs : -amountUahAbs;

        final cardNumber = cardIdx == -1 ? _cardNumber : buffer[cardIdx];
        final isInternal = cardIdx == -1;

        if (periodStart == null || txDate.isBefore(periodStart)) {
          periodStart = txDate;
        }
        if (periodEnd == null || txDate.isAfter(periodEnd)) {
          periodEnd = txDate;
        }

        final exchangeRate = currency == CurrencyType.uah || amountAbs == 0
            ? null
            : amountUahAbs / amountAbs;

        final dedupHash = ParserUtils.buildDedupHash(
          date: txDate,
          amountUah: signedAmountUah,
          bank: bank,
          cardNumber: cardNumber,
        );

        transactions.add(ParsedTransaction(
          txDate: txDate,
          postingDate: postingDate,
          amount: signedAmount,
          currency: currency,
          amountUah: signedAmountUah,
          exchangeRate: exchangeRate,
          txType: txType,
          description: description,
          bank: bank,
          cardNumber: cardNumber,
          iban: _ibanValue,
          commission: commission,
          balanceAfter: null,
          isInternal: isInternal,
          dedupHash: dedupHash,
        ));
      } catch (e) {
        final error = ParseError(
          rowIndex: blockStart + 1,
          rawValue: buffer.join(' | '),
          reason: e.toString(),
        );
        errors.add(error);
        debugPrint(
          'PARSE ERROR row=${error.rowIndex}: ${error.reason} | raw: ${error.rawValue}',
        );
      }

      i = j - 1;
    }

    debugPrint(
      '=== PARSE DONE: transactions=${transactions.length}, errors=${errors.length} ===',
    );
    for (final e in errors) {
      debugPrint('  ERROR: row=${e.rowIndex} reason=${e.reason} raw=${e.rawValue}');
    }

    return ParseResult(
      transactions: transactions,
      errors: errors,
      periodStart: periodStart,
      periodEnd: periodEnd,
      cardNumber: _cardNumber,
    );
  }

  // ─── Допоміжні методи ─────────────────────────────────────────────────────

  TxType _txTypeFromOperation(String operationType) {
    final upper = operationType.toUpperCase();
    if (upper.contains('НАДХОДЖЕННЯ')) return TxType.income;
    return TxType.expense;
  }

  bool _isOperationTypeLine(String line) {
    switch (line.trim().toUpperCase()) {
      case 'ПОКУПКА':
      case 'СПИСАННЯ':
      case 'НАДХОДЖЕННЯ':
      case 'ЗАБЛОКОВАНО':
      case 'ПЕРЕВІРКА РАХУНКУ':
        return true;
      default:
        return false;
    }
  }

  bool _isSkippable(String operationType) {
    final upper = operationType.toUpperCase();
    return upper.contains('ЗАБЛОКОВАНО') || upper.contains('ПЕРЕВІРКА РАХУНКУ');
  }

  DateTime _parseDate(String s) {
    // YYYY-MM-DD
    final parts = s.split('-');
    if (parts.length != 3) {
      throw FormatException('Неочікуваний формат дати: $s');
    }
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  DateTime _withTime(DateTime date, String hhmmss) {
    final p = hhmmss.split(':');
    if (p.length != 3) {
      throw FormatException('Неочікуваний формат часу: $hhmmss');
    }
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(p[0]),
      int.parse(p[1]),
      int.parse(p[2]),
    );
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

  int _lastIndexWhere(List<String> items, bool Function(String) test) {
    for (var i = items.length - 1; i >= 0; i--) {
      if (test(items[i])) return i;
    }
    return -1;
  }

  bool _isBlockStart(
    List<String> lines,
    int index,
    RegExp dateRegex,
    RegExp timeRegex,
  ) {
    if (index < 0 || index >= lines.length) return false;
    if (!dateRegex.hasMatch(lines[index])) return false;

    var next = index + 1;
    while (next < lines.length && lines[next].isEmpty) {
      next++;
    }
    if (next >= lines.length) return false;

    return timeRegex.hasMatch(lines[next]);
  }

  double _parseAmount(String s) {
    return double.parse(
      s.replaceAll(' ', '').replaceAll(',', '.'),
    );
  }
}
