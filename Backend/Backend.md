# Backend Wiring Tracker

FastAPI edge controller on Raspberry Pi 3 B+ (`Pi-Backend`, port 5000) and unified backend on store laptop (`Central-Server`, port 8000).

## 1. Pi-Backend REST Endpoints (`http://<PI_IP>:5000`)

| Method | Endpoint | Request Payload | Response Schema | Description |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/status` | _None_ | `{"cart_id": str, "state": str, "user_id": str\|null, "pending_barcode": str\|null, ...}` | Current FSM state & hardware status |
| `POST` | `/api/vision-event` | `{"camera_id": str, "event": "CROSS_IN"\|"CROSS_OUT", "detected_class": str, "timestamp": float}` | `{"status": "processed", "cart_id": str, "current_state": str}` | Ingests phone camera crossings over USB |
| `POST` | `/api/session/pair-notify`<br>`/api/cart/activate` | `{"cart_id": str, "user_id": str}` | `{"status": "paired", "cart_id": str, "user_id": str, "current_state": str}` | Central Server notifies cart is paired |
| `POST` | `/api/session/reset`<br>`/api/cart/checkout` | `{"cart_id": str, "status": "PAID"}` | `{"status": "checkout_acknowledged", "cart_id": str, "current_state": str}` | Central Server notifies checkout complete |
| `POST` | `/api/debug/simulate-scan` | `{"barcode": str}` | `{"status": "scan_simulated", "barcode": str, "current_state": str}` | Injects simulated barcode scan |
| `POST` | `/api/debug/clear-alert` | _None_ | `{"status": "alert_cleared", "current_state": str}` | Manually clears alarm & resets to STANDBY |

*Pi Outbound Telemetry:* Dispatches `POST http://<SERVER_IP>:8000/api/cart/sync` on verified drop (`ADD_ITEM`), removal (`REMOVE_ITEM`), or anomaly (`UNSCANNED_DROP`).

## 2. Central-Server REST Endpoints (`http://<SERVER_IP>:8000`)

| Method | Endpoint | Request Payload | Response Schema | Description |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/cart/register-pi` | `{"cart_id": str, "pi_ip": str, "pi_port": int}` | `{"status": "registered", "cart_id": str, "pi_ip": str, "pi_port": int, "server_time": float}` | Pi startup registration |
| `POST` | `/api/session/pair` | `{"cart_id": str, "user_id": str, "timestamp"?: str}` | `{"status": "paired", "session_id": str, "cart_id": str, "user_id": str, "current_state": "IDLE", "store_name": str, "message": str}` | Pairs app session with cart |
| `POST` | `/api/cart/sync` | `{"cart_id": str, "action": "ADD_ITEM"\|"REMOVE_ITEM"\|"UNSCANNED_DROP", "detected_class": str, "timestamp": float, "barcode"?: str}` | `{"status": str, "action": str, "cart_id": str, "barcode"?: str, "items_count": int, "running_total": float}` | Upstream sensor sync from Pi (auto-creates fallback product for unseeded barcodes) |
| `POST` | `/api/cart/alert` | `{"cart_id": str, "alert_type": str, "detected_class": str, "message": str, "timestamp"?: float, "is_resolved": bool}` | `{"status": "terminated", "alert_id": int, "cart_id": str, "alert_type": str}` | Security alert ingestion |
| `POST` | `/api/session/checkout` | `{"cart_id": str, "status": "PAID", "payment_method": str, "amount": float, "timestamp"?: str}` | `{"status": "PAID", "cart_id": str, "session_id": str, "receipt_id": str, "exit_pass_token": str, "amount_paid": float, "timestamp": str, "message": str}` | Self-checkout & exit pass |
| `GET` | `/api/products/search` | Query: `q?: str`, `category?: str` | `[{"id": str, "barcode": str, "sku": str, "name": str, "brand": str, "category": str, "aisle": str, "shelf_section": str, "map_x_coord": float, "map_y_coord": float, "price": float, "original_price": float, "stock": int, "distance_meters": float, "image_url"?: str}]` | In-store catalog search |
| `GET` | `/api/products/barcode/{barcode}` | Path: `barcode: str` | `ProductResponse` schema (barcode, sku, name, brand, category, aisle, mrp, sale_price, stock_qty) | Product lookup by barcode (auto-creates fallback product if unseeded) |
| `GET` | `/api/products` | _None_ | `List[ProductResponse]` | Full product inventory |
| `POST` | `/api/products` | `{"barcode": str, "sku": str, "name": str, "brand"?: str, "category"?: str, "aisle"?: str, "mrp": float, "sale_price": float, "stock_qty"?: int}` | `ProductResponse` | Create or update product |
| `GET` | `/api/admin/carts` | _None_ | `[{"cart_id": str, "state": str, "battery_level": int, "ip_address": str, "user_id"?: str, "items_count": int, "running_total": float, ...}]` | All active carts & status |
| `GET` | `/api/cart/{cart_id}` | Path: `cart_id: str` | `{"cart_id": str, "user_id"?: str, "status": str, "battery_level": int, "running_total": float, "items_count": int, "items": list, ...}` | Cart snapshot & line items |
| `GET` | `/api/admin/alerts` | Query: `unresolved_only?: bool` | `[{"id": int, "cart_id": str, "alert_type": str, "message": str, "timestamp": float, "is_resolved": bool}]` | Security alerts audit log |
| `POST` | `/api/admin/alerts/{alert_id}/resolve` | Path: `alert_id: int` | `{"status": "resolved", "alert_id": int, "is_resolved": true}` | Resolves security alert |
| `GET` | `/api/admin/stats` | _None_ | `{"visitors_today": int, "active_customers": int, "active_baskets": int, "avg_checkout_sec": int, "avg_basket_val": float, "total_revenue_today": float, "store_status": str, "fleet_health_percent": float}` | Real-time admin KPI counters |
| `POST` | `/api/auth/login` | `{"phone": str, "password"?: str}` | `{"status": "authenticated", "user_id": str, "name": str, "phone": str, "loyalty_tier": str, "reward_points": int}` | Shopper auth / auto-provision |
| `GET` | `/api/orders/history/{user_id}` | Path: `user_id: str` | `[{"order_id": str, "store_name": str, "total_paid": float, "items_count": int, "receipt_id": str, "exit_token": str, "items": list, ...}]` | Customer order receipts |
| `GET` | `/api/status` | _None_ | `{"status": "healthy", "server": "Central-Server", "version": "1.0.0", "websocket_stats": dict}` | Server health & WS stats |

## 3. WebSocket Endpoints (`ws://<SERVER_IP>:8000`)

### `/ws/cart/{cart_id}` (Customer Mobile App)
- **Initial Snapshot (on connect):**
  `{"action": "CART_UPDATED", "cart_id": str, "session_id": str, "status": str, "running_total": float, "total_savings": float, "items_count": int, "items": list, "timestamp": float}`
- **Verified Drop Broadcast (`ADD_ITEM`):**
  `{"action": "ADD_ITEM", "type": "CART_UPDATED", "cart_id": str, "barcode": str, "name": str, "price": float, "original_price": float, "quantity": int, "category": str, "aisle": str, "running_total": float, "total_savings": float, "items_count": int, "items": list, "timestamp": float}`
- **Item Removal Broadcast (`REMOVE_ITEM`):**
  `{"action": "REMOVE_ITEM", "cart_id": str, "barcode": str, "running_total": float, "total_savings": float, "items_count": int, "items": list, "timestamp": float}`
- **Security Anomaly Broadcast (`UNSCANNED_DROP`):**
  `{"action": "STOP_SYNC_AND_EXIT", "event": "UNSCANNED_DROP", "session_terminated": true, "cart_id": str, "status": "TERMINATED", "running_total": 0.0, "items_count": 0, "items": [], "message": str, "timestamp": float}`
- **Checkout Reset Broadcast (`SESSION_RESET`):**
  `{"action": "SESSION_RESET", "cart_id": str, "status": "PAID", "receipt_id": str, "exit_pass_token": str, "amount_paid": float, "message": str, "timestamp": float}`
- **Heartbeat:** Client sends `{"type": "ping"}` or `"ping"`; Server returns `{"type": "pong", "timestamp": float}`.

### `/ws/admin` (Store Admin Dashboard)
- **Initial Snapshot (on connect):** `{"type": "INITIAL_SNAPSHOT", "carts": list, "alerts": list, "timestamp": float}`
- **Cart Paired:** `{"type": "CART_PAIRED", "cart_id": str, "session_id": str, "user_id": str, "user_name": str, "status": "ACTIVE", "running_total": float, "items_count": int, "timestamp": float}`
- **Cart Updated (`ADD_ITEM` / `REMOVE_ITEM`):** `{"type": "CART_UPDATED", "cart_id": str, "action": str, "barcode": str, "status": str, "items_count": int, "running_total": float, "timestamp": float}`
- **Security Anomaly:** `{"type": "SECURITY_ALERT", "event": "UNSCANNED_DROP", "session_terminated": true, "alert_id": int, "cart_id": str, "status": "TERMINATED", "message": str, "timestamp": float}`
- **Alert Resolved:** `{"type": "ALERT_RESOLVED", "alert_id": int, "cart_id": str}`
- **Checkout Complete:** `{"type": "CHECKOUT_COMPLETE", "cart_id": str, "receipt_id": str, "total_paid": float, "items_count": int, "timestamp": float}`

### `/ws/pi/{cart_id}` (Raspberry Pi Edge Controller)
- **On Connect:** `{"action": "CONNECTED", "cart_id": str, "status": "online", "server_time": float}`
- **Pair Push:** `{"command": "SESSION_PAIRED", "action": "SESSION_PAIRED", "cart_id": str, "user_id": str, "session_id": str, "timestamp": float}`
- **Checkout Reset Push:** `{"command": "SESSION_RESET", "action": "SESSION_RESET", "cart_id": str, "status": "PAID", "timestamp": float}`

## 4. Database Schema (`Central-Server/models.py`)

| Table Name | Primary Key | Columns (Name & Type) | Foreign Keys & Indexes |
| :--- | :--- | :--- | :--- |
| `products` | `barcode` (String 32) | `barcode`, `sku` (String 64, Unique), `name` (String 256), `brand` (String 128), `category` (String 64), `aisle` (String 64), `shelf_section` (String 64), `map_x_coord` (Float), `map_y_coord` (Float), `mrp` (Float), `sale_price` (Float), `stock_qty` (Integer), `unit_weight_grams` (Integer), `image_url` (Text), `created_at` (DateTime) | Index on `barcode` |
| `active_carts` | `cart_id` (String 32) | `cart_id`, `user_id` (String 64), `status` (String 32), `total_amount` (Float), `item_count` (Integer), `store_id` (String 64), `battery_level` (Integer), `ip_address` (String 45), `session_id` (String 64), `receipt_id` (String 64), `exit_pass_token` (String 256), `updated_at` (DateTime), `created_at` (DateTime) | Index on `cart_id` |
| `cart_items` | `id` (Integer Autoincrement) | `id`, `cart_id` (String 32), `session_id` (String 64), `barcode` (String 32), `product_name` (String 256), `unit_price` (Float), `original_price` (Float), `quantity` (Integer), `weight_grams` (Integer), `vision_verified` (Boolean), `added_at` (DateTime) | FK: `barcode` -> `products.barcode`<br>Indexes: `id`, `cart_id`, `session_id` |
| `security_alerts` | `id` (Integer Autoincrement) | `id`, `cart_id` (String 32), `session_id` (String 64), `alert_type` (String 64), `event_type` (String 64), `detected_class` (String 64), `message` (Text), `timestamp` (Float), `is_resolved` (Boolean), `resolved` (Boolean), `created_at` (DateTime) | Indexes: `id`, `cart_id` |
| `users` | `id` (String 64) | `id`, `name` (String 128), `phone` (String 20, Unique), `password_hash` (String 256), `loyalty_tier` (String 32), `reward_points` (Integer), `created_at` (DateTime) | Indexes: `id`, `phone` |
| `cart_sessions` | `session_id` (String 64) | `session_id`, `cart_id` (String 32), `user_id` (String 64), `status` (String 32), `total_mrp` (Float), `running_total` (Float), `total_savings` (Float), `items_count` (Integer), `payment_method` (String 64), `receipt_id` (String 64), `exit_pass_token` (String 256), `started_at` (DateTime), `ended_at` (DateTime) | Indexes: `session_id`, `cart_id`, `user_id` |
| `orders` | `order_id` (String 64) | `order_id`, `user_id` (String 64), `cart_id` (String 32), `store_name` (String 128), `total_mrp` (Float), `total_paid` (Float), `total_savings` (Float), `items_count` (Integer), `payment_method` (String 64), `receipt_id` (String 64), `exit_token` (String 256), `status` (String 32), `items_json` (Text), `created_at` (DateTime) | Indexes: `order_id`, `user_id` |
