// lib/services/import_service.dart
//
// Головний оркестратор імпорту банківських виписок.
//
// Пайплайн одного імпорту:
//   1. Визначити банк за розширенням та вмістом файлу (auto-detect)
//   2. Завантажити власні картки з БД → передати у парсер
//   3. Викликати відповідний парсер → ParseResult
//   4. Для кожної ParsedTransaction:
//        a. Знайти або створити CartModel (upsert)
//        b. Визначити категорію через RuleRepository.categorize()
//        c. Побудувати TransactionModel (з UUID, batch_id, category)
//        d. Для Monobank: якщо cashback > 0 → створити окрему cashback-транзакцію
//   5. insertBatch() → ImportResult
//   6. Зберегти ImportBatchModel у import_batches
//   7. recalculate() + recalculateCategoryBreakdown() для всіх зачеплених місяців
//   8. Повернути ImportReport
//
// Скасування імпорту:
//   ImportBatchRepository.rollback(batchId) + recalculate() для місяців

import 'dart:io';

import 'package:family_budget/data/database_helper.dart';
import 'package:family_budget/data/models/card_model.dart';
import 'package:family_budget/data/models/import_batch_model.dart';
import 'package:family_budget/data/models/transaction_model.dart';
import 'package:family_budget/data/repositories/card_repository.dart';
import 'package:family_budget/data/repositories/import_batch_repository.dart';
import 'package:family_budget/data/repositories/monthly_summary_repository.dart';
import 'package:family_budget/data/repositories/rule_repository.dart';
import 'package:family_budget/data/repositories/transaction_repository.dart';

import 'parsers/bank_parser.dart';
import 'parsers/monobank_parser.dart';
import 'parsers/privatbank_parser.dart';
import 'parsers/pumb_parser.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ImportReport — детальний звіт після завершення імпорту
// ─────────────────────────────────────────────────────────────────────────────

/// Детальний звіт про результати імпорту однієї виписки.
class ImportReport {
  /// Ідентифікатор пакету (UUID) — для можливості rollback.
  final String batchId;

  /// Банк джерела.
  final BankSource bank;

  /// Назва файлу.
  final String fileName;

  /// Загальна кількість рядків у файлі (до фільтрації).
  final int parsedTotal;

  /// Кількість успішно збережених транзакцій.
  final int imported;

  /// Кількість пропущених дублікатів.
  final int skippedDup;

  /// Кількість пропущених внутрішніх переказів.
  final int skippedInternal;

  /// Кількість транзакцій без визначеної категорії (отримали '?').
  final int uncategorized;

  /// Кількість помилок під час парсингу.
  final int parseErrors;

  /// Кількість помилок під час запису в БД.
  final int dbErrors;

  /// Список помилок парсингу для відображення користувачу.
  final List<ParseError> parseErrorDetails;

  /// Покриті місяці (рік, місяць) — для яких оновлено monthly_summary.
  final Set<({int year, int month})> recalculatedMonths;

  /// Час початку імпорту.
  final DateTime startedAt;

  /// Час завершення імпорту.
  final DateTime finishedAt;

  const ImportReport({
    required this.batchId,
    required this.bank,
    required this.fileName,
    required this.parsedTotal,
    required this.imported,
    required this.skippedDup,
    required this.skippedInternal,
    required this.uncategorized,
    required this.parseErrors,
    required this.dbErrors,
    required this.parseErrorDetails,
    required this.recalculatedMonths,
    required this.startedAt,
    required this.finishedAt,
  });

  Duration get duration => finishedAt.difference(startedAt);

  double get successRate =>
      parsedTotal == 0 ? 0.0 : imported / parsedTotal;

  /// Чи є хоча б одна проблема, на яку варто звернути увагу користувача.
  bool get hasWarnings =>
      parseErrors > 0 || uncategorized > 0 || dbErrors > 0;

  @override
  String toString() =>
      'ImportReport(bank: ${bank.toSqlValue()}, file: $fileName, '
      'imported: $imported, skippedDup: $skippedDup, '
      'skippedInternal: $skippedInternal, uncategorized: $uncategorized, '
      'parseErrors: $parseErrors, dbErrors: $dbErrors, '
      'duration: ${duration.inMilliseconds}ms)';
}

// ─────────────────────────────────────────────────────────────────────────────
// ImportException
// ─────────────────────────────────────────────────────────────────────────────

class ImportException implements Exception {
  final String message;
  final Object? cause;
  const ImportException(this.message, {this.cause});

  @override
  String toString() => 'ImportException: $message'
      '${cause != null ? '\nCause: $cause' : ''}';
}

// ─────────────────────────────────────────────────────────────────────────────
// ImportService
// ─────────────────────────────────────────────────────────────────────────────

class ImportService {
  final DatabaseHelper _db;
  final CardRepository _cardRepo;
  final RuleRepository _ruleRepo;
  final TransactionRepository _txRepo;
  final MonthlySummaryRepository _summaryRepo;
  final ImportBatchRepository _batchRepo;

  ImportService({
    required DatabaseHelper db,
    required CardRepository cardRepo,
    required RuleRepository ruleRepo,
    required TransactionRepository txRepo,
    required MonthlySummaryRepository summaryRepo,
    required ImportBatchRepository batchRepo,
  })  : _db = db,
        _cardRepo = cardRepo,
        _ruleRepo = ruleRepo,
        _txRepo = txRepo,
        _summaryRepo = summaryRepo,
        _batchRepo = batchRepo;

  // ─── Фабричний конструктор ────────────────────────────────────────────────

  /// Створює ImportService із єдиного [DatabaseHelper].
  factory ImportService.fromDb(DatabaseHelper db) {
    return ImportService(
      db: db,
      cardRepo: CardRepository(db),
      ruleRepo: RuleRepository(db),
      txRepo: TransactionRepository(db),
      summaryRepo: MonthlySummaryRepository(db),
      batchRepo: ImportBatchRepository(db),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Головний метод: importFile()
  // ─────────────────────────────────────────────────────────────────────────

  /// Повний пайплайн імпорту одного файлу виписки.
  ///
  /// [file]      — файл виписки (.pdf, .xls, .xlsx).
  /// [bankHint]  — необов'язкова підказка банку якщо auto-detect не спрацьовує.
  /// [onProgress]— коллбек прогресу (0.0–1.0) для UI.
  ///
  /// Повертає [ImportReport] з деталями результату.
  /// Кидає [ImportException] при критичних помилках.
  Future<ImportReport> importFile(
    File file, {
    BankSource? bankHint,
    void Function(double progress, String stage)? onProgress,
  }) async {
    final startedAt = DateTime.now();
    final batchId = TransactionModel.generateId();
    final fileName = file.path.split('/').last;

    // ── Крок 1: завантажити власні картки ──────────────────────────────────
    onProgress?.call(0.05, 'Завантаження карток...');
    final ownCards = await _cardRepo.getAll();
    final ownCardNumbers = ownCards.map((c) => c.cardNumber).toSet();

    // ── Крок 2: визначити парсер ────────────────────────────────────────────
    onProgress?.call(0.10, 'Визначення формату файлу...');
    final parser = await _detectParser(file, bankHint, ownCardNumbers);

    // ── Крок 3: парсинг ─────────────────────────────────────────────────────
    onProgress?.call(0.15, 'Читання файлу...');
    final ParseResult parseResult;
    try {
      parseResult = await parser.parse(file);
    } on ParseException catch (e) {
      throw ImportException('Помилка парсингу файлу: ${e.message}', cause: e);
    } catch (e) {
      throw ImportException('Неочікувана помилка при читанні файлу.', cause: e);
    }

    if (parseResult.transactions.isEmpty && parseResult.hasErrors) {
      throw ImportException(
        'Файл розпізнано, але жодної транзакції не знайдено. '
        'Перевірте формат виписки.',
      );
    }

    // ── Крок 4: підготовка транзакцій ───────────────────────────────────────
    onProgress?.call(0.30, 'Категоризація (${parseResult.count} транзакцій)...');

    final txModels = <TransactionModel>[];
    var uncategorized = 0;

    for (var i = 0; i < parseResult.transactions.length; i++) {
      final parsed = parseResult.transactions[i];

      // 4a. Upsert картки
      final cardModel = await _resolveCard(parsed);

      // 4b. Категоризація
      final category = await _ruleRepo.categorize(
        description: parsed.description,
        txType: parsed.txType,
        bankCategory: parsed.bankCategory,
      );

      if (category == null) uncategorized++;

      // 4c. Побудова TransactionModel
      final tx = _buildTransaction(
        parsed: parsed,
        cardId: cardModel?.id,
        categoryName: category ?? '?',
        batchId: batchId,
        fileName: fileName,
      );
      txModels.add(tx);

      // 4d. Monobank кешбек → окрема транзакція
      if (parsed.cashback > 0) {
        txModels.add(_buildCashbackTransaction(tx, parsed.cashback));
      }

      // Прогрес категоризації (30%–60%)
      if (i % 20 == 0 && parseResult.count > 0) {
        onProgress?.call(0.30 + 0.30 * (i / parseResult.count), 'Категоризація...');
      }
    }

    // ── Крок 5: пакетний запис до БД ────────────────────────────────────────
    onProgress?.call(0.65, 'Збереження в базу даних...');
    final ImportResult dbResult;
    try {
      dbResult = await _txRepo.insertBatch(txModels, batchId);
    } catch (e) {
      throw ImportException('Помилка запису транзакцій до БД.', cause: e);
    }

    // ── Крок 6: збереження пакету імпорту ───────────────────────────────────
    onProgress?.call(0.75, 'Збереження журналу імпорту...');
    final batch = ImportBatchModel(
      id: batchId,
      bank: parser.bank,
      fileName: fileName,
      periodStart: parseResult.periodStart,
      periodEnd: parseResult.periodEnd,
      txTotal: parseResult.count,
      txImported: dbResult.imported,
      txSkippedDup: dbResult.skippedDup,
      txSkippedInt: dbResult.skippedInternal,
      txErrors: dbResult.errors,
      txUncategorized: uncategorized,
      status: ImportStatus.completed,
      importedAt: DateTime.now(),
    );
    await _batchRepo.insert(batch);

    // ── Крок 7: перерахунок місячних підсумків ──────────────────────────────
    onProgress?.call(0.85, 'Оновлення місячних підсумків...');
    final recalcMonths = _collectAffectedMonths(txModels);
    for (final m in recalcMonths) {
      await _summaryRepo.recalculate(m.year, m.month);
      await _summaryRepo.recalculateCategoryBreakdown(m.year, m.month);
    }

    onProgress?.call(1.0, 'Готово');

    return ImportReport(
      batchId: batchId,
      bank: parser.bank,
      fileName: fileName,
      parsedTotal: parseResult.count,
      imported: dbResult.imported,
      skippedDup: dbResult.skippedDup,
      skippedInternal: dbResult.skippedInternal,
      uncategorized: uncategorized,
      parseErrors: parseResult.errors.length,
      dbErrors: dbResult.errors,
      parseErrorDetails: parseResult.errors,
      recalculatedMonths: recalcMonths,
      startedAt: startedAt,
      finishedAt: DateTime.now(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // rollbackImport() — скасування пакету
  // ─────────────────────────────────────────────────────────────────────────

  /// Скасовує імпорт: м'яко видаляє всі транзакції пакету,
  /// позначає пакет як rolled_back, перераховує місячні підсумки.
  Future<void> rollbackImport(String batchId) async {
    final batch = await _batchRepo.getById(batchId);
    if (batch == null) throw ImportException('Пакет $batchId не знайдено.');
    if (batch.status == ImportStatus.rolledBack) {
      throw ImportException('Пакет $batchId вже відкочено.');
    }

    final txs = await _txsForBatch(batchId);
    final months = _collectAffectedMonths(txs);

    await _batchRepo.rollback(batchId, _txRepo);

    for (final m in months) {
      await _summaryRepo.recalculate(m.year, m.month);
      await _summaryRepo.recalculateCategoryBreakdown(m.year, m.month);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // retryUncategorized() — повторна категоризація '?' транзакцій
  // ─────────────────────────────────────────────────────────────────────────

  /// Запускає повторну категоризацію транзакцій з категорією '?'.
  /// Корисно після додавання нових правил.
  /// Повертає кількість оновлених транзакцій.
  Future<int> retryUncategorized() async {
    final txs = await _txRepo.getByCategory('?');
    var updated = 0;
    final months = <({int year, int month})>{};

    for (final tx in txs) {
      final category = await _ruleRepo.categorize(
        description: tx.description,
        txType: tx.txType,
        bankCategory: tx.bankCategory,
      );
      if (category != null && category != '?') {
        await _txRepo.updateCategory(tx.id, category);
        updated++;
        months.add((year: tx.txDate.year, month: tx.txDate.month));
      }
    }

    for (final m in months) {
      await _summaryRepo.recalculateCategoryBreakdown(m.year, m.month);
    }

    return updated;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Внутрішні допоміжні методи
  // ─────────────────────────────────────────────────────────────────────────

  // ── Auto-detect парсера ───────────────────────────────────────────────────

  Future<BankParser> _detectParser(
    File file,
    BankSource? hint,
    Set<String> ownCardNumbers,
  ) async {
    final parsers = <BankParser>[
      PumbParser(ownCardNumbers: ownCardNumbers),
      MonobankParser(ownCardNumbers: ownCardNumbers),
      PrivatbankParser(ownCardNumbers: ownCardNumbers),
    ];

    if (hint != null) {
      final hinted = parsers.firstWhere(
        (p) => p.bank == hint,
        orElse: () => parsers.first,
      );
      if (await hinted.canParse(file)) return hinted;
    }

    for (final p in parsers) {
      if (await p.canParse(file)) return p;
    }

    throw ImportException(
      'Формат файлу "${file.path.split('/').last}" не розпізнано. '
      'Підтримуються: ПУМБ (PDF), Monobank (XLS), Приватбанк (XLSX).',
    );
  }

  // ── Upsert картки ─────────────────────────────────────────────────────────

  /// Знаходить або автоматично створює картку для транзакції.
  Future<CardModel?> _resolveCard(ParsedTransaction parsed) async {
    try {
      return await _cardRepo.upsert(
        CardModel(
          bank: _bankSourceToType(parsed.bank),
          cardNumber: parsed.cardNumber,
          iban: parsed.iban,
          currency: parsed.currency,
          displayName: _defaultDisplayName(parsed.bank, parsed.cardNumber),
          balance: 0.0,
          isActive: true,
          sortOrder: 99,
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  BankType _bankSourceToType(BankSource source) {
    switch (source) {
      case BankSource.pumb:
        return BankType.pumb;
      case BankSource.monobank:
        return BankType.monobank;
      case BankSource.privatbank:
        return BankType.privatbank;
      case BankSource.manual:
        return BankType.other;
    }
  }

  String _defaultDisplayName(BankSource bank, String cardNumber) {
    final suffix = cardNumber.length >= 4
        ? cardNumber.substring(cardNumber.length - 4)
        : cardNumber;
    return '${bank.toSqlValue()} …$suffix';
  }

  // ── Побудова TransactionModel ─────────────────────────────────────────────

  TransactionModel _buildTransaction({
    required ParsedTransaction parsed,
    required int? cardId,
    required String categoryName,
    required String batchId,
    required String fileName,
  }) {
    final now = DateTime.now().toUtc();
    return TransactionModel(
      id: TransactionModel.generateId(),
      txDate: parsed.txDate,
      postingDate: parsed.postingDate,
      amount: parsed.amount,
      currency: parsed.currency,
      amountUah: parsed.amountUah,
      exchangeRate: parsed.exchangeRate,
      txType: parsed.txType,
      description: parsed.description,
      categoryName: categoryName,
      bankCategory: parsed.bankCategory,
      bank: parsed.bank,
      cardId: cardId,
      iban: parsed.iban,
      mcc: parsed.mcc,
      commission: parsed.commission,
      cashback: 0.0,
      balanceAfter: parsed.balanceAfter,
      parentTxId: null,
      importSource: fileName,
      importBatchId: batchId,
      importDate: now,
      dedupHash: parsed.dedupHash,
      isManual: false,
      isInternal: parsed.isInternal,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Створює окрему транзакцію кешбеку з посиланням на батьківську.
  TransactionModel _buildCashbackTransaction(
    TransactionModel parent,
    double cashbackAmount,
  ) {
    final now = DateTime.now().toUtc();
    return TransactionModel(
      id: TransactionModel.generateId(),
      txDate: parent.txDate,
      amount: cashbackAmount,
      currency: CurrencyType.uah,
      amountUah: cashbackAmount,
      txType: TxType.income,
      description: 'Кешбек: ${parent.description}',
      categoryName: 'Кешбек',
      bank: parent.bank,
      cardId: parent.cardId,
      commission: 0.0,
      cashback: 0.0,
      parentTxId: parent.id,
      importSource: parent.importSource,
      importBatchId: parent.importBatchId,
      importDate: now,
      dedupHash: null,
      isManual: false,
      isInternal: false,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  // ── Місяці, що потребують перерахунку ────────────────────────────────────

  Set<({int year, int month})> _collectAffectedMonths(
    List<TransactionModel> txs,
  ) {
    return txs
        .where((t) => !t.isDeleted && !t.isInternal)
        .map((t) => (year: t.txDate.year, month: t.txDate.month))
        .toSet();
  }

  // ── Транзакції конкретного пакету (для rollback) ──────────────────────────

  Future<List<TransactionModel>> _txsForBatch(String batchId) async {
    final db = await _db.database;
    final rows = await db.query(
      'transactions',
      where: 'import_batch_id = ?',
      whereArgs: [batchId],
    );
    return rows.map(TransactionModel.fromMap).toList();
  }
}
