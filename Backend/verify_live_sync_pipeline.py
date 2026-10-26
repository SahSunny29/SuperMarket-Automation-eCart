#!/usr/bin/env python3
"""
Verification Script: Live Pipeline & Unknown Real-World Barcode Test
Validates:
1. Unknown barcode lookup (GET /api/products/barcode/{barcode}) auto-creates fallback product and returns HTTP 200.
2. Pi Edge verified drop sync (POST /api/cart/sync ADD_ITEM) with unseeded barcode:
   - Auto-creates product in catalog
   - Updates basket in database
   - Emits immediate WebSocket broadcast on /ws/cart/{cart_id} with complete items snapshot
3. REST endpoint (GET /api/cart/{cart_id}) returns complete snapshot matching Flutter CartItem.fromJson.
"""

import asyncio
import os
import sys
import time

current_dir = os.path.dirname(os.path.abspath(__file__))
central_dir = os.path.join(current_dir, "Central-Server")
sys.path.insert(0, central_dir)

from starlette.testclient import TestClient

from server import app as central_app
from database import SessionLocal, init_db
from models import ActiveCart, Product, CartItem


def run_pipeline_verification():
    print("=" * 75)
    print("VERIFYING LIVE INGESTION PIPELINE & UNKNOWN REAL-WORLD BARCODES")
    print("=" * 75)

    init_db()
    db = SessionLocal()
    # Reset CART_01 to clean state
    cart = db.query(ActiveCart).filter(ActiveCart.cart_id == "CART_01").first()
    if not cart:
        cart = ActiveCart(cart_id="CART_01", status="IDLE", ip_address="127.0.0.1", battery_level=90)
        db.add(cart)
    else:
        cart.status = "IDLE"
        cart.user_id = None
        cart.total_amount = 0.0
        cart.item_count = 0
    db.query(CartItem).filter(CartItem.cart_id == "CART_01").delete()
    db.commit()
    db.close()

    client = TestClient(central_app)

    # 1. Test Unknown Barcode Auto-Creation via GET /api/products/barcode/{barcode}
    print("\n[STEP 1] Testing Unknown Barcode Auto-Creation (GET /api/products/barcode/{barcode})...")
    random_barcode_1 = "9998887776665"
    # Ensure not in catalog beforehand
    db = SessionLocal()
    db.query(Product).filter(Product.barcode == random_barcode_1).delete()
    db.commit()
    db.close()

    resp_lookup = client.get(f"/api/products/barcode/{random_barcode_1}")
    print(f"  Lookup status: {resp_lookup.status_code}")
    print(f"  Lookup body: {resp_lookup.json()}")
    assert resp_lookup.status_code == 200, "Unknown barcode lookup must succeed with 200"
    data_lookup = resp_lookup.json()
    assert data_lookup["barcode"] == random_barcode_1
    assert data_lookup["name"] == "Scanned Item (6665)"
    assert data_lookup["price"] == 50.0
    assert data_lookup["original_price"] == 55.0

    # 2. Test Pairing CART_01
    print("\n[STEP 2] Pairing CART_01 with Buyer App...")
    pair_resp = client.post("/api/session/pair", json={"cart_id": "CART_01", "user_id": "U_LIVE_TEST"})
    assert pair_resp.status_code == 200, "Pairing must return 200"
    print(f"  Pair response: {pair_resp.json()['status']}")

    # 3. Test Real-Time WebSocket Connection & ADD_ITEM Broadcast with Unknown Barcode
    print("\n[STEP 3] Testing Real-Time WebSocket Broadcast on /ws/cart/CART_01...")
    random_barcode_2 = "8901234567890"

    with client.websocket_connect("/ws/cart/CART_01") as ws:
        # Step 3a: Read initial snapshot sent on connect
        initial_msg = ws.receive_json()
        print(f"  Received initial WS snapshot on connect: action={initial_msg.get('action')}, items={len(initial_msg.get('items', []))}")
        assert initial_msg.get("action") == "CART_UPDATED"
        assert "items" in initial_msg

        # Step 3b: Pi Edge sends POST /api/cart/sync (ADD_ITEM) with the unseeded barcode
        print(f"  Pi Edge Controller posting verified drop: barcode='{random_barcode_2}'...")
        sync_resp = client.post(
            "/api/cart/sync",
            json={
                "cart_id": "CART_01",
                "action": "ADD_ITEM",
                "barcode": random_barcode_2,
                "detected_class": "item",
                "timestamp": time.time(),
            },
        )
        print(f"  Pi sync response: {sync_resp.status_code} - {sync_resp.json()}")
        assert sync_resp.status_code == 200, "Sync must return 200"

        # Step 3c: Verify live WebSocket message received by Flutter client
        live_ws_msg = ws.receive_json()
        print(f"  Received live WS event: action={live_ws_msg.get('action')}, barcode={live_ws_msg.get('barcode')}, running_total={live_ws_msg.get('running_total')}")
        assert live_ws_msg.get("action") == "ADD_ITEM"
        assert live_ws_msg.get("barcode") == random_barcode_2
        assert len(live_ws_msg.get("items", [])) == 1

        first_item = live_ws_msg["items"][0]
        print(f"  First item in payload: name='{first_item['name']}', price={first_item['price']}, qty={first_item['quantity']}")
        assert first_item["barcode"] == random_barcode_2
        assert first_item["name"] == "Scanned Item (7890)"
        assert first_item["price"] == 50.0

    # 4. Test REST Snapshot GET /api/cart/CART_01 (used by Flutter refreshCartState())
    print("\n[STEP 4] Testing REST Cart Snapshot (GET /api/cart/CART_01)...")
    cart_resp = client.get("/api/cart/CART_01")
    assert cart_resp.status_code == 200
    cart_json = cart_resp.json()
    print(f"  Cart Status: {cart_json['status']}")
    print(f"  Item Count: {cart_json['item_count']}")
    print(f"  Running Total: Rs.{cart_json['running_total']}")
    print(f"  Items: {cart_json['items']}")
    assert cart_json["item_count"] == 1
    assert cart_json["running_total"] == 50.0
    assert len(cart_json["items"]) == 1

    print("\n" + "=" * 75)
    print("ALL LIVE PIPELINE CHECKS PASSED SUCCESSFULLY!")
    print("=" * 75)


if __name__ == "__main__":
    run_pipeline_verification()
