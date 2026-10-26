#!/usr/bin/env python3
"""
Central Store Server - Main FastAPI Application Entrypoint
Target Port: 8000
Coordinates:
- Real-time WebSockets (/ws/cart/{cart_id} and /ws/admin)
- Customer Mobile App REST APIs (Session Pairing, Wayfinding, Checkout)
- Upstream Edge Telemetry from Raspberry Pi Edge Controller (:5000)
- Store Admin Management and Security Grid
"""

import json
import logging
import time
from contextlib import asynccontextmanager
from typing import Any, Dict

import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from database import SessionLocal, init_db
from models import ActiveCart, CartItem, Product, SecurityAlert
from routes import cart_routes, checkout_routes
from routes.cart_routes import get_cart_items_list, recalculate_cart_totals
from seed_products import seed_database
from websocket_manager import manager

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("CentralServer.Main")


# ==============================================================================
# Application Lifespan Context Manager (Startup / Shutdown)
# ==============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Executes on application startup and graceful shutdown."""
    logger.info("================================================================")
    logger.info("   Starting Central Store Server (Port 8000)                   ")
    logger.info("================================================================")

    # 1. Initialize SQLite/PostgreSQL Database
    init_db()

    # 2. Seed catalog and ensure default products & carts exist
    logger.info("[Startup] Verifying retail inventory catalog and active carts...")
    seed_database()

    db = SessionLocal()
    try:
        product_count = db.query(Product).count()
        logger.info(f"[Startup] Database online with {product_count} retail products in catalog.")

        # Ensure default CART_01 is present
        cart_01 = db.query(ActiveCart).filter(ActiveCart.cart_id == "CART_01").first()
        if not cart_01:
            cart_01 = ActiveCart(
                cart_id="CART_01",
                store_id="DMART_HSR_01",
                status="IDLE",
                battery_level=88,
                ip_address="127.0.0.1",
            )
            db.add(cart_01)
            db.commit()
            logger.info("[Startup] Registered default smart cart: CART_01 (Status: IDLE).")
    finally:
        db.close()

    logger.info("[Startup] Central Server ready. Listening for Pi, Flutter, and Admin Dashboard.")

    yield

    logger.info("[Shutdown] Central Server shutting down cleanly.")


# Initialize FastAPI Application
app = FastAPI(
    title="Central Store Server",
    description="Unified Backend for Smart Shopping Cart Ecosystem, Edge Controller, Mobile App, and Admin Dashboard.",
    version="1.0.0",
    lifespan=lifespan,
)

# Enable CORS for Mobile App and Next.js/Vite Dashboard
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register REST API Routers
app.include_router(cart_routes.router)
app.include_router(checkout_routes.router)


# ==============================================================================
# WebSocket Endpoints
# ==============================================================================

@app.websocket("/ws/pi/{cart_id}")
async def websocket_pi_endpoint(websocket: WebSocket, cart_id: str):
    """
    Dedicated bidirectional WebSocket connection for Raspberry Pi Edge Controller.
    Used for instant command push (SESSION_PAIRED, CHECKOUT_COMPLETE, etc.)
    and telemetry synchronization.
    """
    await manager.connect_pi(websocket, cart_id)
    client_ip = websocket.client.host if websocket.client else "127.0.0.1"
    db = SessionLocal()
    try:
        cart = db.query(ActiveCart).filter(ActiveCart.cart_id == cart_id).first()
        if cart:
            if client_ip not in ("127.0.0.1", "localhost"):
                cart.ip_address = client_ip
            db.commit()
        await websocket.send_json({
            "action": "CONNECTED",
            "cart_id": cart_id,
            "status": "online",
            "server_time": time.time(),
            "message": f"Pi {cart_id} connected to Central Server",
        })
        logger.info(f"[WS] Pi '{cart_id}' established link from IP {client_ip}.")
    except Exception as e:
        logger.warning(f"[WS] Error during Pi connect handling: {e}")
    finally:
        db.close()

    try:
        while True:
            data = await websocket.receive_text()
            try:
                msg = json.loads(data)
                if isinstance(msg, dict):
                    msg_type = msg.get("type") or msg.get("action")
                    if msg_type == "ping":
                        await websocket.send_json({"type": "pong", "timestamp": time.time()})
                    elif msg_type == "register":
                        pi_ip = msg.get("pi_ip") or client_ip
                        db_reg = SessionLocal()
                        try:
                            c = db_reg.query(ActiveCart).filter(ActiveCart.cart_id == cart_id).first()
                            if c and pi_ip:
                                c.ip_address = pi_ip
                                db_reg.commit()
                        finally:
                            db_reg.close()
                        await websocket.send_json({"action": "REGISTERED", "cart_id": cart_id, "pi_ip": pi_ip})
            except Exception:
                if data.strip().lower() == "ping":
                    await websocket.send_json({"type": "pong", "timestamp": time.time()})
    except WebSocketDisconnect:
        await manager.disconnect_pi(websocket, cart_id)
    except Exception as e:
        logger.debug(f"[WS] Pi socket exception for '{cart_id}': {e}")
        await manager.disconnect_pi(websocket, cart_id)


@app.websocket("/ws/cart/{cart_id}")
async def websocket_cart_endpoint(websocket: WebSocket, cart_id: str):
    """
    Real-time dedicated WebSocket connection for Buyer's Flutter application.
    Subscribes to cart room, sends instant initial snapshot on connect,
    and streams verified drops, item removals, alerts, and checkout events.
    """
    await manager.connect_cart(websocket, cart_id)
    db = SessionLocal()
    try:
        # Send instant initial snapshot so Flutter UI immediately populates
        cart = db.query(ActiveCart).filter(ActiveCart.cart_id == cart_id).first()
        if cart:
            items_list = get_cart_items_list(db, cart_id)
            totals = recalculate_cart_totals(db, cart_id)
            initial_payload = {
                "action": "CART_UPDATED",
                "cart_id": cart_id,
                "session_id": cart.session_id,
                "status": cart.status,
                "running_total": totals["running_total"],
                "total_savings": totals["total_savings"],
                "items_count": totals["item_count"],
                "items": items_list,
                "timestamp": time.time(),
            }
            await websocket.send_json(initial_payload)
            logger.info(f"[WS] Dispatched initial snapshot for cart '{cart_id}' ({len(items_list)} items).")
    except Exception as e:
        logger.warning(f"[WS] Failed to send initial snapshot for cart '{cart_id}': {e}")
    finally:
        db.close()

    # Continuous listener for heartbeats (ping -> pong)
    try:
        while True:
            data = await websocket.receive_text()
            try:
                msg = json.loads(data)
                if isinstance(msg, dict) and msg.get("type") == "ping":
                    await websocket.send_json({"type": "pong", "timestamp": time.time()})
            except Exception:
                if data.strip().lower() == "ping":
                    await websocket.send_json({"type": "pong", "timestamp": time.time()})
    except WebSocketDisconnect:
        await manager.disconnect_cart(websocket, cart_id)
    except Exception as e:
        logger.debug(f"[WS] Cart socket exception for '{cart_id}': {e}")
        await manager.disconnect_cart(websocket, cart_id)


@app.websocket("/ws/admin")
async def websocket_admin_endpoint(websocket: WebSocket):
    """
    Global real-time WebSocket connection for Store Manager's Admin Dashboard.
    Streams live cart updates, anti-theft security anomaly alerts, and KPI counters.
    """
    await manager.connect_admin(websocket)
    db = SessionLocal()
    try:
        # Send instant initial fleet snapshot to Admin Dashboard
        carts = db.query(ActiveCart).all()
        alerts = (
            db.query(SecurityAlert)
            .filter(SecurityAlert.is_resolved == False)
            .order_by(SecurityAlert.id.desc())
            .limit(10)
            .all()
        )
        cart_snapshots = []
        for c in carts:
            cart_snapshots.append({
                "cart_id": c.cart_id,
                "state": c.status,
                "status": c.status,
                "battery_level": c.battery_level,
                "user_id": c.user_id,
                "items_count": c.item_count,
                "running_total": c.total_amount,
            })

        alert_snapshots = []
        for a in alerts:
            alert_snapshots.append({
                "id": a.id,
                "cart_id": a.cart_id,
                "alert_type": a.alert_type,
                "message": a.message,
                "timestamp": a.timestamp,
            })

        await websocket.send_json({
            "type": "INITIAL_SNAPSHOT",
            "carts": cart_snapshots,
            "alerts": alert_snapshots,
            "timestamp": time.time(),
        })
        logger.info(f"[WS] Dispatched initial admin snapshot ({len(cart_snapshots)} carts).")
    except Exception as e:
        logger.warning(f"[WS] Failed to send initial admin snapshot: {e}")
    finally:
        db.close()

    try:
        while True:
            data = await websocket.receive_text()
            try:
                msg = json.loads(data)
                if isinstance(msg, dict) and msg.get("type") == "ping":
                    await websocket.send_json({"type": "pong", "timestamp": time.time()})
            except Exception:
                if data.strip().lower() == "ping":
                    await websocket.send_json({"type": "pong", "timestamp": time.time()})
    except WebSocketDisconnect:
        await manager.disconnect_admin(websocket)
    except Exception as e:
        logger.debug(f"[WS] Admin socket exception: {e}")
        await manager.disconnect_admin(websocket)


# ==============================================================================
# Development Server Runner
# ==============================================================================

if __name__ == "__main__":
    uvicorn.run(
        "server:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        log_level="info",
    )
