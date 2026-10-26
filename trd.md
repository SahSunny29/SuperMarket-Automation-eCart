# Technical Requirements Document (TRD)
**Project:** Smart Shopping Trolley & Retail Ecosystem (MVP Edition)

---

## 1. Introduction
This Technical Requirements Document (TRD) outlines the architecture, technology stack, hardware specifications, and communication protocols for the Smart Shopping Trolley MVP. The architecture emphasizes decentralized Edge AI execution utilizing mobile browser hardware acceleration, combined with localized audio-visual I/O to guide the user seamlessly.

---

## 2. Technology Stack & Libraries

### 2.1. Edge Hardware (Smart Trolley)
*   **Edge Controller:** Raspberry Pi 3 Model B+ (Hosts local vision web server, coordinates USB/I2C/GPIO I/O, merges sensor states, and talks to the Laptop server over Wi-Fi).
*   **Vision Verification (Edge AI Nodes):** 2x Android Smartphones mounted at opposing internal rim angles.
*   **Optical Scanning:** Fixed-mount USB 1D/2D barcode scanner (USB HID keyboard emulation).
*   **User Interface / Feedback:** 16x4 Character I2C LCD screen with PCF8574 expander module, and 2x Active Buzzers connected to standard digital GPIO pins.

### 2.2. Edge Software (Raspberry Pi & Camera Phones)
*   **Edge Controller Language:** Python 3.9+ (FastAPI / Flask for local serving).
*   **Hardware Interface Libraries:**
    *   `evdev` for asynchronous background polling of the USB barcode scanner.
    *   `RPLCD` and `smbus2` for controlling the 16x4 I2C LCD.
    *   `gpiozero` or `RPi.GPIO` for triggering Digital High/PWM signals to the dual buzzers.
*   **Phone Vision Stack (Served by Pi):**
    *   HTML5 `<canvas>` and `getUserMedia()` API for camera streaming.
    *   ONNX Runtime Web / TensorFlow.js utilizing WebGL/WebGPU.
    *   Quantized YOLOv8 Nano (`.onnx`) object detection model.
    *   Vanilla JavaScript for bounding-box centroid tracking across a virtual horizontal gate.

### 2.3. Unified Central Backend (Laptop)
*   **Application Server:** Node.js (Express) or Python (FastAPI).
*   **Real-time Communication:** WebSockets (`ws` or `Socket.io`) for sub-second state broadcasts.
*   **Primary Database (Relational):** SQLite or PostgreSQL (ACID-compliant storage for users, inventory, active carts, and alerts).

### 2.4. Client Applications
*   **Customer Mobile Application:** Flutter (Dart) using `web_socket_channel` and `http` for API requests.
*   **Store Admin Dashboard:** React.js (Vite) utilizing WebSocket clients for live telemetry rendering.

---

## 3. Feature Implementation & Logic Details

### 3.1. USB Bridge & Browser Vision Execution
*   **Networking over USB:** The Raspberry Pi utilizes a startup script (`setup_adb.sh`) executing `adb reverse tcp:5000 tcp:5000`. This allows the mounted Android phones to access the Pi's local web server via `http://localhost:5000` strictly over the physical USB cables.
*   **Execution:** The phones download the HTML/JS and `.onnx` model into RAM, process 480p frames at 30 FPS locally, and send tiny JSON payloads (e.g., `{"event": "CROSS_IN"}`) via HTTP POST to the Pi over the established USB tunnel.

### 3.2. Sensor Fusion & State Resolution
*   **Deduplication:** The Pi receives `CROSS_IN` POST requests from both `CAM_LEFT` and `CAM_RIGHT`. A software debounce filter merges events occurring within a **500ms window** to prevent double-counting a single physical item.
*   **State Machine (with Audio-Visual Output):** 
    *   Barcode scan triggers a `PENDING_VERIFICATION` state valid for exactly **5.0 seconds**, updates the LCD, and sounds a short buzzer beep.
    *   If a deduplicated `CROSS_IN` event occurs during this window, the item is verified, LCD updates to "Item Added!", buzzers sound a success double-beep, and an HTTP POST is dispatched to the Laptop Server.
    *   If `CROSS_IN` occurs while state is `IDLE`, an `UNSCANNED_DROP` security alert is generated, LCD displays an alert, and buzzers sound a continuous alarm.
    *   If 5.0 seconds elapse without a `CROSS_IN` event, the scan is cancelled, LCD resets, and buzzers emit a low error tone.

### 3.3. Real-Time Synchronization Protocol
*   **Client Handshake:** Flutter app sends `POST /api/session/pair` containing `{"cart_id": "CART_01", "user_id": "U123"}` to the Laptop Server.
*   **WebSocket Subscription:** Upon pairing, Flutter app connects to `ws://<LAPTOP_IP>:8000/ws/cart/CART_01`.
*   **Admin Subscription:** The React dashboard maintains a global connection to `ws://<LAPTOP_IP>:8000/ws/admin`.
*   **Broadcast Trigger:** When the Laptop Server receives a verified `POST /api/cart/sync` from the Pi, it updates PostgreSQL and instantly broadcasts the new cart JSON to both WebSocket rooms.

---

## 4. Performance Thresholds
*   **Browser Inference Speed:** The YOLOv8n model running on the phone GPU must maintain $\ge$ **20 Frames Per Second (FPS)** to ensure accurate centroid tracking.
*   **Edge Reconciliation Latency:** The Pi must reconcile a barcode string and a USB JSON vision trigger, update the I2C LCD, and activate the dual buzzers in **< 300 milliseconds**.
*   **WebSocket Propagation:** A verified physical drop must reflect on the Flutter app and Admin Dashboard UI in **< 150 milliseconds** over the local Wi-Fi network.