// lib/services/parsers/bank_parser.dart
//
// Базовий інтерфейс та спільні типи для всіх парсерів банківських виписок.

import 'dart:io';

import 'package:family_budget/data/models/card_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ParsedTransaction — проміжний об'єкт до збереження в БД
// ─────────────────────────────────────────────────────────────────────────────

/// Транзакція, розпарсена з банківського файлу.
/// Ще не має id, category_name, import_batch_id — вони призначаються в ImportService.
class ParsedTransaction {
  final DateTime txDate;
  final DateTime? postingDate;
  final double amount; // від'ємне = витрата, додатне = дохід
  final CurrencyType currency;
  final double amountUah;
  final double? exchangeRate;
  final TxType txType;
  final String description;
  final String? bankCategory; // тільки Приватбанк
  final BankSource bank;
  final String cardNumber; // '42065200****7875' — для пошуку card_id
  final String? iban;
  final int? mcc; // тільки Monobank
  final double commission;
  final double cashback;
  final double? balanceAfter;
  final bool isInternal; // внутрішній переказ між власними картками
  final String dedupHash;

  const ParsedTransaction({
    required this.txDate,
    this.postingDate,
    required this.amount,
    required this.currency,
    required this.amountUah,
    this.exchangeRate,
    required this.txType,
    required this.description,
    this.bankCategory,
    required this.bank,
    required this.cardNumber,
    this.iban,
    this.mcc,
    this.commission = 0.0,
    this.cashback = 0.0,
    this.balanceAfter,
    this.isInternal = false,
    required this.dedupHash,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// ParseResult — результат роботи одного парсера
// ─────────────────────────────────────────────────────────────────────────────

/// Результат парсингу файлу виписки.
class ParseResult {
  /// Успішно розпарсені транзакції.
  final List<ParsedTransaction> transactions;

  /// Рядки/секції, які не вдалось розпарсити (для звіту).
  final List<ParseError> errors;

  /// Дата початку покритого файлом періоду.
  final DateTime? periodStart;

  /// Дата кінця покритого файлом періоду.
  final DateTime? periodEnd;

  /// Номер картки, знайдений у файлі.
  final String? cardNumber;

  const ParseResult({
    required this.transactions,
    this.errors = const [],
    this.periodStart,
    this.periodEnd,
    this.cardNumber,
  });

  bool get hasErrors => errors.isNotEmpty;
  int get count => transactions.length;
}

// ─────────────────────────────────────────────────────────────────────────────
// ParseError — помилка парсингу одного рядка
// ─────────────────────────────────────────────────────────────────────────────

class ParseError {
  final int? rowIndex;
  final String rawValue;
  final String reason;

  const ParseError({
    this.rowIndex,
    required this.rawValue,
    required this.reason,
  });

  @override
  String toString() =>
      'ParseError(row: $rowIndex, reason: $reason, raw: "$rawValue")';
}

// ─────────────────────────────────────────────────────────────────────────────
// BankParser — абстрактний інтерфейс
// ─────────────────────────────────────────────────────────────────────────────

/// Абстрактний парсер банківського файлу.
/// Кожен банк реалізує свій підклас.
abstract class BankParser {
  /// Банк, якому відповідає цей парсер.
  BankSource get bank;

  /// Парсить файл виписки та повертає [ParseResult].
  /// Кидає [ParseException] якщо файл не розпізнаний або пошкоджений.
  Future<ParseResult> parse(File file);

  /// Перевіряє чи файл відповідає формату цього банку (без повного парсингу).
  Future<bool> canParse(File file);
}

// ─────────────────────────────────────────────────────────────────────────────
// ParseException
// ─────────────────────────────────────────────────────────────────────────────

class ParseException implements Exception {
  final String message;
  final BankSource? bank;
  const ParseException(this.message, {this.bank});

  @override
  String toString() =>
      'ParseException(${bank?.toSqlValue() ?? 'unknown'}): $message';
}

// ─────────────────────────────────────────────────────────────────────────────
// Спільні утиліти парсингу
// ─────────────────────────────────────────────────────────────────────────────

abstract final class ParserUtils {
  /// Визначає тип транзакції за знаком суми.
  static TxType txTypeFromAmount(double amount) =>
      amount >= 0 ? TxType.income : TxType.expense;

  /// Будує dedup hash для транзакції.
  /// Формат: `YYYY-MM-DD|amountUah|bank|cardNumber` (через `|`).
  static String buildDedupHash({
    required DateTime date,
    required double amountUah,
    required BankSource bank,
    required String cardNumber,
  }) {
    final dateStr = date.toIso8601String().substring(0, 10);
    final raw = '$dateStr|$amountUah|${bank.toSqlValue()}|$cardNumber';
    return raw.hashCode.toRadixString(16);
  }

  /// Очищує рядок опису: прибирає зайві пробіли, нульові символи.
  static String cleanDescription(String raw) =>
      raw.replaceAll('\u0000', '').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Визначає чи є транзакція внутрішнім переказом між власними картками.
  /// Логіка ПУМБ: тип «Переказ» або «P2P» + номер власної картки в описі.
  static bool isInternalTransfer({
    required String description,
    required String? bankRawType,
    required Set<String> ownCardNumbers,
  }) {
    final descUpper = description.toUpperCase();

    // FUIB MoneyTransfer без номера власної картки — НЕ внутрішній (ЗП)
    if (descUpper.contains('FUIB MONEYTRANSFER')) {
      // Перевіряємо чи є в описі номер власної картки
      for (final card in ownCardNumbers) {
        final digits = card.replaceAll(RegExp(r'[^\d*]'), '');
        if (description.contains(digits)) return true;
      }
      return false; // зовнішній платіж — ЗП
    }

    // Приватбанк: bank_category='Перекази між своїми рахунками'
    if (bankRawType != null && bankRawType.contains('своїм')) {
      return true;
    }

    // P2P між відомими власними картками
    for (final card in ownCardNumbers) {
      final digits = card.replaceAll(RegExp(r'[^\d*]'), '');
      if (description.contains(digits)) return true;
    }

    return false;
  }
}
