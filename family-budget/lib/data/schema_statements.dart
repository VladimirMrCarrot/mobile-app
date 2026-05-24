// Generated from MASTER.md РОЗДІЛ 2 schema.sql line ranges.
// ignore_for_file: lines_longer_than_80_chars

const List<String> kSchemaStatements = [
  r'''PRAGMA encoding = 'UTF-8';''',
  r'''CREATE TABLE IF NOT EXISTS cards (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    bank          TEXT    NOT NULL CHECK (bank IN ('ПУМБ', 'Monobank', 'Приватбанк', 'Інший')),
    card_number   TEXT    NOT NULL,                    -- '42065200****7875'
    iban          TEXT,                                -- 'UA14348510000026208117398264' (без пробілів)
    currency      TEXT    NOT NULL DEFAULT 'UAH'
                          CHECK (currency IN ('UAH', 'USD', 'EUR')),
    display_name  TEXT,                                -- Власна назва: «Моно основна»
    balance       REAL    NOT NULL DEFAULT 0.0,        -- Поточний залишок
    balance_updated_at DATETIME,                       -- Коли залишок оновлювався
    is_active     INTEGER NOT NULL DEFAULT 1           -- 0 = архівна картка
                          CHECK (is_active IN (0, 1)),
    sort_order    INTEGER NOT NULL DEFAULT 0,
    created_at    DATETIME NOT NULL DEFAULT (datetime('now')),
    updated_at    DATETIME NOT NULL DEFAULT (datetime('now')),

    UNIQUE (bank, card_number)
);''',
  r'''INSERT OR IGNORE INTO cards (bank, card_number, iban, currency, display_name, sort_order) VALUES
    ('ПУМБ',        '42065200****7875', 'UA14348510000026208117398264', 'UAH', 'ПУМБ',              1),
    ('Monobank',    '4441****4491',     'UA193220010000026209300479632', 'UAH', 'Monobank',          2),
    ('Приватбанк',  '5168****4428',     NULL,                            'UAH', 'Приват 4428',       3),
    ('Приватбанк',  '5169****3844',     NULL,                            'UAH', 'Приват 3844',       4),
    ('Приватбанк',  '4149****3336',     NULL,                            'UAH', 'Приват 3336',       5);''',
  r'''CREATE TABLE IF NOT EXISTS categories (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    name          TEXT    NOT NULL UNIQUE,
    icon          TEXT,                                -- Emoji або назва іконки
    color_hex     TEXT,                                -- '#4CAF50'
    type          TEXT    NOT NULL DEFAULT 'expense'
                          CHECK (type IN ('expense', 'income', 'both')),
    is_system     INTEGER NOT NULL DEFAULT 0           -- 1 = не можна видалити
                          CHECK (is_system IN (0, 1)),
    is_visible    INTEGER NOT NULL DEFAULT 1
                          CHECK (is_visible IN (0, 1)),
    sort_order    INTEGER NOT NULL DEFAULT 0,
    created_at    DATETIME NOT NULL DEFAULT (datetime('now')),
    updated_at    DATETIME NOT NULL DEFAULT (datetime('now'))
);''',
  r'''INSERT OR IGNORE INTO categories (name, icon, color_hex, type, is_system, sort_order) VALUES
    ('Продукти',    '🛒', '#4CAF50', 'expense', 0,  1),
    ('Комуналка',   '🏠', '#2196F3', 'expense', 0,  2),
    ('Батьки Ф',    '👨‍👩‍👧', '#9C27B0', 'expense', 0,  3),
    ('Батьки С',    '👨‍👩‍👦', '#E91E63', 'expense', 0,  4),
    ('Батьки Ф зд', '❤️‍🩹', '#6A1B9A', 'expense', 0,  5),
    ('Батьки С зд', '❤️‍🩹', '#880E4F', 'expense', 0,  6),
    ('ЗП',          '💸', '#00C853', 'income',  0,  7),
    ('Таксі',       '🚕', '#FFC107', 'expense', 0,  8),
    ('Здоров''я',   '💊', '#F44336', 'expense', 0,  9),
    ('Косметика',   '💄', '#CE93D8', 'expense', 0, 10),
    ('Краса',       '✂️', '#B39DDB', 'expense', 0, 11),
    ('Побут',       '🧹', '#9E9E9E', 'expense', 0, 12),
    ('Освіта',      '📚', '#1565C0', 'expense', 0, 13),
    ('Відпочинок',  '🎮', '#00BCD4', 'expense', 0, 14),
    ('Свята',       '🎉', '#FFD700', 'expense', 0, 15),
    ('Подарунки',   '🎁', '#FF9800', 'expense', 0, 16),
    ('Бува',        '🐾', '#81D4FA', 'expense', 0, 17),
    ('Благо',       '🤝', '#26A69A', 'expense', 0, 18),
    ('Кешбек',      '💰', '#66BB6A', 'income',  0, 19),
    ('Кредит',      '🏦', '#616161', 'expense', 0, 20),
    ('Тімур',       '👤', '#8D6E63', 'expense', 0, 21),
    ('Інше',        '❓', '#BDBDBD', 'both',    1, 22),  -- is_system, не видаляти
    ('?',           '⚠️', '#FF5722', 'both',    1, 23);  -- службова: невизначені''',
  r'''CREATE TABLE IF NOT EXISTS rules (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    keyword       TEXT    NOT NULL,                    -- 'VARUS' або 'ATB'
    match_type    TEXT    NOT NULL DEFAULT 'contains'
                          CHECK (match_type IN (
                              'contains',              -- опис містить keyword (регістр не важливий)
                              'starts_with',           -- починається з
                              'exact',                 -- точний збіг
                              'regex'                  -- регулярний вираз
                          )),
    category_name TEXT    NOT NULL
                          REFERENCES categories(name) ON UPDATE CASCADE,
    source_field  TEXT    NOT NULL DEFAULT 'description'
                          CHECK (source_field IN (
                              'description',           -- поле опису мерчанта
                              'bank_category'          -- категорія банку (Приватбанк)
                          )),
    tx_type       TEXT    DEFAULT NULL
                          CHECK (tx_type IN ('income', 'expense', NULL)),
                                                       -- NULL = застосовувати до обох типів
    priority      INTEGER NOT NULL DEFAULT 50,         -- 1–100; більше = вищий пріоритет
    is_active     INTEGER NOT NULL DEFAULT 1
                          CHECK (is_active IN (0, 1)),
    is_system     INTEGER NOT NULL DEFAULT 0           -- 1 = вбудоване правило (не видаляти)
                          CHECK (is_system IN (0, 1)),
    created_at    DATETIME NOT NULL DEFAULT (datetime('now')),
    updated_at    DATETIME NOT NULL DEFAULT (datetime('now'))
);''',
  r'''INSERT OR IGNORE INTO rules (keyword, match_type, category_name, source_field, tx_type, priority, is_system) VALUES
    -- Продукти — пріоритет 90
    ('VARUS',               'contains', 'Продукти',   'description', 'expense', 90, 1),
    ('ATB',                 'contains', 'Продукти',   'description', 'expense', 90, 1),
    ('ATB-MARKET',          'contains', 'Продукти',   'description', 'expense', 90, 1),
    ('SILPO',               'contains', 'Продукти',   'description', 'expense', 90, 1),
    ('NOVUS',               'contains', 'Продукти',   'description', 'expense', 90, 1),
    ('METRO',               'contains', 'Продукти',   'description', 'expense', 90, 1),
    ('AUCHAN',              'contains', 'Продукти',   'description', 'expense', 90, 1),
    ('FORA',                'contains', 'Продукти',   'description', 'expense', 90, 1),
    ('TAVRIAV',             'contains', 'Продукти',   'description', 'expense', 90, 1),
    ('FOZZY',               'contains', 'Продукти',   'description', 'expense', 90, 1),

    -- Комуналка — пріоритет 90
    ('YASNO',               'contains', 'Комуналка',  'description', 'expense', 90, 1),
    ('Нафтогаз',            'contains', 'Комуналка',  'description', 'expense', 90, 1),
    ('Дніпроводоканал',     'contains', 'Комуналка',  'description', 'expense', 90, 1),
    ('Дніпротеплоенерго',   'contains', 'Комуналка',  'description', 'expense', 90, 1),
    ('Укртелеком',          'contains', 'Комуналка',  'description', 'expense', 90, 1),
    ('Київстар',            'contains', 'Комуналка',  'description', 'expense', 90, 1),
    ('Vodafone',            'contains', 'Комуналка',  'description', 'expense', 90, 1),
    ('Lifecell',            'contains', 'Комуналка',  'description', 'expense', 90, 1),
    -- Приватбанк: категорія банку
    ('Комуналка та Інтернет','exact',   'Комуналка',  'bank_category','expense',40, 1),

    -- Таксі — пріоритет 90
    ('UKLON',               'contains', 'Таксі',      'description', 'expense', 90, 1),
    ('IPAY.UA*UKLON',       'contains', 'Таксі',      'description', 'expense', 90, 1),
    ('Bolt',                'contains', 'Таксі',      'description', 'expense', 90, 1),
    ('Uber',                'contains', 'Таксі',      'description', 'expense', 90, 1),
    ('PLATON',              'contains', 'Таксі',      'description', 'expense', 90, 1),

    -- Здоров'я — пріоритет 80
    ('iHerb',               'contains', 'Здоров''я',  'description', 'expense', 80, 1),
    ('Med-Magazin',         'contains', 'Здоров''я',  'description', 'expense', 80, 1),
    ('АПТЕКА',              'contains', 'Здоров''я',  'description', 'expense', 80, 1),
    ('APTEKA',              'contains', 'Здоров''я',  'description', 'expense', 80, 1),

    -- Косметика — пріоритет 80
    ('BARPHEROMONES',       'contains', 'Косметика',  'description', 'expense', 80, 1),
    ('BROCARD',             'contains', 'Косметика',  'description', 'expense', 80, 1),
    ('EVA',                 'exact',    'Косметика',  'description', 'expense', 80, 1),
    ('WATSONS',             'contains', 'Косметика',  'description', 'expense', 80, 1),

    -- Відпочинок — пріоритет 70
    ('Steam',               'contains', 'Відпочинок', 'description', 'expense', 70, 1),
    ('Netflix',             'contains', 'Відпочинок', 'description', 'expense', 70, 1),
    ('Megogo',              'contains', 'Відпочинок', 'description', 'expense', 70, 1),
    ('Spotify',             'contains', 'Відпочинок', 'description', 'expense', 70, 1),
    ('SWEET.TV',            'contains', 'Відпочинок', 'description', 'expense', 70, 1),
    ('PlayStation',         'contains', 'Відпочинок', 'description', 'expense', 70, 1),
    ('Google Play',         'contains', 'Відпочинок', 'description', 'expense', 70, 1),
    -- Приватбанк
    ('Кіно',                'exact',    'Відпочинок', 'bank_category','expense',40, 1),
    ('Розваги',             'exact',    'Відпочинок', 'bank_category','expense',40, 1),

    -- Освіта — пріоритет 70
    ('Perplexity',          'contains', 'Освіта',     'description', 'expense', 70, 1),
    ('ChatGPT',             'contains', 'Освіта',     'description', 'expense', 70, 1),
    ('Chat GPT',            'contains', 'Освіта',     'description', 'expense', 70, 1),
    ('OPENAI',              'contains', 'Освіта',     'description', 'expense', 70, 1),
    ('Coursera',            'contains', 'Освіта',     'description', 'expense', 70, 1),
    ('Udemy',               'contains', 'Освіта',     'description', 'expense', 70, 1),
    ('Prometheus',          'contains', 'Освіта',     'description', 'expense', 70, 1),
    ('Duolingo',            'contains', 'Освіта',     'description', 'expense', 70, 1),

    -- Кредит — пріоритет 85 (треба до WAYFORPAY загальний)
    ('WAYFORPAY',           'contains', 'Кредит',     'description', 'expense', 85, 1),
    ('Кредит ПриватБанк',   'contains', 'Кредит',     'description', 'expense', 85, 1),
    ('Кредити',             'exact',    'Кредит',     'bank_category','expense',40, 1),

    -- ЗП — пріоритет 70, тільки income
    ('FUIB MoneyTransfer',  'contains', 'ЗП',         'description', 'income',  70, 1),
    ('Зарахування переказу','exact',    'ЗП',         'bank_category','income', 30, 1); -- низький пріоритет, може бути й не ЗП''',
  r'''CREATE TABLE IF NOT EXISTS transactions (
    id                TEXT    PRIMARY KEY,             -- UUID v4: 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'

    -- Часові поля
    tx_date           DATETIME NOT NULL,               -- Дата та час операції (з виписки)
    posting_date      DATE,                            -- Дата постінгу (тільки ПУМБ PDF)

    -- Сума та валюта
    amount            REAL    NOT NULL,                -- Оригінальна сума (від'ємна = витрата)
    currency          TEXT    NOT NULL DEFAULT 'UAH'
                              CHECK (currency IN ('UAH', 'USD', 'EUR')),
    amount_uah        REAL    NOT NULL,                -- Сума у гривнях (для звітів)
    exchange_rate     REAL,                            -- Курс конвертації (якщо валютна операція)

    -- Тип операції
    tx_type           TEXT    NOT NULL
                              CHECK (tx_type IN ('income', 'expense', 'transfer')),

    -- Опис та категоризація
    description       TEXT    NOT NULL DEFAULT '',
    category_name     TEXT    REFERENCES categories(name) ON UPDATE CASCADE ON DELETE SET NULL,
    bank_category     TEXT,                            -- Оригінальна категорія Приватбанку

    -- Джерело
    bank              TEXT    NOT NULL
                              CHECK (bank IN ('ПУМБ', 'Monobank', 'Приватбанк', 'Ручний ввід')),
    card_id           INTEGER REFERENCES cards(id) ON DELETE SET NULL,
    iban              TEXT,                            -- IBAN рахунку (якщо відомий)

    -- Monobank специфічні поля
    mcc               INTEGER,                         -- MCC код мерчанта
    commission        REAL    NOT NULL DEFAULT 0.0,
    cashback          REAL    NOT NULL DEFAULT 0.0,
    balance_after     REAL,                            -- Залишок після операції

    -- Кешбек-зв'язок
    parent_tx_id      TEXT    REFERENCES transactions(id) ON DELETE SET NULL,
                                                       -- Для кешбек-транзакцій: посилання на основну

    -- Імпорт
    import_source     TEXT,                            -- Ім'я файлу: 'Vipiska-po-rakhunku.pdf'
    import_batch_id   TEXT,                            -- UUID сесії імпорту (щоб скасувати пакет)
    import_date       DATETIME NOT NULL DEFAULT (datetime('now')),

    -- Дедублікація
    dedup_hash        TEXT    UNIQUE,                  -- hash(tx_date_day + amount_uah + bank + card_id)
                                                       -- NULL для ручних транзакцій

    -- Прапорці
    is_manual         INTEGER NOT NULL DEFAULT 0
                              CHECK (is_manual IN (0, 1)),
    is_internal       INTEGER NOT NULL DEFAULT 0       -- 1 = внутрішній переказ (ігнорувати в статистиці)
                              CHECK (is_internal IN (0, 1)),
    is_deleted        INTEGER NOT NULL DEFAULT 0       -- М'яке видалення
                              CHECK (is_deleted IN (0, 1)),

    created_at        DATETIME NOT NULL DEFAULT (datetime('now')),
    updated_at        DATETIME NOT NULL DEFAULT (datetime('now'))
);''',
  r'''CREATE TABLE IF NOT EXISTS monthly_summary (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    year              INTEGER NOT NULL,                -- 2026
    month             INTEGER NOT NULL                 -- 1–12
                              CHECK (month BETWEEN 1 AND 12),
    total_income      REAL    NOT NULL DEFAULT 0.0,    -- Загальні доходи за місяць (UAH)
    total_expense     REAL    NOT NULL DEFAULT 0.0,    -- Загальні витрати за місяць (UAH)
    balance           REAL    GENERATED ALWAYS AS     -- Автообчислюване: дохід − витрата
                              (total_income - total_expense) VIRTUAL,
    is_migrated       INTEGER NOT NULL DEFAULT 0       -- 1 = дані перенесені з Nash-biudzhet.xlsx
                              CHECK (is_migrated IN (0, 1)),
    calculated_at     DATETIME NOT NULL DEFAULT (datetime('now')),

    UNIQUE (year, month)
);''',
  r'''CREATE TABLE IF NOT EXISTS monthly_category_summary (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    year          INTEGER NOT NULL,
    month         INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
    category_name TEXT    NOT NULL REFERENCES categories(name) ON UPDATE CASCADE,
    total         REAL    NOT NULL DEFAULT 0.0,        -- Сума витрат/доходів UAH
    tx_count      INTEGER NOT NULL DEFAULT 0,          -- Кількість транзакцій
    calculated_at DATETIME NOT NULL DEFAULT (datetime('now')),

    UNIQUE (year, month, category_name)
);''',
  r'''CREATE TABLE IF NOT EXISTS assets (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    name          TEXT    NOT NULL,                    -- 'Депозит USD', 'Квартира', 'Автомобіль'
    asset_type    TEXT    NOT NULL
                          CHECK (asset_type IN ('deposit', 'real_estate', 'vehicle', 'other')),
    value         REAL    NOT NULL DEFAULT 0.0,
    currency      TEXT    NOT NULL DEFAULT 'UAH'
                          CHECK (currency IN ('UAH', 'USD', 'EUR')),
    -- Тільки для deposit
    interest_rate REAL,                                -- Відсоткова ставка (%)
    maturity_date DATE,                                -- Дата закінчення депозиту
    bank          TEXT,                                -- Банк де відкрито депозит
    is_active     INTEGER NOT NULL DEFAULT 1
                          CHECK (is_active IN (0, 1)),
    created_at    DATETIME NOT NULL DEFAULT (datetime('now')),
    updated_at    DATETIME NOT NULL DEFAULT (datetime('now'))
);''',
  r'''CREATE TABLE IF NOT EXISTS import_batches (
    id              TEXT    PRIMARY KEY,               -- UUID сесії імпорту
    bank            TEXT    NOT NULL,
    file_name       TEXT    NOT NULL,
    period_start    DATE,
    period_end      DATE,
    tx_total        INTEGER NOT NULL DEFAULT 0,
    tx_imported     INTEGER NOT NULL DEFAULT 0,
    tx_skipped_dup  INTEGER NOT NULL DEFAULT 0,
    tx_skipped_int  INTEGER NOT NULL DEFAULT 0,        -- Внутрішні перекази
    tx_errors       INTEGER NOT NULL DEFAULT 0,
    tx_uncategorized INTEGER NOT NULL DEFAULT 0,
    status          TEXT    NOT NULL DEFAULT 'completed'
                            CHECK (status IN ('completed', 'rolled_back')),
    imported_at     DATETIME NOT NULL DEFAULT (datetime('now'))
);''',
  r'''CREATE INDEX IF NOT EXISTS idx_tx_date
    ON transactions (tx_date);''',
  r'''CREATE INDEX IF NOT EXISTS idx_tx_year_month
    ON transactions (strftime('%Y', tx_date), strftime('%m', tx_date))
    WHERE is_deleted = 0 AND is_internal = 0;''',
  r'''CREATE INDEX IF NOT EXISTS idx_tx_category
    ON transactions (category_name)
    WHERE is_deleted = 0;''',
  r'''CREATE INDEX IF NOT EXISTS idx_tx_bank
    ON transactions (bank)
    WHERE is_deleted = 0;''',
  r'''CREATE INDEX IF NOT EXISTS idx_tx_card
    ON transactions (card_id)
    WHERE is_deleted = 0;''',
  r'''CREATE INDEX IF NOT EXISTS idx_tx_type
    ON transactions (tx_type)
    WHERE is_deleted = 0 AND is_internal = 0;''',
  r'''CREATE INDEX IF NOT EXISTS idx_tx_dedup
    ON transactions (dedup_hash)
    WHERE dedup_hash IS NOT NULL;''',
  r'''CREATE INDEX IF NOT EXISTS idx_tx_description
    ON transactions (description);''',
  r'''CREATE INDEX IF NOT EXISTS idx_tx_parent
    ON transactions (parent_tx_id)
    WHERE parent_tx_id IS NOT NULL;''',
  r'''CREATE INDEX IF NOT EXISTS idx_tx_import_batch
    ON transactions (import_batch_id)
    WHERE import_batch_id IS NOT NULL;''',
  r'''CREATE INDEX IF NOT EXISTS idx_monthly_year_month
    ON monthly_summary (year, month);''',
  r'''CREATE INDEX IF NOT EXISTS idx_monthly_cat_year_month
    ON monthly_category_summary (year, month);''',
  r'''CREATE INDEX IF NOT EXISTS idx_rules_active
    ON rules (source_field, priority DESC)
    WHERE is_active = 1;''',
  r'''CREATE TRIGGER IF NOT EXISTS trg_cards_updated
    AFTER UPDATE ON cards
    BEGIN
        UPDATE cards SET updated_at = datetime('now') WHERE id = NEW.id;
    END;''',
  r'''CREATE TRIGGER IF NOT EXISTS trg_categories_updated
    AFTER UPDATE ON categories
    BEGIN
        UPDATE categories SET updated_at = datetime('now') WHERE id = NEW.id;
    END;''',
  r'''CREATE TRIGGER IF NOT EXISTS trg_rules_updated
    AFTER UPDATE ON rules
    BEGIN
        UPDATE rules SET updated_at = datetime('now') WHERE id = NEW.id;
    END;''',
  r'''CREATE TRIGGER IF NOT EXISTS trg_transactions_updated
    AFTER UPDATE ON transactions
    BEGIN
        UPDATE transactions SET updated_at = datetime('now') WHERE id = NEW.id;
    END;''',
  r'''CREATE TRIGGER IF NOT EXISTS trg_assets_updated
    AFTER UPDATE ON assets
    BEGIN
        UPDATE assets SET updated_at = datetime('now') WHERE id = NEW.id;
    END;''',
  r'''CREATE VIEW IF NOT EXISTS v_transactions AS
SELECT
    t.id,
    t.tx_date,
    t.posting_date,
    t.amount,
    t.currency,
    t.amount_uah,
    t.exchange_rate,
    t.tx_type,
    t.description,
    t.category_name,
    c.icon          AS category_icon,
    c.color_hex     AS category_color,
    t.bank_category,
    t.bank,
    t.card_id,
    k.card_number,
    k.display_name  AS card_display_name,
    t.mcc,
    t.commission,
    t.cashback,
    t.balance_after,
    t.is_manual,
    t.import_source,
    t.import_date,
    t.created_at
FROM transactions t
LEFT JOIN categories c ON c.name = t.category_name
LEFT JOIN cards     k ON k.id   = t.card_id
WHERE t.is_deleted = 0
  AND t.is_internal = 0;''',
  r'''CREATE VIEW IF NOT EXISTS v_monthly_totals AS
SELECT
    CAST(strftime('%Y', tx_date) AS INTEGER) AS year,
    CAST(strftime('%m', tx_date) AS INTEGER) AS month,
    SUM(CASE WHEN tx_type = 'income'  THEN amount_uah ELSE 0 END) AS income,
    SUM(CASE WHEN tx_type = 'expense' THEN amount_uah ELSE 0 END) AS expense,
    SUM(CASE WHEN tx_type = 'income'  THEN amount_uah
             WHEN tx_type = 'expense' THEN -amount_uah
             ELSE 0 END)                                          AS balance,
    COUNT(*)                                                       AS tx_count
FROM transactions
WHERE is_deleted = 0
  AND is_internal = 0
GROUP BY year, month
ORDER BY year, month;''',
];
