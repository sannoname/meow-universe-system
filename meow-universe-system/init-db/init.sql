-- 啟用 UUID 生成 (非必須，但在分散式系統中很好用)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- 1. 帳號與組織 (Identity & Organization)
-- ==========================================

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) CHECK (role IN ('Admin', 'Merchant', 'Worker', 'Customer')),
    merchant_id INT, -- 稍後建立外鍵
    api_key VARCHAR(100) UNIQUE DEFAULT uuid_generate_v4()::text,
    balance DECIMAL(15, 2) DEFAULT 0.00 CHECK (balance >= 0), -- [NEW] 防止餘額變負數
    is_active BOOLEAN DEFAULT TRUE, -- [NEW] 可停權帳號
    last_login_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE merchants (
    id SERIAL PRIMARY KEY,
    admin_id INT REFERENCES users(id),
    merchant_name VARCHAR(100) NOT NULL,
    min_order_value DECIMAL(10, 2) DEFAULT 0.00,
    config_json JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 補回 users 的外鍵
ALTER TABLE users ADD CONSTRAINT fk_merchant FOREIGN KEY (merchant_id) REFERENCES merchants(id) ON DELETE SET NULL;

-- [NEW] 資金流水帳 (非常重要！取代單純的 balance 修改)
CREATE TABLE transaction_history (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    amount DECIMAL(15, 2) NOT NULL, -- 正數為充值/收入，負數為扣款
    type VARCHAR(20) CHECK (type IN ('Deposit', 'Payment', 'Commission', 'Refund', 'Adjustment')),
    reference_id INT, -- 可關聯 orders_id 或 task_id
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- 2. 商品監控 (Product Monitoring)
-- ==========================================

CREATE TABLE product_catalog (
    id SERIAL PRIMARY KEY,
    handle VARCHAR(100) UNIQUE NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    source_url TEXT,
    tags TEXT[],
    status VARCHAR(20) DEFAULT 'Monitoring' CHECK (status IN ('Monitoring', 'Available', 'Sold_Out')),
    is_monitoring BOOLEAN DEFAULT TRUE, -- [NEW] 允許商家手動暫停監控
    last_checked_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE product_variants (
    id SERIAL PRIMARY KEY,
    product_id INT REFERENCES product_catalog(id) ON DELETE CASCADE,
    v_id VARCHAR(50) NOT NULL,
    v_title VARCHAR(100),
    price DECIMAL(10, 2) NOT NULL,
    purchase_limit INT DEFAULT 1,
    stock_status VARCHAR(20) DEFAULT 'Unknown', -- [NEW] 紀錄該變體的具體庫存狀態
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- 3. 許願池 (Wishlist)
-- ==========================================

CREATE TABLE wishlist (
    id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES users(id),
    merchant_id INT REFERENCES merchants(id),
    item_url TEXT NOT NULL,
    target_qty INT DEFAULT 1,
    expected_price DECIMAL(10, 2),
    created_at_ms BIGINT NOT NULL, -- 核心排序依據
    status VARCHAR(20) DEFAULT 'Waiting' CHECK (status IN ('Waiting', 'Allocated', 'Fulfilled', 'Cancelled')),
    allocated_task_id INT -- [NEW] 追蹤這筆許願被分配給哪個任務了
);

-- ==========================================
-- 4. 任務配發 (Task Allocation)
-- ==========================================

CREATE TABLE allocation_tasks (
    id SERIAL PRIMARY KEY,
    merchant_id INT REFERENCES merchants(id),
    worker_id INT REFERENCES users(id),
    variant_id INT REFERENCES product_variants(id),
    assigned_qty INT NOT NULL,
    min_order_total DECIMAL(10, 2),
    backup_variant_id INT REFERENCES product_variants(id),
    checkout_url TEXT,
    status VARCHAR(20) DEFAULT 'Pending' CHECK (status IN ('Pending', 'Executing', 'Success', 'PartialSuccess', 'Failed', 'Expired')),
    expires_at TIMESTAMP, -- [NEW] 任務過期時間 (例如發出後 10 分鐘)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE worker_feedback (
    id SERIAL PRIMARY KEY,
    task_id INT UNIQUE REFERENCES allocation_tasks(id) ON DELETE CASCADE,
    actual_qty INT DEFAULT 0,
    receipt_img VARCHAR(255),
    checkout_link_backup TEXT,
    worker_note TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- 5. 訂單與結算 (Orders & Settlement)
-- ==========================================

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES users(id),
    merchant_id INT REFERENCES merchants(id),
    total_amount DECIMAL(15, 2),
    order_status VARCHAR(20) DEFAULT 'Pre_Order' CHECK (order_status IN ('Pre_Order', 'Secured', 'Shipped', 'Closed', 'Cancelled')),
    deposit_status BOOLEAN DEFAULT FALSE,
    booking_time TIMESTAMP NOT NULL,
    related_task_id INT REFERENCES allocation_tasks(id), -- [NEW] 關聯是哪一次搶購任務買到的
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE system_logs (
    id SERIAL PRIMARY KEY,
    operator_id INT REFERENCES users(id), -- 改名 operator 比較通用
    action_type VARCHAR(50),
    payload JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE merchant_settlements (
    id SERIAL PRIMARY KEY,
    merchant_id INT REFERENCES merchants(id),
    period_start TIMESTAMP,
    period_end TIMESTAMP,
    total_successful_qty INT DEFAULT 0,
    fee_total DECIMAL(15, 2) DEFAULT 0.00,
    status VARCHAR(20) DEFAULT 'Pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ==========================================
-- 索引優化 (Performance Indexing)
-- ==========================================
CREATE INDEX idx_users_api_key ON users(api_key); -- Extension 驗證用
CREATE INDEX idx_wishlist_sort ON wishlist(merchant_id, created_at_ms) WHERE status = 'Waiting'; -- 配單算法核心索引
CREATE INDEX idx_product_monitor ON product_catalog(status) WHERE is_monitoring = TRUE; -- 爬蟲只抓需要的
CREATE INDEX idx_tasks_worker ON allocation_tasks(worker_id, status); -- 小幫手查詢任務用