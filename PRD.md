# Product Requirements Document (PRD)
## Project: Smart Shopping Trolley & Retail Ecosystem (MVP Edition)

### 1. Core Purpose
The SuperMarket Automation MVP project transforms the traditional retail experience into an autonomous, edge-synchronized shopping ecosystem scalable for broad retail deployment. By integrating a Raspberry Pi edge controller, web-based mobile computer vision, a 1D/2D barcode scanner, and synchronized audio-visual feedback directly into shopping trolleys, the system eliminates manual checkout lines.

### 2. Target Users
*   **Shoppers:** Users requiring a frictionless shopping experience without checkout queues.
*   **Store Administration/Management:** Retail managers requiring real-time monitoring of active carts, inventory tracking, and theft reduction via a unified web dashboard.

### 3. Problem Statement vs. Proposed Solution
*   **The Problem:** Traditional POS systems incur high labor costs and queues. Self-checkout kiosks shift labor to the customer and increase retail shrink (theft). 
*   **The Proposed Solution (MVP):** A decentralized edge architecture. Scanning and vision verification occur concurrently on the shopping trolley. Edge AI—running inside mounted smartphone browsers—verifies items dropping into the cart, enabling a zero-queue walkout checkout synced instantly to the user's phone via WebSockets, supported by immediate audio-visual hardware feedback.

### 4. Key Features & Functional Requirements

#### 4.1. Cart Pairing & Identity Synchronization
*   **Workflow:** User scans the cart's static 2D QR matrix (e.g., `CART_01`) via the Flutter app. The app sends a pairing REST request to the Laptop Central Server. The Server notifies the Raspberry Pi edge controller to transition the 16x4 LCD to active shopping mode, accompanied by a success beep from the dual buzzers.

#### 4.2. Built-In 1D/2D Barcode Telemetry
*   **Workflow:** User scans a standard barcode using the cart-mounted USB scanner. The Pi intercepts the keyboard HID string, enters a 5-second `PENDING_VERIFICATION` state, sounds an audio confirmation via the buzzers, and updates the 16x4 LCD to prompt item placement.

#### 4.3. Dual-Phone Edge Browser Computer Vision Verification
*   **Hardware:** 2x Android smartphones mounted at the basket entrance, connected to the Pi via USB cables (ADB Reverse Port Forwarding / Tethering).
*   **Workflow:** The Pi serves a static HTML/JS page and a quantized YOLOv8n model to the phones. The phones run inference locally in their browsers using WebGL/WebGPU. A centroid tracker monitors items crossing a virtual horizontal line and sends lightweight JSON `CROSS_IN` triggers back to the Pi over USB.

#### 4.4. 16x4 I2C LCD & Dual Buzzer Feedback Subsystem
*   **Hardware:** Backlit 16x4 Character I2C LCD driven via PCF8574 expander, paired with two active buzzers driven via standard GPIO pins.
*   **Workflow:** Dynamically displays textual states ("Smart Cart Ready", "Item Added!", "ALERT: Unscanned Item!") and simultaneously activates the buzzers for every screen update (single beep for scan, double beep for verification, continuous pulse for anomaly alerts).

#### 4.5. Customer Mobile Application (Flutter Client)
*   **Networking:** HTTP REST for checkout and `web_socket_channel` for sub-second cart state synchronization.
*   **Features:** QR Cart Pairing, live synchronization of cart contents/running total with "Vision Verified" badges, unscanned item warning modals, and in-app self-checkout generating a Digital Exit Pass.

#### 4.6. Central Store Server & Admin Dashboard (Laptop)
*   **Stack:** Node.js/Express or Python FastAPI backend; SQLite/PostgreSQL database; React.js/Vite frontend.
*   **Features:** Acts as the unified backend for both the Flutter app and Admin Dashboard. Manages WebSocket broadcast rooms, live inventory decrementing, and renders a live grid of active carts and real-time anti-theft alerts for store staff.

### 5. Out of Scope for MVP
Explicitly excluded to maintain strict MVP scope:
*   Gravimetric Load Cells and analog mass verification.
*   MQTT Brokers (relying strictly on HTTP/WebSockets).
*   Predictive AI Analytics, demand forecasting, and dynamic pricing.
*   Spatial Routing and Floorplan mapping.
*   RFID Integration and Ceiling-Mounted Camera Arrays.