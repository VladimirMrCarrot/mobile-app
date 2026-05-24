// lib/data/models/import_batch_model.dart

import 'dart:convert';

import 'card_model.dart'; // BankSource, ImportStatus

// ---------------------------------------------------------------------------
// Модель пакету імпорту банківської виписки
// ---------------------------------------------------------------------------
class ImportBatchModel {
  /// Назва таблиці в SQLite
  static const String tableName = 'import_batches';

  /// Унікальний ідентифікатор пакету (UUID)
  final String id;

  /// Банк, з якого здійснено імпорт
  final BankSource bank;

  /// Оригінальна назва завантаженого файлу
  final String fileName;

  /// Початок охопленого виpiскою періоду
  final DateTime? periodStart;

  /// Кінець охопленого виpискою періоду
  final DateTime? periodEnd;

  /// Загальна кількість рядків у файлі
  final int txTotal;

  /// Кількість успішно імпортованих транзакцій
  final int txImported;

  /// Кількість пропущених дублікатів
  final int txSkippedDup;

  /// Кількість пропущених внутрішніх переказів
  final int txSkippedInt;

  /// Кількість рядків із помилками парсингу
  final int txErrors;

  /// Кількість транзакцій без категорії після автокатегоризації
  final int txUncategorized;

  /// Статус пакету імпорту
  final ImportStatus status;

  /// Час проведення імпорту
  final DateTime importedAt;

  const ImportBatchModel({
    required this.id,
    required this.bank,
    required this.fileName,
    this.periodStart,
    this.periodEnd,
    this.txTotal = 0,
    this.txImported = 0,
    this.txSkippedDup = 0,
    this.txSkippedInt = 0,
    this.txErrors = 0,
    this.txUncategorized = 0,
    this.status = ImportStatus.completed,
    required this.importedAt,
  });

  // -------------------------------------------------------------------------
  // Обчислювані властивості
  // -------------------------------------------------------------------------

  /// Загальна кількість пропущених транзакцій (дублікати + внутрішні перекази)
  int get txSkipped => txSkippedDup + txSkippedInt;

  /// Частка успішно імпортованих транзакцій відносно загальної кількості.
  /// Повертає 0.0, якщо [txTotal] == 0, щоб уникнути ділення на нуль.
  double get successRate => txTotal == 0 ? 0.0 : txImported / txTotal;

  // -------------------------------------------------------------------------
  // Фабричний конструктор з рядка SQLite / JSON-об'єкта
  // -------------------------------------------------------------------------
  factory ImportBatchModel.fromMap(Map<String, dynamic> map) {
    return ImportBatchModel(
      id: map['id'] as String,
      bank: BankSource.fromSqlValue(map['bank'] as String),
      fileName: map['file_name'] as String,
      periodStart: map['period_start'] != null
          ? DateTime.parse(map['period_start'] as String)
          : null,
      periodEnd: map['period_end'] != null
          ? DateTime.parse(map['period_end'] as String)
          : null,
      txTotal: (map['tx_total'] as int?) ?? 0,
      txImported: (map['tx_imported'] as int?) ?? 0,
      txSkippedDup: (map['tx_skipped_dup'] as int?) ?? 0,
      txSkippedInt: (map['tx_skipped_int'] as int?) ?? 0,
      txErrors: (map['tx_errors'] as int?) ?? 0,
      txUncategorized: (map['tx_uncategorized'] as int?) ?? 0,
      status: ImportStatus.fromSqlValue(
        (map['status'] as String?) ?? 'completed',
      ),
      importedAt: DateTime.parse(map['imported_at'] as String),
    );
  }

  /// Серіалізація для збереження в SQLite.
  /// UUID передається явно — AUTOINCREMENT не використовується.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bank': bank.toSqlValue(),
      'file_name': fileName,
      'period_start': periodStart?.toIso8601String(),
      'period_end': periodEnd?.toIso8601String(),
      'tx_total': txTotal,
      'tx_imported': txImported,
      'tx_skipped_dup': txSkippedDup,
      'tx_skipped_int': txSkippedInt,
      'tx_errors': txErrors,
      'tx_uncategorized': txUncategorized,
      'status': status.toSqlValue(),
      'imported_at': importedAt.toIso8601String(),
    };
  }

  // -------------------------------------------------------------------------
  // JSON-серіалізація
  // -------------------------------------------------------------------------
  factory ImportBatchModel.fromJson(Map<String, dynamic> json) =>
      ImportBatchModel.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  /// Декодування з JSON-рядка
  factory ImportBatchModel.fromJsonString(String source) =>
      ImportBatchModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// Кодування до JSON-рядка
  String toJsonString() => jsonEncode(toJson());

  // -------------------------------------------------------------------------
  // copyWith — повертає новий незмінний екземпляр зі зміненими полями
  // -------------------------------------------------------------------------
  ImportBatchModel copyWith({
    String? id,
    BankSource? bank,
    String? fileName,
    DateTime? periodStart,
    bool clearPeriodStart = false,
    DateTime? periodEnd,
    bool clearPeriodEnd = false,
    int? txTotal,
    int? txImported,
    int? txSkippedDup,
    int? txSkippedInt,
    int? txErrors,
    int? txUncategorized,
    ImportStatus? status,
    DateTime? importedAt,
  }) {
    return ImportBatchModel(
      id: id ?? this.id,
      bank: bank ?? this.bank,
      fileName: fileName ?? this.fileName,
      periodStart:
          clearPeriodStart ? null : (periodStart ?? this.periodStart),
      periodEnd: clearPeriodEnd ? null : (periodEnd ?? this.periodEnd),
      txTotal: txTotal ?? this.txTotal,
      txImported: txImported ?? this.txImported,
      txSkippedDup: txSkippedDup ?? this.txSkippedDup,
      txSkippedInt: txSkippedInt ?? this.txSkippedInt,
      txErrors: txErrors ?? this.txErrors,
      txUncategorized: txUncategorized ?? this.txUncategorized,
      status: status ?? this.status,
      importedAt: importedAt ?? this.importedAt,
    );
  }

  // -------------------------------------------------------------------------
  // Рівність та хеш-код
  // -------------------------------------------------------------------------
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImportBatchModel &&
        other.id == id &&
        other.bank == bank &&
        other.fileName == fileName &&
        other.periodStart == periodStart &&
        other.periodEnd == periodEnd &&
        other.txTotal == txTotal &&
        other.txImported == txImported &&
        other.txSkippedDup == txSkippedDup &&
        other.txSkippedInt == txSkippedInt &&
        other.txErrors == txErrors &&
        other.txUncategorized == txUncategorized &&
        other.status == status &&
        other.importedAt == importedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        bank,
        fileName,
        periodStart,
        periodEnd,
        txTotal,
        txImported,
        txSkippedDup,
        txSkippedInt,
        txErrors,
        txUncategorized,
        status,
        importedAt,
      );

  @override
  String toString() {
    return 'ImportBatchModel('
        'id: $id, '
        'bank: ${bank.toSqlValue()}, '
        'fileName: $fileName, '
        'periodStart: $periodStart, '
        'periodEnd: $periodEnd, '
        'txTotal: $txTotal, '
        'txImported: $txImported, '
        'txSkippedDup: $txSkippedDup, '
        'txSkippedInt: $txSkippedInt, '
        'txErrors: $txErrors, '
        'txUncategorized: $txUncategorized, '
        'txSkipped: $txSkipped, '
        'successRate: $successRate, '
        'status: ${status.toSqlValue()}, '
        'importedAt: $importedAt'
        ')';
  }
}
