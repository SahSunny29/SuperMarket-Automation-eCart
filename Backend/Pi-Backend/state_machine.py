#!/usr/bin/env python3
# ==============================================================================
# Smart Shopping Cart Edge Controller - Cart State Machine & Sensor Fusion
# Target: Raspberry Pi 3 Model B+
# Reconciles USB Barcode Scans, Dual Phone Vision Events, and Hardware I/O
# Latency Target: <300ms edge reconciliation loop
# ==============================================================================

import asyncio
import enum
import json
import logging
import socket
import time
from urllib.parse import urlparse
from typing import Any, Dict, Optional

import httpx

from config import settings
from hardware.lcd_display import LCDDisplayController
from hardware.buzzer_controller import BuzzerController

logger = logging.getLogger("CartStateMachine")


# Demo Product Catalog mapping for 16x2 LCD Line 1 (strictly <= 16 characters)
DEMO_PRODUCT_CATALOG: Dict[str, str] = {
    "8901058852234": "Maggi Noodles",
    "8901030383848": "Amul Butter 100g",
    "8901058852241": "Maggi Special",
    "8901725181222": "Tata Salt 1kg",
    "8901491101833": "Lays Classic",
    "8901030383855": "Amul Milk 500ml",
    "8901725181239": "Tata Tea 250g",
    "8901491101840": "Kurkure Masala",
}


class CartState(str, enum.Enum):
    """Finite State Machine states for the Smart Shopping Cart."""
    STANDBY = "STANDBY"                            # Unpaired, displaying QR prompt
    IDLE = "IDLE"                                  # Paired with shopper, ready for scan
    PENDING_VERIFICATION = "PENDING_VERIFICATION"  # Barcode scanned, 5.0s window active
    VERIFIED = "VERIFIED"                          # Drop verified, dispatching to server
    ALERT = "ALERT"                                # Security anomaly: unscanned drop
    PAID = "PAID"                                  # Checkout complete, playing chime


def _detect_local_ip(target_host: str = "8.8.8.8") -> str:
    """Detect local IP address of the active Wi-Fi interface by opening a dummy UDP socket."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect((target_host, 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


class CartStateMachine:
    """Asynchronous, thread-safe state machine managing shopping cart workflow.
    
    Coordinates the 500ms dual-camera debounce filter, 5.0s verification countdown,
    <300ms hardware audio-visual feedback, and upstream HTTP telemetry to the Central Server.
    """

    def __init__(
        self,
        lcd: LCDDisplayController,
        buzzer: BuzzerController,
        central_server_url: Optional[str] = None,
    ):
        """Initialize the state machine.

        Args:
            lcd: Initialized LCDDisplayController instance.
            buzzer: Initialized BuzzerController instance.
            central_server_url: Base URL of the Laptop Central Server.
        """
        self.lcd = lcd
        self.buzzer = buzzer
        self.central_server_url = (central_server_url or settings.CENTRAL_SERVER_URL).rstrip("/")

        self._state: CartState = CartState.STANDBY
        self._lock = asyncio.Lock()

        # Session Context
        self.user_id: Optional[str] = None
        self.pending_barcode: Optional[str] = None
        self.verification_deadline: float = 0.0
        self._countdown_task: Optional[asyncio.Task] = None
        self._sync_task: Optional[asyncio.Task] = None

        # 500ms Dual-Camera Debounce Filter State
        self._last_crossing_event: Optional[str] = None
        self._last_crossing_timestamp: float = 0.0

        # Telemetry & Diagnostics
        self.last_event: Optional[Dict[str, Any]] = None
        self.start_time = time.monotonic()

        # HTTP Client for Central Server communication
        self._http_client: Optional[httpx.AsyncClient] = None

    async def start(self) -> None:
        """Start background services and initialize hardware to STANDBY."""
        self._http_client = httpx.AsyncClient(timeout=3.0)
        async with self._lock:
            self._state = CartState.STANDBY
            self.lcd.show_standby()
            self.buzzer.play_startup_chirp()
            logger.info(f"[FSM] Cart {settings.CART_ID} initialized in STANDBY state.")

        # Start background Central Server synchronization loop
        self._sync_task = asyncio.create_task(self._central_server_sync_loop())

    async def stop(self) -> None:
        """Clean up background tasks and HTTP connections."""
        if self._countdown_task and not self._countdown_task.done():
            self._countdown_task.cancel()
        if self._sync_task and not self._sync_task.done():
            self._sync_task.cancel()
        if self._http_client:
            await self._http_client.aclose()
        logger.info("[FSM] State machine stopped.")

    @property
    def state(self) -> CartState:
        """Current state of the cart."""
        return self._state

    def get_status(self) -> Dict[str, Any]:
        """Return a snapshot of current cart status for HTTP telemetry."""
        now = time.monotonic()
        remaining = max(0.0, self.verification_deadline - now) if self._state == CartState.PENDING_VERIFICATION else 0.0
        return {
            "cart_id": settings.CART_ID,
            "state": self._state.value,
            "user_id": self.user_id,
            "pending_barcode": self.pending_barcode,
            "seconds_remaining": round(remaining, 2),
            "hardware_simulated": {
                "lcd": getattr(self.lcd, "simulated", True),
                "buzzer": getattr(self.buzzer, "simulated", True),
            },
            "last_event": self.last_event,
            "uptime_sec": round(now - self.start_time, 1),
        }

    # ==========================================================================
    # 500ms Dual-Camera Debounce Filter
    # ==========================================================================

    def _debounce_crossing_event(self, camera_id: str, event_type: str, timestamp: float) -> bool:
        """Filter out duplicate crossing triggers from CAM_LEFT and CAM_RIGHT within 500ms.

        Returns:
            True if this is an accepted new physical crossing event.
            False if discarded as a debounced duplicate.
        """
        now = time.monotonic()
        time_delta_ms = (now - self._last_crossing_timestamp) * 1000.0

        if (
            self._last_crossing_event == event_type
            and time_delta_ms < settings.CAMERA_DEBOUNCE_MS
        ):
            logger.info(
                f"[DEBOUNCE] Merged duplicate '{event_type}' from {camera_id} "
                f"({time_delta_ms:.1f}ms < {settings.CAMERA_DEBOUNCE_MS}ms). Deduplicated into single item drop."
            )
            return False

        self._last_crossing_event = event_type
        self._last_crossing_timestamp = now
        logger.info(f"[DEBOUNCE] Accepted physical event: '{event_type}' from {camera_id}.")
        return True

    # ==========================================================================
    # State Transition Handlers
    # ==========================================================================

    async def on_session_paired(self, user_id: str) -> None:
        """Stage 1: Shopper scans cart QR via mobile app -> Central Server pairs cart."""
        async with self._lock:
            self.user_id = user_id
            self._state = CartState.IDLE
            self.pending_barcode = None

            # Immediate hardware audio-visual feedback (<300ms)
            self.lcd.show_cart_synced(settings.CART_ID)
            self.buzzer.play_pair_success()

            self.last_event = {
                "type": "SESSION_PAIRED",
                "user_id": user_id,
                "timestamp": time.time(),
            }
            logger.info(f"[FSM] Session paired with shopper '{user_id}'. State -> IDLE.")

            # Transition to Ready after brief greeting
            asyncio.create_task(self._delayed_ready_prompt(1.8))

    async def on_barcode_scanned(self, barcode: str) -> None:
        """Stage 2: Shopper scans an item barcode using the USB optical scanner."""
        async with self._lock:
            if self._state == CartState.STANDBY:
                if settings.ALLOW_BARCODE_AUTO_PAIR:
                    logger.info(f"[FSM] Auto-pairing cart {settings.CART_ID} upon barcode scan: '{barcode}'.")
                    self.user_id = self.user_id or "U_WALKIN"
                    self._state = CartState.IDLE
                    self.lcd.show_cart_synced(settings.CART_ID)
                    self.buzzer.play_pair_success()
                    asyncio.create_task(self._notify_central_server_auto_pair(self.user_id))
                else:
                    logger.warning(f"[FSM] Barcode scanned ('{barcode}') while cart in STANDBY. Ignoring.")
                    self.buzzer.play_timeout_error_tone()
                    return

            if self._state == CartState.ALERT:
                logger.warning(f"[FSM] Barcode scanned ('{barcode}') while cart in ALERT.")
                return

            # Cancel any previous active countdown
            if self._countdown_task and not self._countdown_task.done():
                self._countdown_task.cancel()

            self._state = CartState.PENDING_VERIFICATION
            self.pending_barcode = barcode
            self.verification_deadline = time.monotonic() + settings.VERIFICATION_WINDOW_SEC

            # Immediate audio-visual feedback (<300ms)
            item_name = DEMO_PRODUCT_CATALOG.get(barcode, barcode[:16])
            self.buzzer.play_scan_beep()
            self.lcd.show_pending_verification(barcode=barcode, item_name=item_name, seconds_left=int(settings.VERIFICATION_WINDOW_SEC))

            self.last_event = {
                "type": "BARCODE_SCANNED",
                "barcode": barcode,
                "timestamp": time.time(),
            }
            logger.info(
                f"[FSM] Scanned barcode: '{barcode}'. State -> PENDING_VERIFICATION "
                f"({settings.VERIFICATION_WINDOW_SEC}s window started)."
            )

            # Start 5.0-second countdown task
            self._countdown_task = asyncio.create_task(
                self._verification_countdown_loop(barcode, settings.VERIFICATION_WINDOW_SEC)
            )

    async def _verification_countdown_loop(self, barcode: str, duration: float) -> None:
        """Asynchronously updates the LCD countdown second by second until timeout."""
        try:
            start = time.monotonic()
            end = start + duration

            while time.monotonic() < end:
                await asyncio.sleep(1.0)
                remaining = int(round(end - time.monotonic()))
                if remaining > 0 and self._state == CartState.PENDING_VERIFICATION:
                    item_name = DEMO_PRODUCT_CATALOG.get(barcode, barcode[:16])
                    self.lcd.show_pending_verification(barcode=barcode, item_name=item_name, seconds_left=remaining)

            # Timeout reached without verified drop
            await self._handle_scan_timeout()

        except asyncio.CancelledError:
            # Drop verified or cancelled early
            pass

    async def _handle_scan_timeout(self) -> None:
        """Stage 2 Resolution (Timeout): 5.0 seconds elapsed without a drop."""
        async with self._lock:
            if self._state != CartState.PENDING_VERIFICATION:
                return

            logger.info(f"[FSM] Verification timeout for barcode '{self.pending_barcode}'. Cancelling.")
            self._state = CartState.IDLE
            self.pending_barcode = None

            # Immediate audio-visual feedback
            self.buzzer.play_timeout_error_tone()
            self.lcd.show_scan_cancelled()

            self.last_event = {
                "type": "SCAN_TIMEOUT",
                "timestamp": time.time(),
            }

            # Return to Ready display
            asyncio.create_task(self._delayed_ready_prompt(1.8))

    async def on_vision_event(
        self,
        camera_id: str,
        event: str,
        detected_class: str = "item",
        timestamp: Optional[float] = None,
    ) -> None:
        """Stage 2: Receives CROSS_IN / CROSS_OUT trigger over USB from CAM_LEFT or CAM_RIGHT."""
        # Step 1: Apply 500ms dual-camera debounce filter
        if not self._debounce_crossing_event(camera_id, event, timestamp or time.time()):
            return

        async with self._lock:
            if event == "CROSS_IN":
                await self._handle_cross_in(detected_class)
            elif event == "CROSS_OUT":
                await self._handle_cross_out(detected_class)

    async def _handle_cross_in(self, detected_class: str) -> None:
        """Process an accepted physical CROSS_IN item drop."""
        # Case A: Matched drop during active PENDING_VERIFICATION window
        if self._state == CartState.PENDING_VERIFICATION and self.pending_barcode:
            # Cancel countdown timer immediately
            if self._countdown_task and not self._countdown_task.done():
                self._countdown_task.cancel()

            verified_barcode = self.pending_barcode
            self._state = CartState.VERIFIED
            self.pending_barcode = None

            # Immediate audio-visual feedback (<300ms)
            item_name = DEMO_PRODUCT_CATALOG.get(verified_barcode, "Item Added!")
            self.buzzer.play_verified_double_beep()
            self.lcd.show_item_added(item_name=item_name)

            self.last_event = {
                "type": "VERIFIED_DROP",
                "barcode": verified_barcode,
                "detected_class": detected_class,
                "timestamp": time.time(),
            }
            logger.info(f"[FSM] Item verified! Barcode '{verified_barcode}' matched to physical drop.")

            # Asynchronously sync to Central Server
            asyncio.create_task(
                self._dispatch_upstream_sync(
                    action="ADD_ITEM",
                    barcode=verified_barcode,
                    detected_class=detected_class,
                )
            )

            # Return to IDLE
            asyncio.create_task(self._delayed_ready_prompt(1.6))

        # Case B: Unscanned item dropped into cart (Security Anomaly)
        elif self._state in (CartState.IDLE, CartState.STANDBY, CartState.PENDING_VERIFICATION):
            if self._countdown_task and not self._countdown_task.done():
                self._countdown_task.cancel()

            self._state = CartState.ALERT
            self.user_id = None
            self.pending_barcode = None

            # Immediate security feedback
            self.buzzer.start_unscanned_alarm()
            self.lcd.show_unscanned_alert()

            self.last_event = {
                "type": "UNSCANNED_DROP_ALERT",
                "detected_class": detected_class,
                "timestamp": time.time(),
            }
            logger.warning("[FSM] SECURITY ALERT: Unscanned item dropped into cart! Terminating sync immediately.")

            # Dispatch security alert to Central Server
            asyncio.create_task(
                self._dispatch_upstream_sync(
                    action="UNSCANNED_DROP",
                    detected_class=detected_class,
                )
            )

            # Stop syncing immediately: display warning for 3.0s, then reset directly to STANDBY
            asyncio.create_task(self._delayed_alert_standby_reset(3.0))

    async def _handle_cross_out(self, detected_class: str) -> None:
        """Process an accepted physical CROSS_OUT item removal."""
        logger.info(f"[FSM] Outward crossing detected ({detected_class}).")
        self.last_event = {
            "type": "ITEM_REMOVED",
            "detected_class": detected_class,
            "timestamp": time.time(),
        }

        # Forward removal telemetry to Central Server if session is active
        if self._state in (CartState.IDLE, CartState.PENDING_VERIFICATION) and self.user_id:
            asyncio.create_task(
                self._dispatch_upstream_sync(
                    action="REMOVE_ITEM",
                    detected_class=detected_class,
                )
            )

    async def on_checkout_complete(self) -> None:
        """Stage 4: Laptop Central Server marks session PAID -> Reset cart."""
        async with self._lock:
            # Cancel any pending countdown
            if self._countdown_task and not self._countdown_task.done():
                self._countdown_task.cancel()

            self.buzzer.stop_alarm()
            self._state = CartState.PAID
            self.pending_barcode = None

            # Immediate audio-visual feedback (<300ms)
            self.lcd.show_checkout_complete()
            self.buzzer.play_checkout_chime()

            self.last_event = {
                "type": "CHECKOUT_COMPLETE",
                "user_id": self.user_id,
                "timestamp": time.time(),
            }
            logger.info(f"[FSM] Checkout complete for cart '{settings.CART_ID}'. Resetting to STANDBY.")

            # Pause briefly for customer to see thank you, then reset to STANDBY
            asyncio.create_task(self._delayed_standby_reset(3.2))

    async def clear_alert(self) -> None:
        """Manual / debug resolution to stop the alarm and reset directly to STANDBY."""
        async with self._lock:
            self.buzzer.stop_alarm()
            self._state = CartState.STANDBY
            self.user_id = None
            self.pending_barcode = None
            self.lcd.show_standby()
            logger.info("[FSM] Security alert manually cleared. Reset to STANDBY.")

    async def _delayed_alert_standby_reset(self, delay_seconds: float) -> None:
        """Display security alert for 3 seconds, silence alarm, and reset directly to STANDBY."""
        await asyncio.sleep(delay_seconds)
        async with self._lock:
            self.buzzer.stop_alarm()
            self._state = CartState.STANDBY
            self.user_id = None
            self.pending_barcode = None
            self.lcd.show_standby()
            logger.info("[FSM] Security alert completed. Pi Edge reset directly to STANDBY (Scan handle QR!).")

    # ==========================================================================
    # Upstream HTTP Dispatch to Laptop Central Server
    # ==========================================================================

    async def _dispatch_upstream_sync(
        self,
        action: str,
        barcode: Optional[str] = None,
        detected_class: str = "item",
    ) -> None:
        """Asynchronously dispatch cart sync / alert payload to the Laptop Central Server."""
        payload = {
            "cart_id": settings.CART_ID,
            "action": action,
            "detected_class": detected_class,
            "timestamp": round(time.time(), 3),
        }
        if barcode:
            payload["barcode"] = barcode

        sync_url = f"{self.central_server_url}/api/cart/sync"
        logger.info(f"[UPSTREAM] Dispatching {action} -> {sync_url} ({payload})")

        if not self._http_client:
            return

        try:
            resp = await self._http_client.post(sync_url, json=payload)
            if resp.status_code in (200, 201):
                logger.info(f"[UPSTREAM] Sync acknowledged by server (HTTP {resp.status_code}).")
            else:
                logger.warning(f"[UPSTREAM] Server returned non-200 code: HTTP {resp.status_code}")
        except Exception as err:
            logger.warning(f"[UPSTREAM] Could not dispatch sync to Central Server ({err}). Operating standalone.")

        # If action is an alert, also ping /api/cart/alert per schema conventions
        if action == "UNSCANNED_DROP":
            alert_url = f"{self.central_server_url}/api/cart/alert"
            alert_payload = {
                "cart_id": settings.CART_ID,
                "alert_type": "UNSCANNED_DROP",
                "message": "Unscanned physical item detected in cart basket.",
                "timestamp": round(time.time(), 3),
            }
            try:
                await self._http_client.post(alert_url, json=alert_payload)
            except Exception:
                pass

    # ==========================================================================
    # Delayed UI Helper Transitions
    # ==========================================================================

    async def _delayed_ready_prompt(self, delay_seconds: float) -> None:
        """Briefly wait after an action before updating the LCD to 'Ready: Scan Next Item'."""
        await asyncio.sleep(delay_seconds)
        async with self._lock:
            if self._state == CartState.IDLE or self._state == CartState.VERIFIED:
                self._state = CartState.IDLE
                self.lcd.show_ready_next_item()

    async def _delayed_standby_reset(self, delay_seconds: float) -> None:
        """Wait after checkout chime, then return cart to STANDBY."""
        await asyncio.sleep(delay_seconds)
        async with self._lock:
            self._state = CartState.STANDBY
            self.user_id = None
            self.pending_barcode = None
            self.lcd.show_standby()
            logger.info("[FSM] Cart returned to STANDBY mode.")

    # ==========================================================================
    # Central Server Edge Registration & Bi-Directional State Sync
    # ==========================================================================

    async def register_with_central_server(self) -> bool:
        """Register the Pi Edge Controller's Wi-Fi IP address with the Central Server."""
        local_ip = _detect_local_ip()
        url = f"{self.central_server_url}/api/cart/register-pi"
        payload = {
            "cart_id": settings.CART_ID,
            "pi_ip": local_ip,
            "ip_address": local_ip,
            "pi_port": settings.PORT,
            "port": settings.PORT,
            "status": self._state.value,
        }
        try:
            if not self._http_client:
                self._http_client = httpx.AsyncClient(timeout=3.0)
            res = await self._http_client.post(url, json=payload)
            if res.status_code == 200:
                logger.info(f"[FSM] Registered Pi Wi-Fi IP ({local_ip}:{settings.PORT}) with Central Server.")
                return True
            else:
                logger.warning(f"[FSM] Central Server register failed (HTTP {res.status_code}): {res.text}")
        except Exception as ex:
            logger.debug(f"[FSM] Central Server register attempt: {ex}")
        return False

    async def _central_server_sync_loop(self) -> None:
        """Background synchronization loop with Central Server.
        
        1. Periodically updates Pi registration on the Central Server.
        2. Polls Central Server cart status every 2.0s when in STANDBY.
           If the Central Server shows status ACTIVE (e.g. mobile app paired),
           transitions Pi to IDLE state automatically.
        """
        registered = False
        last_reg_time = 0.0

        while True:
            try:
                now = time.monotonic()
                if not registered or (now - last_reg_time > 20.0):
                    last_reg_time = now
                    registered = await self.register_with_central_server()

                # State synchronization polling
                if self._state == CartState.STANDBY:
                    url = f"{self.central_server_url}/api/cart/{settings.CART_ID}"
                    if self._http_client:
                        try:
                            resp = await self._http_client.get(url)
                            if resp.status_code == 200:
                                data = resp.json()
                                if data.get("status") == "ACTIVE" and data.get("user_id"):
                                    user_id = data.get("user_id")
                                    logger.info(
                                        f"[FSM] Detected ACTIVE session for user '{user_id}' on Central Server. "
                                        f"Syncing Pi to IDLE."
                                    )
                                    await self.on_session_paired(user_id)
                        except Exception as poll_err:
                            logger.debug(f"[FSM] Polling Central Server failed: {poll_err}")

                elif self._state == CartState.IDLE and self.user_id:
                    url = f"{self.central_server_url}/api/cart/{settings.CART_ID}"
                    if self._http_client:
                        try:
                            resp = await self._http_client.get(url)
                            if resp.status_code == 200:
                                data = resp.json()
                                if data.get("status") in ("IDLE", "STANDBY") and not data.get("user_id"):
                                    logger.info("[FSM] Central Server reset cart session. Resetting Pi to STANDBY.")
                                    async with self._lock:
                                        self._state = CartState.STANDBY
                                        self.user_id = None
                                        self.lcd.show_standby()
                        except Exception:
                            pass

                await asyncio.sleep(2.0)
            except asyncio.CancelledError:
                break
            except Exception as loop_err:
                logger.debug(f"[FSM] Central Server sync loop error: {loop_err}")
                await asyncio.sleep(3.0)

    async def _notify_central_server_auto_pair(self, user_id: str) -> None:
        """Notify Central Server if cart was auto-paired directly on the Pi via scan."""
        try:
            url = f"{self.central_server_url}/api/session/pair"
            payload = {"cart_id": settings.CART_ID, "user_id": user_id}
            if self._http_client:
                await self._http_client.post(url, json=payload)
        except Exception as ex:
            logger.debug(f"[FSM] Could not notify Central Server of auto-pair: {ex}")
