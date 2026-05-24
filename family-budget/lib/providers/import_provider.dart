// lib/providers/import_provider.dart
//
// Riverpod-провайдери для імпорту банківських виписок.
//
// importServiceProvider        — синглтон ImportService
// importFileProvider           — AsyncNotifier: запуск імпорту → ImportReport
// importHistoryProvider        — список пакетів імпорту (AsyncNotifierProvider)
// importStateProvider          — локальний UI-стан (статус, превʼю, помилки)

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/import_batch_model.dart';
import '../services/import_service.dart';
import 'database_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ImportService
// ─────────────────────────────────────────────────────────────────────────────

/// Синглтон ImportService, побудований через фабричний конструктор fromDb.
final importServiceProvider = Provider<ImportService>((ref) {
  final db = ref.watch(databaseHelperProvider);
  return ImportService.fromDb(db);
});

// ─────────────────────────────────────────────────────────────────────────────
// Стан імпорту (UI)
// ─────────────────────────────────────────────────────────────────────────────

/// Статус локального процесу імпорту (не плутати з [ImportStatus] у БД).
enum ImportUiStatus {
  idle,
  picking,
  importing,
  success,
  error,
}

/// Знімок стану екрана імпорту: етап, останній звіт, текстові помилки.
class ImportState {
  final ImportUiStatus status;
  final ImportReport? preview;
  final List<String> errors;

  const ImportState({
    required this.status,
    this.preview,
    this.errors = const [],
  });

  factory ImportState.initial() => const ImportState(status: ImportUiStatus.idle);

  ImportState copyWith({
    ImportUiStatus? status,
    ImportReport? preview,
    List<String>? errors,
  }) {
    return ImportState(
      status: status ?? this.status,
      preview: preview ?? this.preview,
      errors: errors ?? this.errors,
    );
  }
}

class ImportStateNotifier extends Notifier<ImportState> {
  @override
  ImportState build() => ImportState.initial();

  void reset() {
    state = ImportState.initial();
  }

  void setStatus(ImportUiStatus status) {
    state = state.copyWith(status: status);
  }

  void setPreview(ImportReport? report) {
    state = state.copyWith(preview: report, status: ImportUiStatus.success);
  }

  void setError(String message) {
    state = ImportState(
      status: ImportUiStatus.error,
      preview: state.preview,
      errors: [...state.errors, message],
    );
  }
}

final importStateProvider =
    NotifierProvider<ImportStateNotifier, ImportState>(ImportStateNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────
// AsyncNotifier для імпорту файлу
// ─────────────────────────────────────────────────────────────────────────────

/// Стан одного запуску імпорту файлу.
class ImportFileNotifier extends AsyncNotifier<ImportReport?> {
  @override
  Future<ImportReport?> build() async => null;

  /// Відкриває файловий пікер, запускає імпорт і повертає [ImportReport].
  ///
  /// Підтримувані розширення: pdf, xls, xlsx
  Future<void> pickAndImport() async {
    state = const AsyncValue.loading();

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xls', 'xlsx'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        state = const AsyncValue.data(null);
        return;
      }

      final pickedPath = result.files.single.path;
      if (pickedPath == null) {
        state = AsyncValue.error(
          'Не вдалося отримати шлях до файлу',
          StackTrace.current,
        );
        return;
      }

      final file = File(pickedPath);

      final service = ref.read(importServiceProvider);
      final report = await service.importFile(file);

      state = AsyncValue.data(report);

      ref.invalidate(importHistoryProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Скасування останнього успішного пакету.
  Future<void> rollback(String batchId) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(importServiceProvider);
      await service.rollbackImport(batchId);
      state = const AsyncValue.data(null);
      ref.invalidate(importHistoryProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Провайдер стану імпорту файлу.
final importFileProvider =
    AsyncNotifierProvider<ImportFileNotifier, ImportReport?>(
  ImportFileNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// Історія імпортів
// ─────────────────────────────────────────────────────────────────────────────

/// Список усіх пакетів імпорту (ImportBatchModel) у зворотньому хронологічному порядку.
final importHistoryProvider =
    AsyncNotifierProvider<ImportHistoryNotifier, List<ImportBatchModel>>(
  ImportHistoryNotifier.new,
);

class ImportHistoryNotifier extends AsyncNotifier<List<ImportBatchModel>> {
  @override
  Future<List<ImportBatchModel>> build() async {
    final repo = ref.watch(importBatchRepositoryProvider);
    return repo.getAll();
  }
}
