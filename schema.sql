-- RK Traders : database schema (SQLite)

CREATE TABLE IF NOT EXISTS settings (
    key   TEXT PRIMARY KEY,
    value TEXT
);

CREATE TABLE IF NOT EXISTS branches (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    code    TEXT NOT NULL UNIQUE,          -- short code used in invoice number, e.g. KOL
    name    TEXT NOT NULL,
    address TEXT,
    phone   TEXT,
    gstin   TEXT,
    active  INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS counters (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    branch_id INTEGER NOT NULL REFERENCES branches(id),
    code      TEXT NOT NULL,               -- e.g. C1
    name      TEXT NOT NULL,
    next_seq  INTEGER NOT NULL DEFAULT 1,  -- next invoice sequence number for this counter
    active    INTEGER NOT NULL DEFAULT 1,
    UNIQUE(branch_id, code)
);

CREATE TABLE IF NOT EXISTS users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    username      TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    full_name     TEXT NOT NULL,
    role          TEXT NOT NULL CHECK (role IN ('admin','manager','cashier')),
    branch_id     INTEGER REFERENCES branches(id),   -- NULL for admin = all branches
    active        INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS categories (
    id   INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS products (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT NOT NULL,
    category_id     INTEGER REFERENCES categories(id),
    unit            TEXT NOT NULL DEFAULT 'pcs',      -- pcs, kg, g, ltr, ml, packet, box, dozen
    hsn             TEXT,
    gst_rate        REAL NOT NULL DEFAULT 0,          -- 0, 5, 12, 18, 28
    purchase_price  REAL NOT NULL DEFAULT 0,          -- cost per unit (GST inclusive)
    selling_price   REAL NOT NULL DEFAULT 0,          -- sale price per unit (GST inclusive)
    mrp             REAL,
    low_stock_level REAL NOT NULL DEFAULT 5,
    active          INTEGER NOT NULL DEFAULT 1
);

-- stock is kept per branch
CREATE TABLE IF NOT EXISTS stock (
    product_id INTEGER NOT NULL REFERENCES products(id),
    branch_id  INTEGER NOT NULL REFERENCES branches(id),
    quantity   REAL NOT NULL DEFAULT 0,
    PRIMARY KEY (product_id, branch_id)
);

CREATE TABLE IF NOT EXISTS suppliers (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    name    TEXT NOT NULL,
    phone   TEXT,
    gstin   TEXT,
    address TEXT
);

CREATE TABLE IF NOT EXISTS customers (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    name           TEXT NOT NULL,
    phone          TEXT,
    address        TEXT,
    credit_balance REAL NOT NULL DEFAULT 0     -- amount the customer owes (udhaar)
);

CREATE TABLE IF NOT EXISTS purchases (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    branch_id   INTEGER NOT NULL REFERENCES branches(id),
    supplier_id INTEGER REFERENCES suppliers(id),
    invoice_no  TEXT,                              -- supplier's bill number
    date        TEXT NOT NULL,
    total       REAL NOT NULL DEFAULT 0,
    note        TEXT,
    created_by  INTEGER REFERENCES users(id),
    created_at  TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE TABLE IF NOT EXISTS purchase_items (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    purchase_id INTEGER NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
    product_id  INTEGER NOT NULL REFERENCES products(id),
    quantity    REAL NOT NULL,
    unit_cost   REAL NOT NULL,
    total       REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS sales (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_no   TEXT NOT NULL UNIQUE,
    branch_id    INTEGER NOT NULL REFERENCES branches(id),
    counter_id   INTEGER NOT NULL REFERENCES counters(id),
    customer_id  INTEGER REFERENCES customers(id),
    date         TEXT NOT NULL,                     -- YYYY-MM-DD
    created_at   TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    subtotal     REAL NOT NULL,                     -- sum of line totals before discount (GST inclusive)
    discount     REAL NOT NULL DEFAULT 0,
    taxable      REAL NOT NULL,                     -- after discount, without GST
    cgst         REAL NOT NULL,
    sgst         REAL NOT NULL,
    round_off    REAL NOT NULL DEFAULT 0,
    grand_total  REAL NOT NULL,
    payment_mode TEXT NOT NULL,                     -- Cash, UPI, Card, Credit
    paid_amount  REAL NOT NULL DEFAULT 0,
    credit_amount REAL NOT NULL DEFAULT 0,          -- part put on customer's udhaar
    created_by   INTEGER REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS sale_items (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    sale_id    INTEGER NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id),
    name       TEXT NOT NULL,
    hsn        TEXT,
    unit       TEXT,
    quantity   REAL NOT NULL,
    unit_price REAL NOT NULL,                       -- GST inclusive price used
    cost_price REAL NOT NULL DEFAULT 0,             -- purchase price at time of sale (for profit)
    gst_rate   REAL NOT NULL,
    taxable    REAL NOT NULL,
    tax        REAL NOT NULL,
    total      REAL NOT NULL
);

-- money received from customers against udhaar
CREATE TABLE IF NOT EXISTS payments (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id INTEGER NOT NULL REFERENCES customers(id),
    branch_id   INTEGER REFERENCES branches(id),
    date        TEXT NOT NULL,
    amount      REAL NOT NULL,
    mode        TEXT NOT NULL,
    note        TEXT,
    created_by  INTEGER REFERENCES users(id)
);

-- manual stock corrections (damage, expiry, counting difference, transfer)
CREATE TABLE IF NOT EXISTS stock_adjustments (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    branch_id  INTEGER NOT NULL REFERENCES branches(id),
    product_id INTEGER NOT NULL REFERENCES products(id),
    change_qty REAL NOT NULL,                        -- +ve adds, -ve removes
    reason     TEXT,
    date       TEXT NOT NULL,
    created_by INTEGER REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(date);
CREATE INDEX IF NOT EXISTS idx_sales_branch ON sales(branch_id);
CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);

-- which invoices a customer payment (receipt) was applied to
CREATE TABLE IF NOT EXISTS payment_allocations (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_id INTEGER NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
    sale_id    INTEGER NOT NULL REFERENCES sales(id),
    amount     REAL NOT NULL
);

-- messages between branches (threads: replies have parent_id)
CREATE TABLE IF NOT EXISTS messages (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    parent_id      INTEGER REFERENCES messages(id),
    from_user_id   INTEGER REFERENCES users(id),
    from_branch_id INTEGER NOT NULL REFERENCES branches(id),
    to_branch_id   INTEGER NOT NULL REFERENCES branches(id),
    kind           TEXT NOT NULL DEFAULT 'message',    -- message | stock_request
    subject        TEXT,
    body           TEXT,
    product_id     INTEGER REFERENCES products(id),
    quantity       REAL,                                -- requested quantity
    sent_quantity  REAL,                                -- quantity actually transferred
    status         TEXT NOT NULL DEFAULT 'open',        -- open | sent | declined | closed
    is_read        INTEGER NOT NULL DEFAULT 0,
    created_at     TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);
CREATE INDEX IF NOT EXISTS idx_messages_to ON messages(to_branch_id, is_read);

-- notices from admin/managers to staff
CREATE TABLE IF NOT EXISTS notices (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    from_user_id INTEGER NOT NULL REFERENCES users(id),
    title        TEXT NOT NULL,
    body         TEXT,
    audience     TEXT,                                  -- human readable description of who got it
    created_at   TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);

CREATE TABLE IF NOT EXISTS notice_recipients (
    notice_id INTEGER NOT NULL REFERENCES notices(id) ON DELETE CASCADE,
    user_id   INTEGER NOT NULL REFERENCES users(id),
    read_at   TEXT,
    PRIMARY KEY (notice_id, user_id)
);

-- staff leave applications
CREATE TABLE IF NOT EXISTS leaves (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id        INTEGER NOT NULL REFERENCES users(id),
    branch_id      INTEGER REFERENCES branches(id),
    leave_type     TEXT NOT NULL,                     -- Casual, Sick, Earned, Unpaid, Other
    from_date      TEXT NOT NULL,
    to_date        TEXT NOT NULL,
    days           INTEGER NOT NULL,
    reason         TEXT,
    document       TEXT,                              -- stored file name in uploads/leave
    document_name  TEXT,                              -- original file name
    status         TEXT NOT NULL DEFAULT 'pending',   -- pending | approved | rejected | cancelled
    decided_by     INTEGER REFERENCES users(id),
    decided_at     TEXT,
    decision_note  TEXT,
    overridden_by  INTEGER REFERENCES users(id),      -- admin who changed a manager's decision
    overridden_at  TEXT,
    override_note  TEXT,
    created_at     TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);

-- login audit: one row per login
CREATE TABLE IF NOT EXISTS login_sessions (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id       INTEGER NOT NULL REFERENCES users(id),
    branch_id     INTEGER REFERENCES branches(id),
    counter_id    INTEGER REFERENCES counters(id),
    login_at      TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    last_seen_at  TEXT,
    logout_at     TEXT,
    end_reason    TEXT,                               -- logout | relogin | (NULL = still open)
    ip            TEXT,
    user_agent    TEXT
);
CREATE INDEX IF NOT EXISTS idx_login_sessions_user ON login_sessions(user_id, login_at);

-- prizes / awards given to staff
CREATE TABLE IF NOT EXISTS awards (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id     INTEGER NOT NULL REFERENCES users(id),
    branch_id   INTEGER REFERENCES branches(id),
    given_by    INTEGER NOT NULL REFERENCES users(id),
    title       TEXT NOT NULL,
    prize       TEXT,
    note        TEXT,
    period_from TEXT,
    period_to   TEXT,
    created_at  TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);

-- leave entitlement rules per leave type (set by admin)
CREATE TABLE IF NOT EXISTS leave_policies (
    leave_type            TEXT PRIMARY KEY,
    days_per_year         INTEGER NOT NULL DEFAULT 0,   -- 0 = no limit (e.g. Unpaid)
    eligible_after_months INTEGER NOT NULL DEFAULT 0,   -- 0 = available immediately after joining
    sort_order            INTEGER NOT NULL DEFAULT 0,
    active                INTEGER NOT NULL DEFAULT 1
);

-- activity log: every action by every user (admin only)
CREATE TABLE IF NOT EXISTS audit_log (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    at        TEXT NOT NULL DEFAULT (datetime('now','localtime')),
    user_id   INTEGER,
    username  TEXT,
    role      TEXT,
    branch_id INTEGER,
    ip        TEXT,
    method    TEXT,
    endpoint  TEXT,
    action    TEXT,                 -- human readable, e.g. "Created bill"
    entity_id TEXT,                 -- id or number of the thing acted on
    details   TEXT,                 -- JSON of submitted data (passwords removed)
    status    INTEGER               -- HTTP status of the response
);
CREATE INDEX IF NOT EXISTS idx_audit_log_at ON audit_log(at);

-- promotional offers applied automatically at billing
CREATE TABLE IF NOT EXISTS offers (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL,
    type        TEXT NOT NULL,          -- product_pct | product_price | buy_x_get_y | category_pct | bill_pct | bill_flat
    product_id  INTEGER REFERENCES products(id),
    category_id INTEGER REFERENCES categories(id),
    value       REAL NOT NULL DEFAULT 0, -- percent, special price, or flat amount depending on type
    buy_qty     REAL,                    -- for buy_x_get_y
    free_qty    REAL,
    min_bill    REAL NOT NULL DEFAULT 0, -- for bill offers
    from_date   TEXT NOT NULL,
    to_date     TEXT NOT NULL,
    branch_id   INTEGER REFERENCES branches(id),   -- NULL = all branches
    active      INTEGER NOT NULL DEFAULT 1,
    created_by  INTEGER REFERENCES users(id),
    created_at  TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);

-- HR: staff profile and generated documents
CREATE TABLE IF NOT EXISTS staff_profiles (
    user_id           INTEGER PRIMARY KEY REFERENCES users(id),
    emp_code          TEXT,
    designation       TEXT,
    phone             TEXT,
    address           TEXT,
    dob               TEXT,
    blood_group       TEXT,
    photo             TEXT,                       -- file in uploads/photos
    monthly_salary    REAL NOT NULL DEFAULT 0,
    hra               REAL NOT NULL DEFAULT 0,
    allowances        REAL NOT NULL DEFAULT 0,
    bank_name         TEXT,
    account_no        TEXT,
    ifsc              TEXT,
    pan               TEXT,
    emergency_contact TEXT,
    updated_at        TEXT
);

CREATE TABLE IF NOT EXISTS staff_documents (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id    INTEGER NOT NULL REFERENCES users(id),
    kind       TEXT NOT NULL,                     -- offer_letter | id_card | salary_slip
    title      TEXT NOT NULL,
    period     TEXT,                              -- YYYY-MM for salary slips
    file       TEXT NOT NULL,                     -- pdf in uploads/docs
    data       TEXT,                              -- JSON snapshot of the figures used
    created_by INTEGER REFERENCES users(id),
    created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
);
