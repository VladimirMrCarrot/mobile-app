// lib/data/models/category_model.dart

import 'dart:convert';

// ---------------------------------------------------------------------------
// Тип категорії — витрата, дохід або обидва варіанти
// ---------------------------------------------------------------------------
enum CategoryType {
  expense,
  income,
  both;

  /// Повертає рядкове значення для збереження в SQLite
  String toSqlValue() {
    switch (this) {
      case CategoryType.expense:
        return 'expense';
      case CategoryType.income:
        return 'income';
      case CategoryType.both:
        return 'both';
    }
  }

  /// Розбирає рядкове значення з SQLite
  static CategoryType fromSqlValue(String value) {
    switch (value) {
      case 'expense':
        return CategoryType.expense;
      case 'income':
        return CategoryType.income;
      case 'both':
        return CategoryType.both;
      default:
        throw ArgumentError('Невідомий тип категорії: $value');
    }
  }
}

// ---------------------------------------------------------------------------
// Модель категорії транзакції
// ---------------------------------------------------------------------------
class CategoryModel {
  /// Назва таблиці в SQLite
  static const String tableName = 'categories';

  /// Унікальний ідентифікатор
  final int? id;

  /// Унікальна назва категорії
  final String name;

  /// Emoji-іконка категорії (може бути відсутня)
  final String? icon;

  /// Колір у HEX-форматі, наприклад '#4CAF50' (може бути відсутній)
  final String? colorHex;

  /// Тип: витрата, дохід або обидва
  final CategoryType type;

  /// Чи є категорія системною (не видаляється користувачем)
  final bool isSystem;

  /// Чи відображається категорія у списку
  final bool isVisible;

  /// Порядок відображення у списку
  final int sortOrder;

  /// Час створення запису
  final DateTime? createdAt;

  /// Час останнього оновлення запису
  final DateTime? updatedAt;

  const CategoryModel({
    this.id,
    required this.name,
    this.icon,
    this.colorHex,
    this.type = CategoryType.expense,
    this.isSystem = false,
    this.isVisible = true,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  // -------------------------------------------------------------------------
  // Фабричний конструктор з рядка SQLite
  // -------------------------------------------------------------------------
  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String?,
      colorHex: map['color_hex'] as String?,
      type: CategoryType.fromSqlValue(
        (map['type'] as String?) ?? 'expense',
      ),
      isSystem: ((map['is_system'] as int?) ?? 0) == 1,
      isVisible: ((map['is_visible'] as int?) ?? 1) == 1,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Серіалізація для збереження в SQLite.
  /// Якщо [id] == null, поле 'id' не включається.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'icon': icon,
      'color_hex': colorHex,
      'type': type.toSqlValue(),
      'is_system': isSystem ? 1 : 0,
      'is_visible': isVisible ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  // -------------------------------------------------------------------------
  // JSON-серіалізація
  // -------------------------------------------------------------------------
  factory CategoryModel.fromJson(Map<String, dynamic> json) =>
      CategoryModel.fromMap(json);

  Map<String, dynamic> toJson() => toMap();

  /// Декодування з JSON-рядка
  factory CategoryModel.fromJsonString(String source) =>
      CategoryModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// Кодування до JSON-рядка
  String toJsonString() => jsonEncode(toJson());

  // -------------------------------------------------------------------------
  // copyWith — повертає новий незмінний екземпляр зі зміненими полями
  // -------------------------------------------------------------------------
  CategoryModel copyWith({
    int? id,
    String? name,
    String? icon,
    bool clearIcon = false,
    String? colorHex,
    bool clearColorHex = false,
    CategoryType? type,
    bool? isSystem,
    bool? isVisible,
    int? sortOrder,
    DateTime? createdAt,
    bool clearCreatedAt = false,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: clearIcon ? null : (icon ?? this.icon),
      colorHex: clearColorHex ? null : (colorHex ?? this.colorHex),
      type: type ?? this.type,
      isSystem: isSystem ?? this.isSystem,
      isVisible: isVisible ?? this.isVisible,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    );
  }

  // -------------------------------------------------------------------------
  // Рівність та хеш-код визначаються за полем id
  // -------------------------------------------------------------------------
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CategoryModel('
        'id: $id, '
        'name: $name, '
        'icon: $icon, '
        'colorHex: $colorHex, '
        'type: ${type.toSqlValue()}, '
        'isSystem: $isSystem, '
        'isVisible: $isVisible, '
        'sortOrder: $sortOrder, '
        'createdAt: $createdAt, '
        'updatedAt: $updatedAt'
        ')';
  }

  // -------------------------------------------------------------------------
  // Попередньо заповнений список категорій (23 штуки)
  // -------------------------------------------------------------------------
  static List<CategoryModel> defaults() {
    return const [
      // Витрати — продукти харчування
      CategoryModel(
        name: 'Продукти',
        icon: '🛒',
        colorHex: '#4CAF50',
        type: CategoryType.expense,
        sortOrder: 1,
      ),
      // Витрати — комунальні послуги
      CategoryModel(
        name: 'Комуналка',
        icon: '🏠',
        colorHex: '#2196F3',
        type: CategoryType.expense,
        sortOrder: 2,
      ),
      // Витрати — батьки (Ф-сторона)
      CategoryModel(
        name: 'Батьки Ф',
        icon: '👨‍👩‍👧',
        colorHex: '#9C27B0',
        type: CategoryType.expense,
        sortOrder: 3,
      ),
      // Витрати — батьки (С-сторона)
      CategoryModel(
        name: 'Батьки С',
        icon: '👨‍👩‍👦',
        colorHex: '#E91E63',
        type: CategoryType.expense,
        sortOrder: 4,
      ),
      // Витрати — здоров'я батьків (Ф-сторона)
      CategoryModel(
        name: 'Батьки Ф зд',
        icon: '❤️‍🩹',
        colorHex: '#6A1B9A',
        type: CategoryType.expense,
        sortOrder: 5,
      ),
      // Витрати — здоров'я батьків (С-сторона)
      CategoryModel(
        name: 'Батьки С зд',
        icon: '❤️‍🩹',
        colorHex: '#880E4F',
        type: CategoryType.expense,
        sortOrder: 6,
      ),
      // Дохід — заробітна плата
      CategoryModel(
        name: 'ЗП',
        icon: '💸',
        colorHex: '#00C853',
        type: CategoryType.income,
        sortOrder: 7,
      ),
      // Витрати — таксі
      CategoryModel(
        name: 'Таксі',
        icon: '🚕',
        colorHex: '#FFC107',
        type: CategoryType.expense,
        sortOrder: 8,
      ),
      // Витрати — здоров'я
      CategoryModel(
        name: "Здоров'я",
        icon: '💊',
        colorHex: '#F44336',
        type: CategoryType.expense,
        sortOrder: 9,
      ),
      // Витрати — косметика
      CategoryModel(
        name: 'Косметика',
        icon: '💄',
        colorHex: '#CE93D8',
        type: CategoryType.expense,
        sortOrder: 10,
      ),
      // Витрати — краса, стрижка тощо
      CategoryModel(
        name: 'Краса',
        icon: '✂️',
        colorHex: '#B39DDB',
        type: CategoryType.expense,
        sortOrder: 11,
      ),
      // Витрати — побутові товари
      CategoryModel(
        name: 'Побут',
        icon: '🧹',
        colorHex: '#9E9E9E',
        type: CategoryType.expense,
        sortOrder: 12,
      ),
      // Витрати — освіта
      CategoryModel(
        name: 'Освіта',
        icon: '📚',
        colorHex: '#1565C0',
        type: CategoryType.expense,
        sortOrder: 13,
      ),
      // Витрати — відпочинок та розваги
      CategoryModel(
        name: 'Відпочинок',
        icon: '🎮',
        colorHex: '#00BCD4',
        type: CategoryType.expense,
        sortOrder: 14,
      ),
      // Витрати — свята
      CategoryModel(
        name: 'Свята',
        icon: '🎉',
        colorHex: '#FFD700',
        type: CategoryType.expense,
        sortOrder: 15,
      ),
      // Витрати — подарунки
      CategoryModel(
        name: 'Подарунки',
        icon: '🎁',
        colorHex: '#FF9800',
        type: CategoryType.expense,
        sortOrder: 16,
      ),
      // Витрати — тварини, домашні улюбленці
      CategoryModel(
        name: 'Бува',
        icon: '🐾',
        colorHex: '#81D4FA',
        type: CategoryType.expense,
        sortOrder: 17,
      ),
      // Витрати — благодійність
      CategoryModel(
        name: 'Благо',
        icon: '🤝',
        colorHex: '#26A69A',
        type: CategoryType.expense,
        sortOrder: 18,
      ),
      // Дохід — кешбек
      CategoryModel(
        name: 'Кешбек',
        icon: '💰',
        colorHex: '#66BB6A',
        type: CategoryType.income,
        sortOrder: 19,
      ),
      // Витрати — кредит / позика
      CategoryModel(
        name: 'Кредит',
        icon: '🏦',
        colorHex: '#616161',
        type: CategoryType.expense,
        sortOrder: 20,
      ),
      // Витрати — особисті витрати Тімура
      CategoryModel(
        name: 'Тімур',
        icon: '👤',
        colorHex: '#8D6E63',
        type: CategoryType.expense,
        sortOrder: 21,
      ),
      // Системна категорія — інше (обидва типи)
      CategoryModel(
        name: 'Інше',
        icon: '❓',
        colorHex: '#BDBDBD',
        type: CategoryType.both,
        isSystem: true,
        sortOrder: 22,
      ),
      // Системна категорія — невизначена транзакція
      CategoryModel(
        name: '?',
        icon: '⚠️',
        colorHex: '#FF5722',
        type: CategoryType.both,
        isSystem: true,
        sortOrder: 23,
      ),
    ];
  }
}
