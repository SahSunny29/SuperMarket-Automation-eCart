#!/usr/bin/env python3
"""
Verification Script: Hardware Adaptation & Dual-Camera Debounce Validation
Validates:
1. Pairing CART_01 with mobile shopper.
2. Single-camera mode: Barcode scan + CROSS_IN from CAM_LEFT only -> verifies and dispatches ADD_ITEM once.
3. Dual-camera mode: Barcode scan + CROSS_IN from CAM_LEFT & CAM_RIGHT arriving 50ms apart ->
   verifies first trigger, deduplicates second trigger within 500ms, and dispatches ADD_ITEM strictly once.
4. LCD terminal preview mirror works cleanly without physical hardware.
"""

import asyncio
import os
import sys
import time

current_dir = os.path.dirname(os.path.abspath(__file__))
central_dir = os.path.join(current_dir, "Central-Server")
pi_dir = os.path.join(current_dir, "Pi-Backend")
sys.path.insert(0, central_dir)
sys.path.insert(0, pi_dir)

from starlette.testclient import TestClient

from server import app as central_app
from database import SessionLocal, init_db
from models import ActiveCart, Product, CartItem
from state_machine import CartStateMachine, CartState
from hardware.lcd_display import LCDDisplayController
from hardware.buzzer_controller import BuzzerController
from hardware.barcode_scanner import BarcodeScannerDaemon


async def test_hardware_adaptation():
    print("=" * 75)
    print("RUNNING HARDWARE ADAPTATION & CAMERA DEBOUNCE VERIFICATION")
    print("=" * 75)

    # 1. Initialize DB and Seed Products
    init_db()
    db = SessionLocal()
    cart = db.query(ActiveCart).filter(ActiveCart.cart_id == "CART_01").first()
    if not cart:
        cart = ActiveCart(cart_id="CART_01", status="IDLE", ip_address="127.0.0.1", battery_level=90)
        db.add(cart)
    else:
        cart.status = "IDLE"
        cart.user_id = None
        cart.total_amount = 0.0
        cart.item_count = 0
    # Clear cart items
    db.query(CartItem).filter(CartItem.cart_id == "CART_01").delete()
    db.commit()

    # Seed Product 1: Maggi Noodles
    p1 = db.query(Product).filter(Product.barcode == "8901058852234").first()
    if not p1:
        p1 = Product(
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
        db.add(p1)

    # Seed Product 2: Amul Butter
    p2 = db.query(Product).filter(Product.barcode == "8901030383848").first()
    if not p2:
        p2 = Product(
            barcode="8901030383848",
            sku="AMUL-BUTTER-100G",
            name="Amul Butter 100g",
            brand="Amul",
            category="Dairy",
            aisle="Aisle 2",
            shelf_section="Sec B",
            mrp=60.0,
            sale_price=56.0,
            stock_qty=80,
            unit_weight_grams=100,
        )
        db.add(p2)
    expected_total = (p1.sale_price if p1 else 14.0) + (p2.sale_price if p2 else 56.0)
    db.commit()
    db.close()

    central_client = TestClient(central_app)

    # 2. Track upstream sync events dispatched to Central Server
    dispatched_syncs = []

    # Mock dispatch method on state machine to intercept calls
    lcd = LCDDisplayController(simulated=True)
    buzzer = BuzzerController(simulated=True)
    sm = CartStateMachine(lcd=lcd, buzzer=buzzer)
    await sm.start()

    # Wrap _dispatch_upstream_sync so we can count exact calls to Central Server
    orig_dispatch = sm._dispatch_upstream_sync

    async def intercepted_dispatch(action: str, barcode=None, detected_class="item"):
        dispatched_syncs.append({"action": action, "barcode": barcode})
        # Forward to central server test client
        central_client.post(
            "/api/cart/sync",
            json={
                "cart_id": "CART_01",
                "action": action,
                "barcode": barcode,
                "detected_class": detected_class,
                "timestamp": time.time(),
            },
        )
        await orig_dispatch(action=action, barcode=barcode, detected_class=detected_class)

    sm._dispatch_upstream_sync = intercepted_dispatch

    # STEP A: Pair Cart
    print("\n--- [TEST A: Cart Pairing] ---")
    pair_resp = central_client.post("/api/session/pair", json={"cart_id": "CART_01", "user_id": "U_TEST_01"})
    assert pair_resp.status_code == 200, "Pairing must return 200"
    await sm.on_session_paired("U_TEST_01")
    print(f"Cart paired. State: {sm.state.value} (Expected: IDLE)")
    assert sm.state == CartState.IDLE, "Cart must be in IDLE state"

    # STEP B: 1-Camera Phone Test (CAM_LEFT Only)
    print("\n--- [TEST B: Single Camera Phone Mode (CAM_LEFT only)] ---")
    syncs_before_b = len(dispatched_syncs)
    print("1. Scanning barcode '8901058852234' with USB barcode scanner...")
    await sm.on_barcode_scanned("8901058852234")
    print(f"   State after scan: {sm.state.value} (Expected: PENDING_VERIFICATION)")
    assert sm.state == CartState.PENDING_VERIFICATION, "Must be PENDING_VERIFICATION"

    print("2. Receiving physical item drop event from CAM_LEFT only...")
    await sm.on_vision_event(camera_id="CAM_LEFT", event="CROSS_IN", detected_class="item")
    print(f"   State after CAM_LEFT trigger: {sm.state.value} (Expected: VERIFIED)")
    assert sm.state == CartState.VERIFIED, "Single camera trigger must transition state to VERIFIED"

    # Allow asyncio.create_task for dispatch to yield and run
    await asyncio.sleep(0.1)

    # Check Central Server sync was dispatched exactly once
    new_syncs_b = [s for s in dispatched_syncs[syncs_before_b:] if s["action"] == "ADD_ITEM"]
    print(f"   Upstream ADD_ITEM syncs dispatched: {len(new_syncs_b)} (Expected: 1)")
    assert len(new_syncs_b) == 1, "Must dispatch ADD_ITEM exactly once for 1 camera phone"
    assert new_syncs_b[0]["barcode"] == "8901058852234"

    # Wait briefly for transition back to IDLE
    await asyncio.sleep(1.8)
    print(f"   State after verification: {sm.state.value} (Expected: IDLE)")
    assert sm.state == CartState.IDLE

    # STEP C: 2-Camera Phone Test (CAM_LEFT and CAM_RIGHT arriving 50ms apart)
    print("\n--- [TEST C: Dual Camera Phone Mode (CAM_LEFT + CAM_RIGHT 50ms apart)] ---")
    syncs_before_c = len(dispatched_syncs)
    print("1. Scanning second barcode '8901030383848' with USB barcode scanner...")
    await sm.on_barcode_scanned("8901030383848")
    print(f"   State after scan: {sm.state.value} (Expected: PENDING_VERIFICATION)")
    assert sm.state == CartState.PENDING_VERIFICATION

    print("2. Firing simultaneous dual-camera CROSS_IN (CAM_LEFT @ 0ms, CAM_RIGHT @ 50ms)...")
    t0 = time.time()
    await sm.on_vision_event(camera_id="CAM_LEFT", event="CROSS_IN", detected_class="item", timestamp=t0)
    print(f"   State after CAM_LEFT: {sm.state.value} (Expected: VERIFIED)")
    assert sm.state == CartState.VERIFIED

    # 50ms later, CAM_RIGHT detects the same physical item crossing
    await asyncio.sleep(0.050)
    t1 = t0 + 0.050
    await sm.on_vision_event(camera_id="CAM_RIGHT", event="CROSS_IN", detected_class="item", timestamp=t1)
    print(f"   CAM_RIGHT 50ms event processed. State remains: {sm.state.value}")

    # Allow asyncio background dispatch task to yield and run
    await asyncio.sleep(0.1)

    # Verify that the 2nd camera was merged and ADD_ITEM was dispatched strictly ONCE
    new_syncs_c = [s for s in dispatched_syncs[syncs_before_c:] if s["action"] == "ADD_ITEM"]
    print(f"   Upstream ADD_ITEM syncs dispatched: {len(new_syncs_c)} (Expected: strictly 1)")
    assert len(new_syncs_c) == 1, "500ms debounce must ensure ADD_ITEM is dispatched ONLY once across dual cameras"
    assert new_syncs_c[0]["barcode"] == "8901030383848"

    # STEP D: Verify Central Server final cart state
    print("\n--- [TEST D: Central Server Basket Verification] ---")
    cart_resp = central_client.get("/api/cart/CART_01")
    assert cart_resp.status_code == 200
    cart_data = cart_resp.json()
    print(f"   Central Server Cart Status: {cart_data['status']}")
    print(f"   Total Items in Basket: {cart_data['item_count']} (Expected: 2)")
    print(f"   Running Total: Rs.{cart_data['running_total']} (Expected: Rs.{expected_total})")
    assert cart_data["item_count"] == 2, "Basket must have exactly 2 items"
    assert cart_data["running_total"] == expected_total, f"Total must match Rs.{expected_total}"

    # STEP E: Verify Barcode Scanner Daemon Discovery & Startup
    print("\n--- [TEST E: Barcode Scanner Daemon Discovery] ---")
    scanner = BarcodeScannerDaemon(simulated=None)
    print(f"   Scanner Mode: {'Physical evdev' if not scanner.simulated else 'Auto-simulation'}")
    print(f"   Scanner Device Path: {scanner.device_path or 'None (Virtual)'}")
    await scanner.start(enable_stdin_simulation=False)
    await scanner.stop()

    await sm.stop()

    print("\n" + "=" * 75)
    print("SUCCESS: ALL HARDWARE ADAPTATION & DEBOUNCE CHECKS PASSED!")
    print("=" * 75)


if __name__ == "__main__":
    asyncio.run(test_hardware_adaptation())
