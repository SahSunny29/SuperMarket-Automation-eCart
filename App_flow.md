# Smart Shopping Trolley - MVP User Flow

This document outlines the step-by-step user journey and system interactions during a standard retail shopping session using the Smart Shopping Trolley MVP, Customer Mobile Application, and Central Store Server.

## Stage 1: Trolley Initialization & Synchronization
1. **Approach:** The shopper approaches an idle smart trolley. The 16x4 LCD screen displays a standby prompt: *"Smart Cart Ready - Scan QR on App"*.
2. **Scan:** The shopper launches the Flutter mobile app and scans the cart's fixed 2D QR matrix (`CART_01`).
3. **Authentication:** The mobile app posts a session pairing request via HTTP REST to the Laptop Central Server. The Server registers the session and notifies the cart's Raspberry Pi edge controller over local Wi-Fi.
4. **Confirmation:** The trolley's 16x4 LCD screen updates to display **"Cart Synced! Scan Items"** and the dual buzzers emit a short success chirp.
5. **App Update:** The mobile app opens a persistent WebSocket connection to the server and updates its interface to display **"Cart Active: 0 Items"**.

## Stage 2: Product Acquisition & Edge Sensor Verification
1. **Item Scanning:** The shopper selects a product from the shelf and scans its barcode using the cart's USB 1D/2D optical scanner.
2. **Scan Acknowledgment:** 
   * The Raspberry Pi intercepts the barcode string and enters a 5-second `PENDING_VERIFICATION` state.
   * The dual buzzers sound a short scan-confirmation beep.
   * The 16x4 LCD refreshes to display the item name, price, and the prompt: **"Item Scanned: Place item in cart"**.
3. **Placement & Browser Vision Sensing:** 
   * The user drops the item into the basket entrance.
   * Two cart-mounted Android smartphones, running object detection locally in their mobile web browsers (served via USB by the Pi), track the object.
   * When the object's bounding box centroid crosses the virtual horizontal threshold line, the phones transmit a `CROSS_IN` JSON reaction event over the USB cables to the Raspberry Pi.
4. **Resolution Branch:**
   * **If Verification Passes (Match within 5s):** The Pi deduplicates the dual-camera triggers, matches the physical drop to the scanned barcode, updates the LCD to **"Item Added!"**, sounds a verification double-beep on the buzzers, and sends a verified HTTP POST payload to the Laptop Central Server.
   * **If Scan Times Out (No drop within 5s):** The Pi cancels the pending scan state, updates the LCD to **"Scan Cancelled: Item not placed"**, and emits a low error tone on the buzzers.
   * **If Unscanned Item is Dropped (INSTANT STOP SYNC & ATTENTION ALERT):** 
     * **Raspberry Pi Edge:** Detects a `CROSS_IN` event without an active pending scan, flags an immediate anomaly, triggers dual-buzzer alarm pulsing, renders `* SECURITY *` / `SYNC TERMINATED!` on the 16x2 LCD, dispatches `UNSCANNED_DROP` to the Central Server, clears local session data, displays the alert for 3.0 seconds, and resets directly to unpaired standby (`TROLLEY READY` / `Scan handle QR!`). It does **NOT** wait for item removal.
     * **Central Server:** Records anomaly in `security_alerts`, clears active cart items, resets running total to `Rs. 0.00`, transitions cart status to `TERMINATED`, and broadcasts high-priority JSON (`action: "STOP_SYNC_AND_EXIT"`, `session_terminated: true`) to `/ws/cart/{cart_id}` and `/ws/admin`. Any subsequent sync attempts are rejected with HTTP 400 until a fresh QR scan handshake occurs.
     * **Buyer Mobile App:** Receives `STOP_SYNC_AND_EXIT`, immediately terminates sync, closes the WebSocket subscription, clears the active basket, navigates back to Home/QR Pairing screen, and displays an attention-seeking high-contrast red security alert modal with heavy haptic feedback (*"SECURITY ALERT: Unscanned Item Detected! Cart syncing has been terminated. Please re-scan the cart QR code or contact store staff."*).
     * **Admin Dashboard:** Displays a persistent top-of-screen emergency red alert banner and updates the active trolley card to `TERMINATED (UNSCANNED DROP)`.

## Stage 3: Mobile & Dashboard State Propagation
1. **Telemetry Transmission:** Following a successful verification, the Laptop Central Server queries the product database, updates the cart's running total, and decrements store stock.
2. **Live Broadcast:** The Server pushes the updated cart JSON payload down the active WebSocket channels (`/ws/cart/{cart_id}` and `/ws/admin`).
3. **Live Client Updates:** 
   * **Buyer App:** The Flutter application updates in real time to display the added product, increment the running basket cost, and show a "Vision Verified" badge.
   * **Admin Dashboard:** The store manager's React webpage updates the live cart monitoring grid.
4. **Reset for Next Item:** The cart's 16x4 LCD switches back to **"Ready: Scan Next Item"**.

## Stage 4: Checkout & Cart Reinitialization
1. **Initiate Payment:** Once all shopping is complete, the user taps **"Proceed to Checkout"** on their mobile device and completes the digital payment flow.
2. **Authorization & Unlock:** 
   * The Laptop Server sets the cart session state to `PAID` and sends a reset signal to the Raspberry Pi.
   * The Pi edge controller updates the 16x4 LCD to **"Checkout Complete - Thank You!"** and sounds a final success chime on the buzzers before resetting to standby mode.
3. **Exit Verification:** The Flutter mobile app generates and displays a Digital Exit Pass QR code.
4. **Completion:** The customer presents the digital receipt at the exit and leaves the cart at the return hub.