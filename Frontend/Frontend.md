# Frontend Wiring Tracker

Client architectures for Buyer Mobile App (`Frontend/App_Frontend`, Flutter) and Store Admin Dashboard (`Frontend/Dashboard`, Next.js/React).

## 1. Flutter Providers & State Variables (`App_Frontend/lib/providers/`)

| Provider | State Variables | Description |
| :--- | :--- | :--- |
| `CartProvider`<br>(`cart_provider.dart`) | `serverHost`: String<br>`serverPort`: int<br>`isMockMode`: bool<br>`isSynced`: bool<br>`cartId`: String?<br>`userId`: String?<br>`storeName`: String?<br>`isPairing`: bool<br>`pairError`: String?<br>`items`: List\<CartItem\><br>`runningTotal`: double<br>`totalSavings`: double<br>`isCheckingOut`: bool<br>`isPaid`: bool<br>`receiptId`: String?<br>`exitPassToken`: String?<br>`paidAt`: DateTime?<br>`activeSecurityAlert`: SecurityAlert? | Primary state manager for trolley pairing, basket synchronization, live running total, checkout, and security anomaly termination (`terminateSyncDueToSecurityAnomaly`). |
| `AuthProvider`<br>(`auth_provider.dart`) | `isAuthenticated`: bool (default true)<br>`userId`: String (`U12345`)<br>`userName`: String (`Alex Morgan`)<br>`userPhone`: String (`+91 98765 43210`)<br>`userEmail`: String<br>`loyaltyTier`: String (`Gold Member`)<br>`rewardPoints`: int (`480`) | Manages shopper session profile, loyalty status, points balance, and login/logout state transitions. |
| `SearchProvider`<br>(`search_provider.dart`) | `query`: String<br>`selectedCategory`: String?<br>`selectedAisle`: String?<br>`isSearching`: bool<br>`recentSearches`: List\<String\><br>`allProducts`: List\<StoreProduct\> | Store catalog search, category filtering, aisle distance calculation, and recent search history tracking. |
| `NavigationController`<br>(`core/navigation_controller.dart`) | `currentIndex`: int<br>`history`: List\<int\> | Bottom navigation bar active tab index (0 to 4) and backward navigation history stack. |

## 2. Flutter Screen Routes (`App_Frontend/lib/screens/`)

| Screen / Widget | File | Role & Navigation Context |
| :--- | :--- | :--- |
| `WelcomeScreen` | `screens/welcome_screen.dart` | Auth gate fallback shown when `AuthProvider.isAuthenticated == false`. |
| `MainNavigationShell` | `main.dart` | Root shell containing `IndexedStack` with 5 bottom tabs and root `PopScope`. |
| ↳ Tab 0: `HomeScreen` / `SyncedScreen` | `home_screen.dart`<br>`synced_screen.dart` | Renders `HomeScreen` (unpaired standby & QR trigger) or `SyncedScreen` (paired cart live telemetry card & items preview) based on `CartProvider.isSynced`. |
| ↳ Tab 1: `SearchScreen` | `screens/search_screen.dart` | In-store catalog search, category chips, and distance wayfinding cards. |
| ↳ Tab 2: `ScanScreen` | `screens/scan_screen.dart` | Camera QR scanner to pair cart (`CART_01`) via `CartProvider.pairCart()`. |
| ↳ Tab 3: `CartScreen` | `screens/cart_screen.dart` | Live bill, item rows with "Vision Verified" badges, running savings, and checkout CTA. |
| ↳ Tab 4: `HistoryScreen` | `screens/history_screen.dart` | Past transaction invoices, receipts, and Digital Exit Pass tokens. |
| `LoginScreen` | `screens/login_screen.dart` | Shopper phone login and OTP verification screen. |
| `SearchedScreen` | `screens/searched_screen.dart` | Detailed search results list with sorting and aisle filter badges. |
| `AisleScreen` | `screens/aisle_screen.dart` | Store map & aisle wayfinding guide for located product. |
| `PaymentScreen` | `screens/payment_screen.dart` | Digital checkout gateway (UPI, Card) triggering `CartProvider.checkout()`. |
| `SettingsScreen` | `screens/settings_screen.dart` | Developer config to dynamically update Laptop IP, port, and toggle mock mode. |
| `UnscannedAlertModal` | `widgets/unscanned_alert_modal.dart` | Attention-seeking red security modal popping up when `CartProvider.hasActiveAlert == true`. |

## 3. Server IP/Port & WebSocket Listeners Configuration

### 3.1. Buyer Mobile App (`App_Frontend`)
- **Central-Server Host & Port:**
  - Static Defaults: `AppConstants.defaultLaptopIp = '10.91.228.169'`, `AppConstants.defaultServerPort = 8000` (`lib/core/constants.dart`).
  - Runtime Overrides: Configured in `SettingsScreen` via `CartProvider.updateServerConfig(host, port, mockMode)`, propagating dynamically to `ApiClient` and `WebSocketService`.
- **WebSocket Endpoint & Listener:**
  - URL: `ws://<HOST>:<PORT>/ws/cart/{cart_id}` managed by `WebSocketService` (`lib/core/websocket_service.dart`).
  - Active Listener: `CartProvider._initServices()` subscribes to:
    - `alertStream`: Receives `UNSCANNED_DROP` or `STOP_SYNC_AND_EXIT` -> triggers `terminateSyncDueToSecurityAnomaly()` which clears cart items, resets running total to 0, disconnects WebSocket, navigates back to Tab 0 (`HomeScreen`), and opens `UnscannedAlertModal`.
    - `cartStream`: Receives `ADD_ITEM`, `REMOVE_ITEM`, or `CART_UPDATED` -> updates `_items`, `_runningTotal`, and `_totalSavings`.
    - `connectionStream`: On WS connect/reconnect while paired -> invokes `refreshCartState()` via `GET /api/cart/{cart_id}` for zero-drift basket recovery.
  - Heartbeat & Resilience: Periodic ping every 30s; 3-second auto-reconnect backoff on disconnect; REST snapshot hydration on pair.

### 3.2. Store Admin Dashboard (`Dashboard`)
- **Central-Server Host & Port:**
  - Configured via environment variable in `Frontend/Dashboard/src/app/dashboard/page.tsx`:
    `process.env.NEXT_PUBLIC_ADMIN_WS_URL || "ws://localhost:8000/ws/admin"`
- **WebSocket Endpoint & Listener:**
  - URL: `ws://<HOST>:8000/ws/admin`
  - Active Listener: `useEffect` hook in `Dashboard` (`page.tsx`) maintains persistent connection with 3-second auto-reconnect.
  - Event Handling:
    - `INITIAL_SNAPSHOT`: Populates `cartStatuses` map with all active carts and initial totals.
    - `CART_PAIRED`: Sets trolley to `ACTIVE` and assigns shopper name.
    - `CART_UPDATED`: Ingests real-time `ADD_ITEM` / `REMOVE_ITEM` events, updating trolley running total and item count.
    - `SECURITY_ALERT` / `UNSCANNED_DROP` / `session_terminated`: Displays persistent top-of-screen red emergency alert banner, sets cart status to `TERMINATED`, and resets item count and total to 0.
    - `ALERT_RESOLVED`: Clears emergency alert banner.
    - `CHECKOUT_COMPLETE`: Records checkout completion for trolley.
