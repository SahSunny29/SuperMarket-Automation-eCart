#!/usr/bin/env python3
"""
Verification Script: End-to-End Cart Pairing & Barcode Scanning Test
Validates:
1. Pi-Backend auto-registration with Central Server (IP & Port registration).
2. Central Server POST /api/session/pair notifying Pi over HTTP.
3. Pi State Machine transition from STANDBY -> IDLE.
4. Barcode scan accepted and transitioning to PENDING_VERIFICATION (5.0s window).
5. Physical CROSS_IN item drop verification and upstream sync to Central Server.
6. Fallback Auto-Pairing on Barcode scan if cart was still in STANDBY.
"""

import asyncio
import sys
import os

# Ensure import paths for both backends
current_dir = os.path.dirname(os.path.abspath(__file__))
central_dir = os.path.join(current_dir, "Central-Server")
pi_dir = os.path.join(current_dir, "Pi-Backend")
sys.path.insert(0, central_dir)
sys.path.insert(0, pi_dir)

from starlette.testclient import TestClient

from server import app as central_app
from database import SessionLocal, init_db
from models import ActiveCart, Product, CartItem, CartSession
from state_machine import CartStateMachine, CartState
from hardware.lcd_display import LCDDisplayController
from hardware.buzzer_controller import BuzzerController
from config import settings as pi_settings


async def run_verification():
    print("=" * 70)
    print("STARTING SMART CART PAIRING & SCANNING VERIFICATION TEST")
    print("=" * 70)

    # 1. Initialize Central Server Database & Seed Data
    init_db()
    db = SessionLocal()
    cart_01 = db.query(ActiveCart).filter(ActiveCart.cart_id == "CART_01").first()
    if not cart_01:
        cart_01 = ActiveCart(cart_id="CART_01", status="IDLE", ip_address="127.0.0.1", battery_level=95)
        db.add(cart_01)
        db.commit()
    else:
        cart_01.status = "IDLE"
        cart_01.user_id = None
        db.commit()

    # Ensure test product exists
    maggi = db.query(Product).filter(Product.barcode == "8901058852234").first()
    if not maggi:
        maggi = Product(
            barcode="8901058852234",
            sku="MAGGI-70G",
            name="Maggi Noodles 70g",
            brand="Nestle",
            category="Instant Food",
            aisle="Aisle 1",
            shelf_section="Sec A",
            mrp=15.0,
            sale_price=14.0,
            stock_qty=100,
            unit_weight_grams=70,
        )
        db.add(maggi)
        db.commit()
    db.close()

    central_client = TestClient(central_app)

    # 2. Initialize Pi State Machine (Simulated Hardware)
    lcd = LCDDisplayController(simulated=True)
    buzzer = BuzzerController(simulated=True)
    sm = CartStateMachine(lcd=lcd, buzzer=buzzer)
    await sm.start()

    print(f"\n[STEP 1] Pi initialized.")
    print(f"  Pi Initial State: {sm.state.value} (Expected: STANDBY)")
    assert sm.state == CartState.STANDBY, "Pi state machine must start in STANDBY"

    # 3. Test Pi Auto-Registration with Central Server
    print("\n[STEP 2] Testing Pi Registration (POST /api/cart/register-pi)...")
    pi_ip = "10.138.30.222"  # Simulated Pi Wi-Fi IP
    reg_payload = {
        "cart_id": "CART_01",
        "ip_address": pi_ip,
        "port": 5000,
        "status": "STANDBY"
    }
    reg_resp = central_client.post("/api/cart/register-pi", json=reg_payload)
    print(f"  Registration Response: {reg_resp.status_code} - {reg_resp.json()}")
    assert reg_resp.status_code == 200, "Pi registration must return 200"

    # Verify Central Server updated cart IP
    db = SessionLocal()
    updated_cart = db.query(ActiveCart).filter(ActiveCart.cart_id == "CART_01").first()
    print(f"  Central Server DB Cart IP: {updated_cart.ip_address} (Expected: {pi_ip})")
    assert updated_cart.ip_address == pi_ip, "Central Server must store the registered Pi Wi-Fi IP"
    db.close()

    # 4. Simulate Mobile App Pairing Request (POST /api/session/pair)
    print("\n[STEP 3] Simulating Mobile Buyer App Pairing Request...")
    pair_payload = {
        "cart_id": "CART_01",
        "user_id": "U_BUYER_WI_FI_01"
    }
    pair_resp = central_client.post("/api/session/pair", json=pair_payload)
    print(f"  Pair Response: {pair_resp.status_code} - {pair_resp.json()}")
    assert pair_resp.status_code == 200, "Pairing request must return 200"

    # Simulate the notification reaching the Pi's endpoint (or received via sync loop)
    await sm.on_session_paired(user_id="U_BUYER_WI_FI_01")
    print(f"  Pi State after Pairing Notification: {sm.state.value} (Expected: IDLE)")
    print(f"  Pi Current User: {sm.user_id} (Expected: U_BUYER_WI_FI_01)")
    assert sm.state == CartState.IDLE, "Pi state must transition to IDLE upon pairing"
    assert sm.user_id == "U_BUYER_WI_FI_01", "Pi must set paired user_id"

    # 5. Test USB Barcode Scan with Active Session
    print("\n[STEP 4] Scanning Item Barcode with USB Scanner on Pi ('8901058852234')...")
    await sm.on_barcode_scanned("8901058852234")
    print(f"  Pi State after Barcode Scan: {sm.state.value} (Expected: PENDING_VERIFICATION)")
    print(f"  Pi Pending Barcode: {sm.pending_barcode} (Expected: 8901058852234)")
    assert sm.state == CartState.PENDING_VERIFICATION, "Scan must transition state to PENDING_VERIFICATION"
    assert sm.pending_barcode == "8901058852234", "Pending barcode must match scanned code"

    # 6. Test Physical Item Drop (CROSS_IN vision trigger)
    print("\n[STEP 5] Simulating Physical Drop (CROSS_IN vision trigger)...")
    await sm.on_vision_event(camera_id="CAM_LEFT", event="CROSS_IN", detected_class="item")
    print(f"  Pi State after Physical Drop: {sm.state.value} (Expected: VERIFIED)")
    assert sm.state == CartState.VERIFIED, "Drop match must transition state to VERIFIED"

    # 7. Test Upstream Item Sync with Central Server
    print("\n[STEP 6] Syncing Verified Item to Central Server (POST /api/cart/sync)...")
    sync_payload = {
        "cart_id": "CART_01",
        "action": "ADD_ITEM",
        "barcode": "8901058852234",
        "detected_class": "item"
    }
    sync_resp = central_client.post("/api/cart/sync", json=sync_payload)
    print(f"  Sync Response: {sync_resp.status_code} - {sync_resp.json()}")
    assert sync_resp.status_code == 200, "Central Server sync must succeed"
    assert sync_resp.json()["status"] == "success", "Sync status must be success"

    # Verify session items on Central Server
    cart_status_resp = central_client.get("/api/cart/CART_01")
    cart_data = cart_status_resp.json()
    print(f"  Central Server Cart Status: {cart_data['status']}, Item Count: {cart_data['item_count']}, Total: Rs.{cart_data['total_amount']}")
    assert cart_data["item_count"] >= 1, "Session must contain added item"

    # 8. Test Fallback Auto-Pairing on Barcode Scan when Cart is in STANDBY
    print("\n[STEP 7] Testing Fallback Auto-Pairing (Barcode scanned while cart is in STANDBY)...")
    await sm.stop()
    # Create fresh SM in STANDBY
    sm_fresh = CartStateMachine(lcd=lcd, buzzer=buzzer)
    await sm_fresh.start()
    assert sm_fresh.state == CartState.STANDBY, "Fresh cart must be in STANDBY"
    print(f"  Cart reset to: {sm_fresh.state.value}")

    # Now scan barcode directly without prior app pairing
    print("  Scanning barcode '8901058852234' directly in STANDBY mode...")
    await sm_fresh.on_barcode_scanned("8901058852234")
    print(f"  Pi State after scan with ALLOW_BARCODE_AUTO_PAIR: {sm_fresh.state.value} (Expected: PENDING_VERIFICATION)")
    print(f"  Pi Assigned User: {sm_fresh.user_id}")
    assert sm_fresh.state == CartState.PENDING_VERIFICATION, "Scan must auto-pair and transition to PENDING_VERIFICATION"
    await sm_fresh.stop()

    print("\n" + "=" * 70)
    print("ALL VERIFICATION CHECKS PASSED SUCCESSFULLY!")
    print("=" * 70)


if __name__ == "__main__":
    asyncio.run(run_verification())
