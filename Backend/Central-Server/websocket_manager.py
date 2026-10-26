#!/usr/bin/env python3
"""
Central Store Server - Real-Time WebSocket Connection Manager
Maintains separate broadcast rooms for:
1. Active shopping carts (/ws/cart/{cart_id}) for Buyer's Flutter application.
2. Global admin monitor (/ws/admin) for Store Manager's Dashboard.
Implements resilient auto-cleanup of dead/dropped client connections.
"""

import asyncio
import logging
from typing import Dict, Set, Any
from fastapi import WebSocket

logger = logging.getLogger("CentralServer.WebSocketManager")


class ConnectionManager:
    """Thread-safe, asynchronous WebSocket connection and broadcast router."""

    def __init__(self):
        # Maps cart_id -> Set of active client WebSocket connections (Flutter app)
        self._cart_rooms: Dict[str, Set[WebSocket]] = {}
        # Maps cart_id -> Set of active Raspberry Pi edge controller WebSockets
        self._pi_connections: Dict[str, Set[WebSocket]] = {}
        # Set of active store administration WebSockets
        self._admin_connections: Set[WebSocket] = set()
        self._lock = asyncio.Lock()

    # ==========================================================================
    # Pi Connection Management (/ws/pi/{cart_id})
    # ==========================================================================

    async def connect_pi(self, websocket: WebSocket, cart_id: str) -> None:
        """Accept incoming connection and register Raspberry Pi edge controller."""
        await websocket.accept()
        async with self._lock:
            if cart_id not in self._pi_connections:
                self._pi_connections[cart_id] = set()
            self._pi_connections[cart_id].add(websocket)
            total = len(self._pi_connections[cart_id])
        logger.info(f"[WS] Raspberry Pi connected for cart '{cart_id}' ({total} active).")

    async def disconnect_pi(self, websocket: WebSocket, cart_id: str) -> None:
        """Unsubscribe and clean up Pi WebSocket connection."""
        async with self._lock:
            if cart_id in self._pi_connections:
                self._pi_connections[cart_id].discard(websocket)
                if not self._pi_connections[cart_id]:
                    del self._pi_connections[cart_id]
        logger.info(f"[WS] Raspberry Pi disconnected for cart '{cart_id}'.")

    async def send_to_pi(self, cart_id: str, payload: Dict[str, Any]) -> bool:
        """Send command directly to connected Raspberry Pi edge controller."""
        async with self._lock:
            targets = list(self._pi_connections.get(cart_id, []))

        if not targets:
            logger.debug(f"[WS] No active Pi WebSocket connection for cart '{cart_id}'.")
            return False

        delivered = False
        dead_sockets = []
        for ws in targets:
            try:
                await ws.send_json(payload)
                delivered = True
            except Exception as e:
                logger.warning(f"[WS] Failed to send payload to Pi '{cart_id}' ({e}); marking for removal.")
                dead_sockets.append(ws)

        if dead_sockets:
            async with self._lock:
                if cart_id in self._pi_connections:
                    for dead in dead_sockets:
                        self._pi_connections[cart_id].discard(dead)
                    if not self._pi_connections[cart_id]:
                        del self._pi_connections[cart_id]

        return delivered

    async def broadcast_to_pi(self, cart_id: str, payload: Dict[str, Any]) -> None:
        """Alias for send_to_pi."""
        await self.send_to_pi(cart_id, payload)

    # ==========================================================================
    # Cart Room Management (/ws/cart/{cart_id})
    # ==========================================================================

    async def connect_cart(self, websocket: WebSocket, cart_id: str) -> None:
        """Accept incoming connection and subscribe to cart room."""
        await websocket.accept()
        async with self._lock:
            if cart_id not in self._cart_rooms:
                self._cart_rooms[cart_id] = set()
            self._cart_rooms[cart_id].add(websocket)
            room_size = len(self._cart_rooms[cart_id])

        logger.info(f"[WS] Client subscribed to cart '{cart_id}' room ({room_size} active).")

    async def disconnect_cart(self, websocket: WebSocket, cart_id: str) -> None:
        """Unsubscribe and close connection cleanly."""
        async with self._lock:
            if cart_id in self._cart_rooms:
                self._cart_rooms[cart_id].discard(websocket)
                if not self._cart_rooms[cart_id]:
                    del self._cart_rooms[cart_id]
                logger.info(f"[WS] Client disconnected from cart '{cart_id}'.")

    async def broadcast_to_cart(self, cart_id: str, payload: Dict[str, Any]) -> None:
        """Broadcast JSON payload to all active clients subscribed to a specific cart."""
        async with self._lock:
            targets = list(self._cart_rooms.get(cart_id, []))

        if not targets:
            logger.debug(f"[WS] No active subscribers for cart '{cart_id}' to receive payload.")
            return

        dead_sockets = []
        for ws in targets:
            try:
                await ws.send_json(payload)
            except Exception as e:
                logger.warning(f"[WS] Failed to send to cart client ({e}); marking for removal.")
                dead_sockets.append(ws)

        if dead_sockets:
            async with self._lock:
                if cart_id in self._cart_rooms:
                    for dead in dead_sockets:
                        self._cart_rooms[cart_id].discard(dead)
                    if not self._cart_rooms[cart_id]:
                        del self._cart_rooms[cart_id]

    # ==========================================================================
    # Admin Room Management (/ws/admin)
    # ==========================================================================

    async def connect_admin(self, websocket: WebSocket) -> None:
        """Accept incoming connection and subscribe to global admin telemetry."""
        await websocket.accept()
        async with self._lock:
            self._admin_connections.add(websocket)
            total_admins = len(self._admin_connections)

        logger.info(f"[WS] Admin dashboard connected ({total_admins} active admin sockets).")

    async def disconnect_admin(self, websocket: WebSocket) -> None:
        """Unsubscribe admin dashboard connection."""
        async with self._lock:
            self._admin_connections.discard(websocket)
            logger.info("[WS] Admin dashboard disconnected.")

    async def broadcast_to_admin(self, payload: Dict[str, Any]) -> None:
        """Broadcast JSON event payload to all connected admin dashboards."""
        async with self._lock:
            targets = list(self._admin_connections)

        if not targets:
            return

        dead_sockets = []
        for ws in targets:
            try:
                await ws.send_json(payload)
            except Exception as e:
                logger.warning(f"[WS] Failed to send to admin socket ({e}); marking for removal.")
                dead_sockets.append(ws)

        if dead_sockets:
            async with self._lock:
                for dead in dead_sockets:
                    self._admin_connections.discard(dead)

    # ==========================================================================
    # Global Broadcast Utilities
    # ==========================================================================

    async def broadcast_to_all(self, payload: Dict[str, Any]) -> None:
        """Broadcast payload to all admin dashboards and all cart rooms."""
        await self.broadcast_to_admin(payload)
        async with self._lock:
            cart_ids = list(self._cart_rooms.keys())

        for cid in cart_ids:
            await self.broadcast_to_cart(cid, payload)

    def get_stats(self) -> Dict[str, Any]:
        """Return snapshot of active WebSocket connection counts."""
        return {
            "total_admin_connections": len(self._admin_connections),
            "active_cart_rooms": len(self._cart_rooms),
            "active_pi_connections": {cid: len(sockets) for cid, sockets in self._pi_connections.items()},
            "cart_rooms": {cid: len(sockets) for cid, sockets in self._cart_rooms.items()},
        }


# Global Singleton Instance
manager = ConnectionManager()
