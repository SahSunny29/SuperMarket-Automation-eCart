#!/usr/bin/env python3
# ==============================================================================
# Smart Shopping Cart Edge Controller - FastAPI Application Entrypoint
# Target Hardware: Raspberry Pi 3 Model B+ (Serving on Port 5000)
# ==============================================================================

import os
from contextlib import asynccontextmanager
from typing import Any, Dict, Optional

from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from config import settings
from hardware.lcd_display import LCDDisplayController
from hardware.buzzer_controller import BuzzerController
from hardware.barcode_scanner import BarcodeScannerDaemon
from state_machine import CartStateMachine, CartState

import logging

logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("PiEdgeServer")

# Global Hardware & State Machine References
lcd: Optional[LCDDisplayController] = None
buzzer: Optional[BuzzerController] = None
scanner: Optional[BarcodeScannerDaemon] = None
state_machine: Optional[CartStateMachine] = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan context manager for startup & graceful hardware shutdown."""
    global lcd, buzzer, scanner, state_machine

    logger.info("================================================================")
    logger.info(f"   Starting Smart Shopping Cart Edge Controller ({settings.CART_ID})   ")
    logger.info("================================================================")

    # 1. Initialize JHD 162A 16x2 Parallel GPIO Character LCD Controller (4-bit Mode)
    lcd = LCDDisplayController(
        pin_rs=settings.LCD_PIN_RS,
        pin_e=settings.LCD_PIN_E,
        pins_data=settings.LCD_PINS_DATA,
        cols=settings.LCD_COLS,
        rows=settings.LCD_ROWS,
        simulated=settings.SIMULATED_HARDWARE,
    )

    # 2. Initialize Dual Active Buzzer Controller
    buzzer = BuzzerController(
        pin_buzzer1=settings.BUZZER_PIN_1,
        pin_buzzer2=settings.BUZZER_PIN_2,
        simulated=settings.SIMULATED_HARDWARE,
    )

    # 3. Initialize State Machine
    state_machine = CartStateMachine(
        lcd=lcd,
        buzzer=buzzer,
        central_server_url=settings.CENTRAL_SERVER_URL,
    )
    await state_machine.start()

    # 4. Initialize Barcode Scanner Daemon with event callback
    scanner = BarcodeScannerDaemon(
        device_path=settings.BARCODE_DEVICE_PATH,
        on_barcode_scanned=state_machine.on_barcode_scanned,
        simulated=settings.SIMULATED_HARDWARE,
    )
    await scanner.start(enable_stdin_simulation=False)

    logger.info(f"[Server] All hardware drivers & background daemons running on port {settings.PI_PORT}.")

    yield

    # Shutdown Sequence
    logger.info("[Server] Initiating shutdown sequence...")
    if scanner:
        await scanner.stop()
    if state_machine:
        await state_machine.stop()
    if buzzer:
        buzzer.cleanup()
    if lcd:
        lcd.close()
    logger.info("[Server] Edge Controller shutdown complete.")


# Initialize FastAPI App
app = FastAPI(
    title="Smart Shopping Cart Edge Controller",
    description="Edge API running on Raspberry Pi 3 B+ coordinating sensors, phone vision, and central server.",
    version="1.0.0",
    lifespan=lifespan,
)

# Enable CORS for phone browser clients and admin dashboard
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount Camera Node Static Web Application
camera_node_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "camera_node")
if os.path.exists(camera_node_dir):
    app.mount("/camera-node", StaticFiles(directory=camera_node_dir, html=True), name="camera_node")
    logger.info(f"[Server] Mounted /camera-node from {camera_node_dir}")
else:
    logger.warning(f"[Server] camera_node directory not found at {camera_node_dir}")


# ==============================================================================
# Pydantic Request & Response Models (Strict Schema Compliance)
# ==============================================================================

class VisionEventPayload(BaseModel):
    camera_id: str = Field(..., description="Camera identifier (CAM_LEFT or CAM_RIGHT)")
    event: str = Field(..., description="Crossing event type (CROSS_IN or CROSS_OUT)")
    detected_class: str = Field("item", description="Label of detected item")
    timestamp: float = Field(..., description="Unix epoch timestamp in seconds")


class SessionPairPayload(BaseModel):
    cart_id: str = Field(..., description="Identifier of the cart (e.g. CART_01)")
    user_id: str = Field(..., description="Shopper user ID from Flutter app")


class SessionResetPayload(BaseModel):
    cart_id: str = Field(..., description="Identifier of the cart")
    status: Optional[str] = Field("PAID", description="Payment status")


class SimulateScanPayload(BaseModel):
    barcode: str = Field(..., description="Barcode string to simulate (e.g. 8901030383848)")


# ==============================================================================
# REST API Endpoints
# ==============================================================================

@app.get("/", include_in_schema=False)
async def root_redirect():
    """Redirect root path to the Camera Node web application."""
    return RedirectResponse(url="/camera-node/")


@app.get("/api/status", response_model=Dict[str, Any])
async def get_cart_status():
    """Return real-time state, session details, and hardware status of the edge cart."""
    if not state_machine:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="State machine not initialized")
    return state_machine.get_status()


@app.post("/api/vision-event")
async def receive_vision_event(payload: VisionEventPayload):
    """Receive CROSS_IN or CROSS_OUT JSON trigger dispatched from phone browser vision engine over USB."""
    if not state_machine:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="State machine not ready")

    logger.debug(
        f"[API] Vision event received: {payload.camera_id} -> {payload.event} ({payload.detected_class})"
    )

    # Dispatch to state machine's 500ms debounce and reconciliation pipeline
    await state_machine.on_vision_event(
        camera_id=payload.camera_id,
        event=payload.event,
        detected_class=payload.detected_class,
        timestamp=payload.timestamp,
    )

    return {
        "status": "processed",
        "cart_id": settings.CART_ID,
        "current_state": state_machine.state.value,
    }


@app.post("/api/session/pair")
@app.post("/api/session/pair-notify")
@app.post("/api/cart/activate")
async def session_pair_notify(payload: SessionPairPayload):
    """Endpoint called by the Laptop Central Server when a shopper pairs with CART_01 via mobile app."""
    if not state_machine:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="State machine not ready")

    if payload.cart_id != settings.CART_ID:
        logger.warning(f"[API] Pairing requested for '{payload.cart_id}', but this cart is '{settings.CART_ID}'")

    await state_machine.on_session_paired(user_id=payload.user_id)

    return {
        "status": "paired",
        "cart_id": settings.CART_ID,
        "user_id": payload.user_id,
        "current_state": state_machine.state.value,
    }


@app.post("/api/session/reset")
@app.post("/api/session/checkout")
@app.post("/api/cart/checkout")
@app.post("/api/cart/reset")
async def session_reset_notify(payload: SessionResetPayload):
    """Endpoint called by the Laptop Central Server when shopper checkout payment succeeds."""
    if not state_machine:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="State machine not ready")

    await state_machine.on_checkout_complete()

    return {
        "status": "checkout_acknowledged",
        "cart_id": settings.CART_ID,
        "current_state": state_machine.state.value,
    }


# ==============================================================================
# Hardware-Free Simulation & Integration Debug Endpoints
# ==============================================================================

@app.post("/api/debug/simulate-scan")
async def debug_simulate_scan(payload: SimulateScanPayload):
    """Inject a simulated barcode scan into the state machine without physical USB hardware."""
    if not state_machine:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="State machine not ready")

    logger.info(f"[DEBUG API] Simulating barcode scan: '{payload.barcode}'")
    await state_machine.on_barcode_scanned(payload.barcode)

    return {
        "status": "scan_simulated",
        "barcode": payload.barcode,
        "current_state": state_machine.state.value,
    }


@app.post("/api/debug/clear-alert")
async def debug_clear_alert():
    """Manually clear any active security alarm and return cart to IDLE."""
    if not state_machine:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="State machine not ready")

    await state_machine.clear_alert()

    return {
        "status": "alert_cleared",
        "current_state": state_machine.state.value,
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=settings.PI_HOST,
        port=settings.PI_PORT,
        reload=False,
        log_level="info",
    )
