# Smart Shopping Trolley & Retail Ecosystem - Database Schema (PostgreSQL / SQLite)

This document defines the formal relational schema specifications for the Central Store Server (`Central-Server` @ Port 8000) running PostgreSQL or SQLite.

---

## 1. Relational Tables Definition

### 1.1. `users`
Shopper authentication, identity, and loyalty tier rewards.
```sql
CREATE TABLE users (
    id VARCHAR(64) PRIMARY KEY,              -- e.g. 'U12345'
    name VARCHAR(128) NOT NULL,               -- e.g. 'Sunny Kumar Sah'
    phone VARCHAR(20) UNIQUE NOT NULL,        -- e.g. '+91 98765 43210'
    password_hash VARCHAR(256),              -- bcrypt/argon2 hash
    loyalty_tier VARCHAR(32) DEFAULT 'Gold', -- 'Bronze', 'Silver', 'Gold', 'Platinum'
    reward_points INTEGER DEFAULT 2450,       -- Active loyalty points balance
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 1.2. `carts`
Physical smart trolley hardware fleet status and battery telemetry.
```sql
CREATE TABLE carts (
    cart_id VARCHAR(32) PRIMARY KEY,          -- e.g. 'CART_01', 'CR-408'
    store_id VARCHAR(64) NOT NULL,            -- e.g. 'DMART_HSR_01'
    state VARCHAR(32) DEFAULT 'STANDBY',      -- 'STANDBY', 'IDLE', 'PENDING_VERIFICATION', 'VERIFIED', 'ALERT', 'PAID'
    battery_level INTEGER DEFAULT 88,         -- Percentage (0 - 100)
    ip_address VARCHAR(45),                   -- Local Wi-Fi IP of Raspberry Pi (e.g. '192.168.1.105')
    last_ping TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 1.3. `products`
In-store retail catalog, barcodes, shelf coordinates, and live inventory.
```sql
CREATE TABLE products (
    barcode VARCHAR(32) PRIMARY KEY,          -- e.g. '8901058852234' (EAN-13)
    sku VARCHAR(64) UNIQUE NOT NULL,          -- e.g. 'MAGGI-NOODLE-204G'
    name VARCHAR(256) NOT NULL,               -- e.g. 'Maggi 2-Minute Masala Noodles'
    brand VARCHAR(128) NOT NULL,              -- e.g. 'Nestlé'
    category VARCHAR(64) NOT NULL,           -- e.g. 'Instant Snack', 'Dairy', 'Flours'
    aisle VARCHAR(32) NOT NULL,              -- e.g. 'Aisle 4', 'Aisle 3', 'Aisle 2A'
    shelf_section VARCHAR(32) NOT NULL,       -- e.g. 'Sec 2', 'Bay 14', 'Chillers A1'
    map_x_coord DOUBLE PRECISION DEFAULT 0.0, -- In-store 2D vector coordinate X (0.0 - 100.0)
    map_y_coord DOUBLE PRECISION DEFAULT 0.0, -- In-store 2D vector coordinate Y (0.0 - 100.0)
    mrp NUMERIC(10, 2) NOT NULL,              -- Maximum Retail Price e.g. 56.00
    sale_price NUMERIC(10, 2) NOT NULL,       -- D-Mart Discounted Price e.g. 52.00
    stock_qty INTEGER NOT NULL DEFAULT 50,    -- Real-time in-store inventory level
    unit_weight_grams INTEGER NOT NULL,       -- Net product weight e.g. 204
    image_url TEXT,                           -- Cloudinary / S3 / Google Stitch public asset URL
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 1.4. `cart_sessions`
Active shopping trip sessions binding a shopper to a smart trolley.
```sql
CREATE TABLE cart_sessions (
    session_id VARCHAR(64) PRIMARY KEY,       -- e.g. 'SESS-20261024-001'
    cart_id VARCHAR(32) NOT NULL REFERENCES carts(cart_id),
    user_id VARCHAR(64) NOT NULL REFERENCES users(id),
    status VARCHAR(32) DEFAULT 'ACTIVE',      -- 'ACTIVE', 'PAID', 'ABANDONED', 'CLOSED'
    total_mrp NUMERIC(10, 2) DEFAULT 0.00,
    running_total NUMERIC(10, 2) DEFAULT 0.00,
    total_savings NUMERIC(10, 2) DEFAULT 0.00,
    items_count INTEGER DEFAULT 0,
    payment_method VARCHAR(64),               -- 'UPI_FASTPAY', 'CREDIT_CARD', 'NET_BANKING'
    receipt_id VARCHAR(64),                   -- e.g. 'REC-892348'
    exit_pass_token VARCHAR(256),             -- e.g. 'PASS_CART_01_PAID_1729616400'
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP
);
```

### 1.5. `cart_items`
Individual line items accumulated in an active shopping cart basket.
```sql
CREATE TABLE cart_items (
    id SERIAL PRIMARY KEY,
    session_id VARCHAR(64) NOT NULL REFERENCES cart_sessions(session_id),
    barcode VARCHAR(32) NOT NULL REFERENCES products(barcode),
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price NUMERIC(10, 2) NOT NULL,
    original_price NUMERIC(10, 2) NOT NULL,
    weight_grams INTEGER NOT NULL,
    vision_verified BOOLEAN DEFAULT TRUE,     -- Confirmed by Pi dual-camera crossing
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 1.6. `orders`
Immutable completed transactions rendered in customer order history.
```sql
CREATE TABLE orders (
    order_id VARCHAR(64) PRIMARY KEY,         -- e.g. 'ORD-98421'
    user_id VARCHAR(64) NOT NULL REFERENCES users(id),
    cart_id VARCHAR(32) NOT NULL,
    store_name VARCHAR(128) NOT NULL,         -- e.g. 'D-Mart • HyperPulse HSR'
    total_mrp NUMERIC(10, 2) NOT NULL,        -- e.g. 651.00
    total_paid NUMERIC(10, 2) NOT NULL,       -- e.g. 562.00
    total_savings NUMERIC(10, 2) NOT NULL,    -- e.g. 89.00
    items_count INTEGER NOT NULL,             -- e.g. 3
    payment_method VARCHAR(64) NOT NULL,      -- e.g. 'UPI_FASTPAY (PhonePe)'
    receipt_id VARCHAR(64) NOT NULL,          -- e.g. 'REC-892348'
    exit_token VARCHAR(256) NOT NULL,         -- e.g. 'PASS_CART_01_PAID_1729616400'
    status VARCHAR(32) DEFAULT 'Completed',  -- 'Completed', 'Exit Pass Verified'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 1.7. `security_alerts`
Audit trail of real-time security anomalies (`UNSCANNED_DROP`, weight deviations).
```sql
CREATE TABLE security_alerts (
    id SERIAL PRIMARY KEY,
    cart_id VARCHAR(32) NOT NULL,
    session_id VARCHAR(64),
    alert_type VARCHAR(64) NOT NULL,          -- 'UNSCANNED_DROP', 'WEIGHT_MISMATCH'
    message TEXT NOT NULL,
    is_resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```
