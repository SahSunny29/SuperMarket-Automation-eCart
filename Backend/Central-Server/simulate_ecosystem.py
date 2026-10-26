#!/usr/bin/env python3
"""
================================================================================
Central Store Server & Edge Ecosystem - Live End-to-End Simulation & Verification
================================================================================
Autonomous Verification Harness executing the full retail pipeline:
- Starts Central-Server on port 8000
- Starts Pi-Backend on port 5000 (with simulated I2C/GPIO/evdev drivers)
- Connects 2 real concurrent WebSockets:
    1. Buyer Flutter Client (/ws/cart/CART_01)
    2. Store Admin Dashboard Client (/ws/admin)
- Executes and rigorously asserts all 6 integration scenarios sequentially.
- Measures and validates real-time WebSocket broadcast latencies (< 150ms).
================================================================================
"""

import asyncio
import json
import logging
import os
import re
import socket
import subprocess
import sys
import time
from datetime import datetime, timezone
from typing import Any, Callable, Dict, List, Optional, Tuple

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass

import httpx
import websockets

# Setup paths
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(CURRENT_DIR, "..", ".."))
CENTRAL_SERVER_DIR = CURRENT_DIR
PI_BACKEND_DIR = os.path.abspath(os.path.join(CURRENT_DIR, "..", "Pi-Backend"))

sys.path.insert(0, CENTRAL_SERVER_DIR)

from database import SessionLocal, init_db
from models import ActiveCart, CartItem, CartSession, Order, Product, SecurityAlert
from seed_products import seed_database

# Configure Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("EcosystemSim")

# Color styling constants
class Colors:
    HEADER = "\033[95m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    RESET = "\033[0m"


def print_banner(title: str):
    width = 80
    print("\n" + Colors.CYAN + "=" * width)
    print(f"   {title.center(width - 6)}")
    print("=" * width + Colors.RESET)


def print_scenario(num: int, title: str):
    print("\n" + Colors.BOLD + Colors.BLUE + f"--- [SCENARIO {num}]: {title} ---" + Colors.RESET)


def print_check(name: str, passed: bool, detail: str = ""):
    mark = f"{Colors.GREEN}[PASS] OK{Colors.RESET}" if passed else f"{Colors.RED}[FAIL] X{Colors.RESET}"
    detail_str = f" ({Colors.YELLOW}{detail}{Colors.RESET})" if detail else ""
    print(f"  {mark} {name}{detail_str}")
    if not passed:
        raise AssertionError(f"Check failed: {name} - {detail}")


# ==============================================================================
# Asynchronous WebSocket Mock Client
# ==============================================================================

class MockWebSocketClient:
    """Real asynchronous WebSocket client with queuing and timestamped message recording."""

    def __init__(self, name: str, url: str):
        self.name = name
        self.url = url
        self.queue: asyncio.Queue = asyncio.Queue()
        self.ws: Optional[websockets.ClientConnection] = None
        self._listen_task: Optional[asyncio.Task] = None
        self.all_messages: List[Dict[str, Any]] = []

    async def connect(self):
        logger.info(f"Connecting WebSocket: {self.name} -> {self.url} ...")
        self.ws = await websockets.connect(self.url, open_timeout=5.0)
        self._listen_task = asyncio.create_task(self._listen_loop())
        logger.info(f"WebSocket connected: {self.name}")

    async def _listen_loop(self):
        try:
            async for raw_msg in self.ws:
                t_recv = time.perf_counter()
                try:
                    data = json.loads(raw_msg)
                except Exception:
                    data = {"raw": raw_msg}
                msg_entry = {"data": data, "recv_time": t_recv}
                self.all_messages.append(msg_entry)
                await self.queue.put(msg_entry)
        except (websockets.ConnectionClosed, asyncio.CancelledError):
            pass
        except Exception as e:
            logger.debug(f"[{self.name}] Listen loop exited: {e}")

    async def wait_for_message(
        self,
        predicate: Callable[[Dict[str, Any]], bool],
        timeout: float = 3.0,
    ) -> Tuple[Dict[str, Any], float]:
        """Wait for a message matching predicate and return (data, recv_timestamp)."""
        start = time.perf_counter()
        while (time.perf_counter() - start) < timeout:
            remaining = timeout - (time.perf_counter() - start)
            try:
                msg = await asyncio.wait_for(self.queue.get(), timeout=max(0.01, remaining))
                if predicate(msg["data"]):
                    return msg["data"], msg["recv_time"]
            except asyncio.TimeoutError:
                break
        raise TimeoutError(f"[{self.name}] Timed out waiting for matching WebSocket message after {timeout}s")

    async def drain_queue(self):
        """Discards any currently unread messages in queue."""
        while not self.queue.empty():
            try:
                self.queue.get_nowait()
            except asyncio.QueueEmpty:
                break

    async def close(self):
        if self._listen_task and not self._listen_task.done():
            self._listen_task.cancel()
        if self.ws:
            await self.ws.close()
        logger.info(f"WebSocket disconnected: {self.name}")


# ==============================================================================
# Process Lifecycle Manager
# ==============================================================================

def is_port_in_use(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(("127.0.0.1", port)) == 0


async def wait_for_http_ready(url: str, timeout: float = 12.0) -> bool:
    start = time.perf_counter()
    async with httpx.AsyncClient() as client:
        while time.perf_counter() - start < timeout:
            try:
                resp = await client.get(url, timeout=1.0)
                if resp.status_code in (200, 307, 404):
                    return True
            except Exception:
                pass
            await asyncio.sleep(0.25)
    return False


def stop_process(name: str, proc: Optional[subprocess.Popen]):
    if proc and proc.poll() is None:
        logger.info(f"Stopping subprocess: {name} (PID {proc.pid}) ...")
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=2)
        logger.info(f"Subprocess terminated: {name}")


# ==============================================================================
# Simulation Execution Harness
# ==============================================================================

async def run_ecosystem_simulation():
    print_banner("HYPERPULSE RETAIL ECOSYSTEM: LIVE END-TO-END VERIFICATION")
    print(f"{Colors.DIM}Central Server Port: 8000 | Pi-Backend Edge Port: 5000{Colors.RESET}")

    central_proc: Optional[subprocess.Popen] = None
    pi_proc: Optional[subprocess.Popen] = None
    buyer_ws: Optional[MockWebSocketClient] = None
    admin_ws: Optional[MockWebSocketClient] = None

    scenario_metrics = {}

    try:
        # ----------------------------------------------------------------------
        # 0. Setup & Process Spawning
        # ----------------------------------------------------------------------
        logger.info("[Init] Idempotently re-seeding local database...")
        seed_database()

        # Check / Start Central-Server on port 8000
        if not is_port_in_use(8000):
            logger.info("[Process] Launching Central-Server on port 8000...")
            central_proc = subprocess.Popen(
                [
                    sys.executable,
                    "-m",
                    "uvicorn",
                    "server:app",
                    "--host",
                    "127.0.0.1",
                    "--port",
                    "8000",
                    "--log-level",
                    "warning",
                ],
                cwd=CENTRAL_SERVER_DIR,
                env=os.environ.copy(),
            )
        else:
            logger.info("[Process] Central-Server already active on port 8000.")

        # Check / Start Pi-Backend on port 5000
        if not is_port_in_use(5000):
            logger.info("[Process] Launching Pi-Backend Edge Controller on port 5000...")
            pi_env = os.environ.copy()
            pi_env["CENTRAL_SERVER_URL"] = "http://127.0.0.1:8000"
            pi_env["SIMULATED_HARDWARE"] = "True"
            pi_proc = subprocess.Popen(
                [
                    sys.executable,
                    "-m",
                    "uvicorn",
                    "main:app",
                    "--host",
                    "127.0.0.1",
                    "--port",
                    "5000",
                    "--log-level",
                    "warning",
                ],
                cwd=PI_BACKEND_DIR,
                env=pi_env,
            )
        else:
            logger.info("[Process] Pi-Backend already active on port 5000.")

        # Wait for both HTTP services to become healthy
        central_ok = await wait_for_http_ready("http://127.0.0.1:8000/api/products", timeout=12.0)
        pi_ok = await wait_for_http_ready("http://127.0.0.1:5000/api/status", timeout=12.0)

        print_check("Central Server listening on http://127.0.0.1:8000", central_ok)
        print_check("Pi-Backend Edge Controller listening on http://127.0.0.1:5000", pi_ok)

        # ----------------------------------------------------------------------
        # Connect Real Concurrent WebSockets
        # ----------------------------------------------------------------------
        buyer_ws = MockWebSocketClient("Buyer-Flutter-App", "ws://127.0.0.1:8000/ws/cart/CART_01")
        admin_ws = MockWebSocketClient("Store-Admin-Dashboard", "ws://127.0.0.1:8000/ws/admin")

        await buyer_ws.connect()
        await admin_ws.connect()

        # Wait for and verify initial snapshot broadcasts on connect
        snap_buyer, _ = await buyer_ws.wait_for_message(lambda d: d.get("action") == "CART_UPDATED", timeout=3.0)
        snap_admin, _ = await admin_ws.wait_for_message(lambda d: d.get("type") == "INITIAL_SNAPSHOT", timeout=3.0)

        print_check("Buyer WebSocket (/ws/cart/CART_01) received initial state snapshot", snap_buyer.get("cart_id") == "CART_01")
        print_check("Admin WebSocket (/ws/admin) received fleet initial snapshot", "carts" in snap_admin)

        # Clear initial snapshot messages from queues
        await buyer_ws.drain_queue()
        await admin_ws.drain_queue()

        async with httpx.AsyncClient(timeout=10.0) as http_client:

            # ==================================================================
            # Scenario 1: Stage 1 — Cart Pairing & Session Handshake
            # ==================================================================
            print_scenario(1, "Stage 1 — Cart Pairing & Session Handshake")
            t_s1_start = time.perf_counter()

            pair_payload = {"cart_id": "CART_01", "user_id": "U123"}
            pair_resp = await http_client.post("http://127.0.0.1:8000/api/session/pair", json=pair_payload)
            print_check("POST /api/session/pair HTTP status 200", pair_resp.status_code == 200)

            pair_json = pair_resp.json()
            session_id = pair_json.get("session_id")
            print_check(f"Pairing response valid (Session ID: {session_id})", pair_json.get("status") == "paired")

            # Database Assertions
            db = SessionLocal()
            try:
                cart_row = db.query(ActiveCart).filter(ActiveCart.cart_id == "CART_01").first()
                print_check("Database active_carts row status is 'ACTIVE'", cart_row.status == "ACTIVE")
                print_check("Cart items count initialized to 0", cart_row.item_count == 0)
                print_check("Cart total initialized to Rs. 0.00", cart_row.total_amount == 0.0)
            finally:
                db.close()

            # WebSocket Broadcast Verification & Latency (< 150ms)
            msg_cart, t_cart_recv = await buyer_ws.wait_for_message(
                lambda d: d.get("action") == "CART_UPDATED" and d.get("status") == "ACTIVE",
                timeout=3.0,
            )
            lat_cart_ms = (t_cart_recv - t_s1_start) * 1000.0
            print_check(
                f"Buyer WebSocket received CART_UPDATED pairing broadcast",
                msg_cart.get("cart_id") == "CART_01" and msg_cart.get("items_count") == 0,
                f"Latency: {lat_cart_ms:.2f}ms < 150ms",
            )
            assert lat_cart_ms < 150.0, f"Cart pairing broadcast latency exceeded 150ms: {lat_cart_ms:.2f}ms"

            msg_admin, t_admin_recv = await admin_ws.wait_for_message(
                lambda d: d.get("type") == "CART_PAIRED" and d.get("cart_id") == "CART_01",
                timeout=3.0,
            )
            lat_admin_ms = (t_admin_recv - t_s1_start) * 1000.0
            print_check(
                f"Admin WebSocket received CART_PAIRED broadcast",
                msg_admin.get("user_id") == "U123",
                f"Latency: {lat_admin_ms:.2f}ms < 150ms",
            )
            assert lat_admin_ms < 150.0, f"Admin pairing broadcast latency exceeded 150ms: {lat_admin_ms:.2f}ms"

            # Check Pi acknowledged pairing and entered IDLE
            await asyncio.sleep(0.3)
            pi_status_resp = await http_client.get("http://127.0.0.1:5000/api/status")
            pi_status = pi_status_resp.json()
            print_check(
                "Pi Edge Controller received pair-notify and transitioned to IDLE",
                pi_status.get("state") == "IDLE" and pi_status.get("user_id") == "U123",
            )
            scenario_metrics["Scenario 1"] = {"cart_ws_latency_ms": lat_cart_ms, "admin_ws_latency_ms": lat_admin_ms}

            # ==================================================================
            # Scenario 2: Stage 2 & 3 — Barcode Scan + Dual-Phone CROSS_IN (Happy Path)
            # ==================================================================
            print_scenario(2, "Stage 2 & 3 — Barcode Scan + Dual-Phone CROSS_IN Verification")

            # --- Item 1: Maggi 2-Minute Masala Noodles (8901058852234, Rs. 52.00) ---
            print(f"\n  {Colors.BOLD}Scanning Item 1: Maggi 2-Minute Masala Noodles (8901058852234, Rs. 52.00){Colors.RESET}")
            scan1_resp = await http_client.post(
                "http://127.0.0.1:5000/api/debug/simulate-scan",
                json={"barcode": "8901058852234"},
            )
            print_check("Pi accepted barcode scan and entered PENDING_VERIFICATION", scan1_resp.json().get("current_state") == "PENDING_VERIFICATION")

            # Dual-phone crossing within 200ms (50ms interval) to verify 500ms deduplication filter
            t_drop1_start = time.perf_counter()
            cam_left_call = http_client.post(
                "http://127.0.0.1:5000/api/vision-event",
                json={"camera_id": "CAM_LEFT", "event": "CROSS_IN", "detected_class": "item", "timestamp": time.time()},
            )
            await asyncio.sleep(0.04)
            cam_right_call = http_client.post(
                "http://127.0.0.1:5000/api/vision-event",
                json={"camera_id": "CAM_RIGHT", "event": "CROSS_IN", "detected_class": "item", "timestamp": time.time()},
            )
            res_left, res_right = await asyncio.gather(cam_left_call, cam_right_call)
            print_check("Dual camera vision events processed by Pi Edge", res_left.status_code == 200 and res_right.status_code == 200)

            # Assert WebSocket delivery (< 150ms)
            msg_add1_cart, t_add1_cart = await buyer_ws.wait_for_message(
                lambda d: d.get("action") == "ADD_ITEM" and d.get("barcode") == "8901058852234",
                timeout=3.0,
            )
            lat_add1_cart_ms = (t_add1_cart - t_drop1_start) * 1000.0
            print_check(
                "Buyer WebSocket received ADD_ITEM payload for Item 1",
                msg_add1_cart.get("running_total") == 52.00 and len(msg_add1_cart.get("items", [])) == 1,
                f"Latency: {lat_add1_cart_ms:.2f}ms < 150ms",
            )
            assert lat_add1_cart_ms < 150.0, f"Add Item 1 broadcast latency exceeded 150ms: {lat_add1_cart_ms:.2f}ms"

            msg_add1_admin, t_add1_admin = await admin_ws.wait_for_message(
                lambda d: d.get("type") == "CART_UPDATED" and d.get("action") == "ADD_ITEM" and d.get("barcode") == "8901058852234",
                timeout=3.0,
            )
            lat_add1_admin_ms = (t_add1_admin - t_drop1_start) * 1000.0
            print_check(
                "Admin WebSocket received CART_UPDATED (ADD_ITEM) broadcast",
                msg_add1_admin.get("running_total") == 52.00,
                f"Latency: {lat_add1_admin_ms:.2f}ms < 150ms",
            )
            assert lat_add1_admin_ms < 150.0

            # Database Assertions for Item 1
            db = SessionLocal()
            try:
                p1 = db.query(Product).filter(Product.barcode == "8901058852234").first()
                item1 = db.query(CartItem).filter(CartItem.cart_id == "CART_01", CartItem.barcode == "8901058852234").first()
                print_check("CartItem marked with vision_verified = True", item1 is not None and item1.vision_verified is True)
                print_check(f"Product stock decremented in catalog (Current Stock: {p1.stock_qty})", p1.stock_qty == 41)
            finally:
                db.close()

            # Wait for Pi to return to IDLE (1.6s delay after verified drop)
            logger.info("Waiting for Pi audio-visual feedback delay to transition back to IDLE...")
            for _ in range(25):
                st = (await http_client.get("http://127.0.0.1:5000/api/status")).json()
                if st.get("state") == "IDLE":
                    break
                await asyncio.sleep(0.1)

            # --- Item 2: Amul Pasteurised Butter 500g (8901030383848, Rs. 245.00) ---
            print(f"\n  {Colors.BOLD}Scanning Item 2: Amul Pasteurised Butter 500g (8901030383848, Rs. 245.00){Colors.RESET}")
            scan2_resp = await http_client.post(
                "http://127.0.0.1:5000/api/debug/simulate-scan",
                json={"barcode": "8901030383848"},
            )
            print_check("Pi entered PENDING_VERIFICATION for Item 2", scan2_resp.json().get("current_state") == "PENDING_VERIFICATION")

            t_drop2_start = time.perf_counter()
            cam_left_call = http_client.post(
                "http://127.0.0.1:5000/api/vision-event",
                json={"camera_id": "CAM_LEFT", "event": "CROSS_IN", "detected_class": "item", "timestamp": time.time()},
            )
            await asyncio.sleep(0.04)
            cam_right_call = http_client.post(
                "http://127.0.0.1:5000/api/vision-event",
                json={"camera_id": "CAM_RIGHT", "event": "CROSS_IN", "detected_class": "item", "timestamp": time.time()},
            )
            await asyncio.gather(cam_left_call, cam_right_call)

            msg_add2_cart, t_add2_cart = await buyer_ws.wait_for_message(
                lambda d: d.get("action") == "ADD_ITEM" and d.get("barcode") == "8901030383848",
                timeout=3.0,
            )
            lat_add2_cart_ms = (t_add2_cart - t_drop2_start) * 1000.0
            print_check(
                "Buyer WebSocket received ADD_ITEM payload for Item 2",
                msg_add2_cart.get("running_total") == 297.00 and len(msg_add2_cart.get("items", [])) == 2,
                f"Latency: {lat_add2_cart_ms:.2f}ms < 150ms",
            )
            assert lat_add2_cart_ms < 150.0

            msg_add2_admin, t_add2_admin = await admin_ws.wait_for_message(
                lambda d: d.get("type") == "CART_UPDATED" and d.get("action") == "ADD_ITEM" and d.get("barcode") == "8901030383848",
                timeout=3.0,
            )
            lat_add2_admin_ms = (t_add2_admin - t_drop2_start) * 1000.0
            print_check(
                "Admin WebSocket received CART_UPDATED for Item 2",
                msg_add2_admin.get("running_total") == 297.00 and msg_add2_admin.get("items_count") == 2,
                f"Latency: {lat_add2_admin_ms:.2f}ms < 150ms",
            )
            assert lat_add2_admin_ms < 150.0

            # Database Assertions for Item 2
            db = SessionLocal()
            try:
                p2 = db.query(Product).filter(Product.barcode == "8901030383848").first()
                cart2 = db.query(ActiveCart).filter(ActiveCart.cart_id == "CART_01").first()
                print_check("Cart running total accurate in database (Rs. 297.00)", cart2.total_amount == 297.00)
                print_check("Cart total item count accurate in database (2 items)", cart2.item_count == 2)
                print_check(f"Product 2 stock decremented in catalog (Current Stock: {p2.stock_qty})", p2.stock_qty == 44)
            finally:
                db.close()

            scenario_metrics["Scenario 2"] = {
                "item1_cart_ws_latency_ms": lat_add1_cart_ms,
                "item2_cart_ws_latency_ms": lat_add2_cart_ms,
            }

            # ==================================================================
            # Scenario 3: Stage 2 Branch — 5-Second Scan Timeout (No Drop)
            # ==================================================================
            print_scenario(3, "Stage 2 Branch — 5-Second Scan Timeout (No Drop)")

            # Wait for Pi to return to IDLE
            for _ in range(25):
                st = (await http_client.get("http://127.0.0.1:5000/api/status")).json()
                if st.get("state") == "IDLE":
                    break
                await asyncio.sleep(0.1)

            print("  Simulating scan of 3rd product (Maggi Special Masala 8901058852241)...")
            scan3_resp = await http_client.post(
                "http://127.0.0.1:5000/api/debug/simulate-scan",
                json={"barcode": "8901058852241"},
            )
            print_check("Pi entered PENDING_VERIFICATION (5.0s countdown active)", scan3_resp.json().get("current_state") == "PENDING_VERIFICATION")

            print("  Waiting 5.3s for scan timeout without any physical drop...")
            await asyncio.sleep(5.3)

            pi_status_after_timeout = (await http_client.get("http://127.0.0.1:5000/api/status")).json()
            print_check(
                "Pi verification timed out and state returned to IDLE",
                pi_status_after_timeout.get("state") in ("IDLE", "STANDBY"),
            )

            # Verify Central-Server Database did NOT add the item
            db = SessionLocal()
            try:
                cart3 = db.query(ActiveCart).filter(ActiveCart.cart_id == "CART_01").first()
                items_cnt = db.query(CartItem).filter(CartItem.cart_id == "CART_01").count()
                p3 = db.query(Product).filter(Product.barcode == "8901058852241").first()
                print_check("Item NOT added to cart (Total items remain 2)", items_cnt == 2)
                print_check("Cart running total unchanged (Rs. 297.00)", cart3.total_amount == 297.00)
                print_check("Unscanned product stock unchanged in catalog (42)", p3.stock_qty == 42)
            finally:
                db.close()
            scenario_metrics["Scenario 3"] = {"status": "PASSED - No item added on timeout"}

            # ==================================================================
            # Scenario 4: Stage 2 Branch — Unscanned Item Drop (Instant Stop Sync & Reset)
            # ==================================================================
            print_scenario(4, "Stage 2 Branch — Unscanned Item Drop (UNSCANNED_DROP -> STOP_SYNC_AND_EXIT)")

            # Ensure cart is in IDLE
            for _ in range(25):
                st = (await http_client.get("http://127.0.0.1:5000/api/status")).json()
                if st.get("state") == "IDLE":
                    break
                await asyncio.sleep(0.1)

            print("  Dropping unauthorized object into basket with cart in IDLE state...")
            t_alert_start = time.perf_counter()
            alert_event_resp = await http_client.post(
                "http://127.0.0.1:5000/api/vision-event",
                json={"camera_id": "CAM_LEFT", "event": "CROSS_IN", "detected_class": "unauthorized_item", "timestamp": time.time()},
            )
            print_check("Pi detected physical crossing and triggered security alarm", alert_event_resp.status_code == 200)

            # Assert WebSocket Alert Deliveries (< 150ms)
            msg_alert_cart, t_alert_cart = await buyer_ws.wait_for_message(
                lambda d: d.get("action") == "STOP_SYNC_AND_EXIT" or d.get("session_terminated") is True,
                timeout=3.0,
            )
            lat_alert_cart_ms = (t_alert_cart - t_alert_start) * 1000.0
            print_check(
                "Buyer WebSocket received STOP_SYNC_AND_EXIT (session_terminated = True)",
                msg_alert_cart.get("cart_id") == "CART_01" and msg_alert_cart.get("session_terminated") is True,
                f"Latency: {lat_alert_cart_ms:.2f}ms < 150ms",
            )
            assert lat_alert_cart_ms < 150.0

            msg_alert_admin, t_alert_admin = await admin_ws.wait_for_message(
                lambda d: d.get("type") == "SECURITY_ALERT" and d.get("alert_type") == "UNSCANNED_DROP",
                timeout=3.0,
            )
            lat_alert_admin_ms = (t_alert_admin - t_alert_start) * 1000.0
            print_check(
                "Admin WebSocket received SECURITY_ALERT (Status: TERMINATED, session_terminated = True)",
                msg_alert_admin.get("cart_id") == "CART_01" and msg_alert_admin.get("session_terminated") is True and msg_alert_admin.get("status") == "TERMINATED",
                f"Latency: {lat_alert_admin_ms:.2f}ms < 150ms",
            )
            assert lat_alert_admin_ms < 150.0

            # Database Assertions for Security Alert & Immediate Session Termination
            db = SessionLocal()
            try:
                alert_rec = (
                    db.query(SecurityAlert)
                    .filter(SecurityAlert.cart_id == "CART_01", SecurityAlert.alert_type == "UNSCANNED_DROP")
                    .order_by(SecurityAlert.id.desc())
                    .first()
                )
                cart_alert = db.query(ActiveCart).filter(ActiveCart.cart_id == "CART_01").first()
                active_items_count = db.query(CartItem).filter(CartItem.cart_id == "CART_01").count()
                print_check("Security alert recorded in database security_alerts table", alert_rec is not None)
                print_check("Cart status transitioned to 'TERMINATED'", cart_alert.status == "TERMINATED")
                print_check("Active cart basket cleared (item_count == 0, running_total == 0.0)", cart_alert.item_count == 0 and cart_alert.total_amount == 0.0 and active_items_count == 0)
                recorded_alert_id = alert_rec.id if alert_rec else None
            finally:
                db.close()

            # Query Central Server cart state endpoint to confirm cart stopped syncing
            cart_endpoint_resp = await http_client.get("http://127.0.0.1:8000/api/cart/CART_01")
            cart_json_state = cart_endpoint_resp.json()
            print_check(
                "GET /api/cart/CART_01 confirms cart stopped syncing (status: TERMINATED, items: 0, total: 0.0)",
                cart_json_state.get("status") == "TERMINATED"
                and cart_json_state.get("item_count") == 0
                and cart_json_state.get("total_amount") == 0.0
                and cart_json_state.get("user_id") is None
                and len(cart_json_state.get("items", [])) == 0,
            )

            # Direct state machine unit assertion on Pi-Backend's state_machine.py
            print("  Executing unit test on Pi-Backend CartStateMachine for zero CROSS_OUT recovery waiting...")
            try:
                if PI_BACKEND_DIR not in sys.path:
                    sys.path.insert(0, PI_BACKEND_DIR)
                from hardware.lcd_display import LCDDisplayController
                from hardware.buzzer_controller import BuzzerController
                from state_machine import CartStateMachine, CartState

                unit_lcd = LCDDisplayController(simulated=True)
                unit_buzzer = BuzzerController(simulated=True)
                unit_fsm = CartStateMachine(lcd=unit_lcd, buzzer=unit_buzzer, central_server_url="http://127.0.0.1:8000")
                await unit_fsm.start()
                await unit_fsm.on_session_paired(user_id="UNIT_TEST_USER")
                # Trigger unscanned CROSS_IN
                await unit_fsm.on_vision_event(camera_id="CAM_LEFT", event="CROSS_IN", detected_class="item")
                fsm_is_alert = unit_fsm.state == CartState.ALERT and unit_fsm.user_id is None
                # Send CROSS_OUT to prove no recovery waiting logic
                await unit_fsm.on_vision_event(camera_id="CAM_LEFT", event="CROSS_OUT", detected_class="item")
                fsm_ignored_crossout = unit_fsm.state == CartState.ALERT
                # Reset to standby
                await unit_fsm.clear_alert()
                fsm_reset_standby = unit_fsm.state == CartState.STANDBY
                await unit_fsm.stop()
                print_check(
                    "Unit Test: CartStateMachine unscanned CROSS_IN terminates session and ignores CROSS_OUT",
                    fsm_is_alert and fsm_ignored_crossout and fsm_reset_standby,
                )
            except Exception as e:
                logger.error(f"FSM unit test exception: {e}")
                print_check("Unit Test: CartStateMachine execution", False, str(e))

            # Verify Pi returns to STANDBY after 3.0s security alert window
            print("  Waiting 3.2s for Pi 3-second LCD alert window and auto-reset to STANDBY...")
            await asyncio.sleep(3.2)
            pi_status_after_alert = (await http_client.get("http://127.0.0.1:5000/api/status")).json()
            print_check(
                "Pi reset directly to unpaired STANDBY (TROLLEY READY) without waiting for item removal",
                pi_status_after_alert.get("state") == "STANDBY" and pi_status_after_alert.get("user_id") is None,
            )

            scenario_metrics["Scenario 4"] = {
                "cart_alert_latency_ms": lat_alert_cart_ms,
                "admin_alert_latency_ms": lat_alert_admin_ms,
            }

            # ==================================================================
            # Scenario 5: Sync Rejection, Re-Pairing, Item Removal & Admin REST Queries
            # ==================================================================
            print_scenario(5, "Sync Rejection on Terminated Session, Re-Pairing, Item Removal & Admin REST")

            # 1. Assert rejection of subsequent sync attempts on terminated cart
            print("  Attempting ADD_ITEM sync on terminated cart (must be rejected HTTP 400)...")
            rejected_sync_resp = await http_client.post(
                "http://127.0.0.1:8000/api/cart/sync",
                json={
                    "cart_id": "CART_01",
                    "action": "ADD_ITEM",
                    "barcode": "8901058852234",
                    "detected_class": "item",
                    "timestamp": time.time(),
                },
            )
            print_check(
                "Central Server rejected sync attempt on TERMINATED cart with HTTP 400",
                rejected_sync_resp.status_code == 400 and "TERMINATED" in rejected_sync_resp.json().get("detail", ""),
            )

            # 2. Re-pair cart with fresh QR scan handshake
            print("  Initiating fresh QR pairing handshake (POST /api/session/pair)...")
            repair_resp = await http_client.post(
                "http://127.0.0.1:8000/api/session/pair",
                json={"user_id": "U123", "cart_id": "CART_01"},
            )
            print_check("POST /api/session/pair returned HTTP 200 for re-paired session", repair_resp.status_code == 200)
            session_id = repair_resp.json().get("session_id")

            # Consume re-pairing broadcasts
            await buyer_ws.wait_for_message(lambda d: d.get("action") == "CART_UPDATED" and d.get("status") == "ACTIVE", timeout=3.0)
            await admin_ws.wait_for_message(lambda d: d.get("type") == "CART_PAIRED", timeout=3.0)

            # Add Item 1: Maggi Noodles (8901058852234, Rs. 52.00)
            print("  Adding Item 1 (Maggi Noodles: 8901058852234, Rs. 52.00)...")
            await http_client.post(
                "http://127.0.0.1:8000/api/cart/sync",
                json={"cart_id": "CART_01", "action": "ADD_ITEM", "barcode": "8901058852234", "detected_class": "item", "timestamp": time.time()},
            )
            await buyer_ws.wait_for_message(lambda d: d.get("action") == "ADD_ITEM" and d.get("barcode") == "8901058852234", timeout=3.0)
            await admin_ws.wait_for_message(lambda d: d.get("action") == "ADD_ITEM" and d.get("barcode") == "8901058852234", timeout=3.0)

            # Add Item 2: Amul Butter (8901030383848, Rs. 245.00)
            print("  Adding Item 2 (Amul Butter: 8901030383848, Rs. 245.00)...")
            await http_client.post(
                "http://127.0.0.1:8000/api/cart/sync",
                json={"cart_id": "CART_01", "action": "ADD_ITEM", "barcode": "8901030383848", "detected_class": "item", "timestamp": time.time()},
            )
            await buyer_ws.wait_for_message(lambda d: d.get("action") == "ADD_ITEM" and d.get("barcode") == "8901030383848", timeout=3.0)
            await admin_ws.wait_for_message(lambda d: d.get("action") == "ADD_ITEM" and d.get("barcode") == "8901030383848", timeout=3.0)

            # 3. Simulate legitimate item removal (Amul Butter: 8901030383848, Rs. 245.00)
            print("  Removing 1x Amul Butter (8901030383848) from cart...")
            t_rem_start = time.perf_counter()
            rem_resp = await http_client.post(
                "http://127.0.0.1:8000/api/cart/sync",
                json={
                    "cart_id": "CART_01",
                    "action": "REMOVE_ITEM",
                    "barcode": "8901030383848",
                    "detected_class": "item",
                    "timestamp": time.time(),
                },
            )
            print_check("POST /api/cart/sync (REMOVE_ITEM) returned HTTP 200", rem_resp.status_code == 200)

            # Assert WebSocket Broadcasts (< 150ms)
            msg_rem_cart, t_rem_cart = await buyer_ws.wait_for_message(
                lambda d: d.get("action") == "REMOVE_ITEM" and d.get("barcode") == "8901030383848",
                timeout=3.0,
            )
            lat_rem_cart_ms = (t_rem_cart - t_rem_start) * 1000.0
            print_check(
                "Buyer WebSocket received REMOVE_ITEM payload",
                msg_rem_cart.get("running_total") == 52.00 and msg_rem_cart.get("items_count") == 1,
                f"Latency: {lat_rem_cart_ms:.2f}ms < 150ms",
            )
            assert lat_rem_cart_ms < 150.0

            msg_rem_admin, t_rem_admin = await admin_ws.wait_for_message(
                lambda d: d.get("type") == "CART_UPDATED" and d.get("action") == "REMOVE_ITEM",
                timeout=3.0,
            )
            lat_rem_admin_ms = (t_rem_admin - t_rem_start) * 1000.0
            print_check(
                "Admin WebSocket received CART_UPDATED (REMOVE_ITEM) payload",
                msg_rem_admin.get("running_total") == 52.00 and msg_rem_admin.get("items_count") == 1,
                f"Latency: {lat_rem_admin_ms:.2f}ms < 150ms",
            )
            assert lat_rem_admin_ms < 150.0

            # Database Assertions for Item Removal
            db = SessionLocal()
            try:
                cart_rem = db.query(ActiveCart).filter(ActiveCart.cart_id == "CART_01").first()
                p_rem = db.query(Product).filter(Product.barcode == "8901030383848").first()
                print_check("Cart running total decremented to Rs. 52.00", cart_rem.total_amount == 52.00)
                print_check("Cart item count decremented to 1", cart_rem.item_count == 1)
                print_check(f"Product stock incremented back to original (Current: {p_rem.stock_qty})", p_rem.stock_qty == 44)
            finally:
                db.close()

            # Resolve alert on Central-Server
            if recorded_alert_id:
                res_resp = await http_client.post(f"http://127.0.0.1:8000/api/admin/alerts/{recorded_alert_id}/resolve")
                print_check(f"Central Server marked alert #{recorded_alert_id} resolved", res_resp.status_code == 200)

            # 4. Call and Assert All Admin Dashboard REST Endpoints
            print("\n  Executing Admin Dashboard REST Endpoints Verification...")
            r_prods = await http_client.get("http://127.0.0.1:8000/api/admin/products")
            print_check("GET /api/admin/products returns 200 with product list", r_prods.status_code == 200 and len(r_prods.json()) >= 8)

            r_carts = await http_client.get("http://127.0.0.1:8000/api/admin/carts")
            print_check("GET /api/admin/carts returns 200 with fleet status", r_carts.status_code == 200 and any(c["cart_id"] == "CART_01" for c in r_carts.json()))

            r_alerts = await http_client.get("http://127.0.0.1:8000/api/admin/alerts")
            print_check("GET /api/admin/alerts returns 200 with audit security records", r_alerts.status_code == 200 and len(r_alerts.json()) > 0)

            r_stats = await http_client.get("http://127.0.0.1:8000/api/admin/stats")
            print_check("GET /api/admin/stats returns 200 with store KPIs", r_stats.status_code == 200 and "active_customers" in r_stats.json())

            r_search = await http_client.get("http://127.0.0.1:8000/api/products/search?q=Maggi")
            print_check("GET /api/products/search returns 200 with vector coordinates", r_search.status_code == 200 and len(r_search.json()) >= 2)

            scenario_metrics["Scenario 5"] = {
                "cart_remove_latency_ms": lat_rem_cart_ms,
                "admin_remove_latency_ms": lat_rem_admin_ms,
            }

            # ==================================================================
            # Scenario 6: Stage 4 — Self-Checkout, Digital Exit Pass & Session Reset
            # ==================================================================
            print_scenario(6, "Stage 4 — Self-Checkout, Digital Exit Pass & Session Reset")

            t_chk_start = time.perf_counter()
            chk_payload = {
                "cart_id": "CART_01",
                "payment_method": "UPI_FASTPAY",
                "amount": 52.00,
                "status": "PAID",
            }
            chk_resp = await http_client.post("http://127.0.0.1:8000/api/session/checkout", json=chk_payload)
            print_check("POST /api/session/checkout returned HTTP 200", chk_resp.status_code == 200)

            chk_json = chk_resp.json()
            receipt_id = chk_json.get("receipt_id", "")
            exit_token = chk_json.get("exit_pass_token", "")
            print_check(f"Generated Audit Receipt ID: {receipt_id}", receipt_id.startswith("REC-"))
            print_check(f"Generated Turnstile Exit Pass QR Token: {exit_token}", exit_token.startswith("PASS_CART_01_PAID_"))
            print_check("Total amount paid confirmed: Rs. 52.00", chk_json.get("amount_paid") == 52.00)

            # Assert WebSocket Broadcasts (< 150ms)
            msg_chk_cart, t_chk_cart = await buyer_ws.wait_for_message(
                lambda d: d.get("action") == "SESSION_RESET" and d.get("status") == "PAID",
                timeout=3.0,
            )
            lat_chk_cart_ms = (t_chk_cart - t_chk_start) * 1000.0
            print_check(
                "Buyer WebSocket received SESSION_RESET payload with exit pass token",
                msg_chk_cart.get("exit_pass_token") == exit_token,
                f"Latency: {lat_chk_cart_ms:.2f}ms < 150ms",
            )
            assert lat_chk_cart_ms < 150.0

            msg_chk_admin, t_chk_admin = await admin_ws.wait_for_message(
                lambda d: d.get("type") == "CHECKOUT_COMPLETE" and d.get("cart_id") == "CART_01",
                timeout=3.0,
            )
            lat_chk_admin_ms = (t_chk_admin - t_chk_start) * 1000.0
            print_check(
                "Admin WebSocket received CHECKOUT_COMPLETE broadcast",
                msg_chk_admin.get("total_paid") == 52.00,
                f"Latency: {lat_chk_admin_ms:.2f}ms < 150ms",
            )
            assert lat_chk_admin_ms < 150.0

            # Database Assertions for Checkout
            db = SessionLocal()
            try:
                cart_final = db.query(ActiveCart).filter(ActiveCart.cart_id == "CART_01").first()
                order_rec = db.query(Order).filter(Order.cart_id == "CART_01").order_by(Order.created_at.desc()).first()
                session_rec = db.query(CartSession).filter(CartSession.session_id == session_id).first()
                print_check("Active cart row status is marked 'PAID'", cart_final.status == "PAID")
                print_check(f"Order saved in database orders table (Order ID: {order_rec.order_id if order_rec else 'None'})", order_rec is not None and order_rec.total_paid == 52.00)
                print_check("CartSession marked 'PAID' in cart_sessions table", session_rec is not None and session_rec.status == "PAID")
            finally:
                db.close()

            # Check Pi received checkout reset signal
            await asyncio.sleep(0.4)
            pi_chk_status = (await http_client.get("http://127.0.0.1:5000/api/status")).json()
            print_check(
                "Pi Edge Controller received reset signal and entered PAID/STANDBY chime state",
                pi_chk_status.get("state") in ("PAID", "STANDBY"),
            )

            scenario_metrics["Scenario 6"] = {
                "cart_checkout_latency_ms": lat_chk_cart_ms,
                "admin_checkout_latency_ms": lat_chk_admin_ms,
            }

        # ======================================================================
        # Final Executive Verification Report
        # ======================================================================
        print_banner("ALL 6 INTEGRATION SCENARIOS COMPLETED SUCCESSFULLY")
        print("\n" + Colors.BOLD + f"{'Scenario Name':<45} | {'Metric':<25} | {'Latency':<10}" + Colors.RESET)
        print("-" * 86)
        print(f"{'1. Stage 1: Cart Pairing & Handshake':<45} | {'Buyer WebSocket Broadcast':<25} | {scenario_metrics['Scenario 1']['cart_ws_latency_ms']:>6.2f} ms")
        print(f"{'   (Pairing Telemetry)':<45} | {'Admin WebSocket Broadcast':<25} | {scenario_metrics['Scenario 1']['admin_ws_latency_ms']:>6.2f} ms")
        print(f"{'2. Stage 2&3: Barcode Scan + CROSS_IN':<45} | {'Item 1 Buyer WS Latency':<25} | {scenario_metrics['Scenario 2']['item1_cart_ws_latency_ms']:>6.2f} ms")
        print(f"{'   (500ms Dual-Camera Debounce)':<45} | {'Item 2 Buyer WS Latency':<25} | {scenario_metrics['Scenario 2']['item2_cart_ws_latency_ms']:>6.2f} ms")
        print(f"{'3. Stage 2 Branch: 5s Scan Timeout':<45} | {'Zero State Drift / No Add':<25} | {'PASS':>6}")
        print(f"{'4. Stage 2 Branch: Unscanned Item Drop':<45} | {'Buyer Modal WS Latency':<25} | {scenario_metrics['Scenario 4']['cart_alert_latency_ms']:>6.2f} ms")
        print(f"{'   (STOP_SYNC_AND_EXIT Alert)':<45} | {'Admin Banner WS Latency':<25} | {scenario_metrics['Scenario 4']['admin_alert_latency_ms']:>6.2f} ms")
        print(f"{'5. Sync Reject, Re-Pair & Item Removal':<45} | {'Buyer Removal WS Latency':<25} | {scenario_metrics['Scenario 5']['cart_remove_latency_ms']:>6.2f} ms")
        print(f"{'   (Halted Sync & Basket Reset)':<45} | {'Admin Fleet REST Query':<25} | {'PASS':>6}")
        print(f"{'6. Stage 4: Checkout & Exit Pass':<45} | {'Buyer QR Pass WS Latency':<25} | {scenario_metrics['Scenario 6']['cart_checkout_latency_ms']:>6.2f} ms")
        print(f"{'   (Turnstile PASS_... & Pi Reset)':<45} | {'Admin Checkout WS Latency':<25} | {scenario_metrics['Scenario 6']['admin_checkout_latency_ms']:>6.2f} ms")
        print("-" * 86)
        print(f"{Colors.GREEN}{Colors.BOLD}CONCLUSION: 100% Contract Compliance. Sub-150ms WebSocket Broadcast SLA Verified.{Colors.RESET}\n")

    finally:
        # Cleanup WebSockets
        if buyer_ws:
            await buyer_ws.close()
        if admin_ws:
            await admin_ws.close()

        # Terminate spawned processes
        stop_process("Pi-Backend", pi_proc)
        stop_process("Central-Server", central_proc)


if __name__ == "__main__":
    try:
        asyncio.run(run_ecosystem_simulation())
    except KeyboardInterrupt:
        print("\nSimulation aborted by user.")
        sys.exit(1)
    except Exception as e:
        logger.exception(f"Simulation failed with error: {e}")
        sys.exit(1)
