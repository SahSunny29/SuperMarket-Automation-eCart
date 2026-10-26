#!/usr/bin/env python3
# ==============================================================================
# Smart Shopping Cart Edge Controller - Configuration Management
# Target: Raspberry Pi 3 Model B+ (Edge Controller)
# ==============================================================================

import os
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Centralized, environment-overridable configuration settings for the Pi Edge Controller."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Cart Identity
    CART_ID: str = "CART_01"

    # Local Pi Web Server Host & Port
    PI_HOST: str = "0.0.0.0"
    PI_PORT: int = 5000

    # Laptop Central Server Base URL (Receives verified ADD_ITEM & alerts)
    # Current Laptop Wi-Fi IP address: 10.138.30.169
    CENTRAL_SERVER_URL: str = "http://10.138.30.169:8000"
    CENTRAL_WS_URL: Optional[str] = None

    @property
    def central_ws_endpoint(self) -> str:
        """Returns the WebSocket URL for the Central Server Pi room."""
        if self.CENTRAL_WS_URL:
            return self.CENTRAL_WS_URL
        base = self.CENTRAL_SERVER_URL.rstrip("/").replace("http://", "ws://").replace("https://", "wss://")
        return f"{base}/ws/pi/{self.CART_ID}"

    # Developer convenience flag: Auto-pair cart if barcode scanned in STANDBY mode
    ALLOW_BARCODE_AUTO_PAIR: bool = True

    # Vision & Camera Verification Mode:
    # "HYBRID" = Wait for camera CROSS_IN if >= 1 camera node connected; auto-verify in 1.5s if 0 cameras connected
    # "CAMERA" = Strictly wait 5.0s for camera node CROSS_IN
    # "AUTO"   = Always auto-verify without camera
    VISION_MODE: str = "HYBRID"
    AUTO_VERIFY_WHEN_NO_CAMERA: bool = True
    NO_CAMERA_AUTO_VERIFY_DELAY_SEC: float = 1.5

    # Sensor Fusion Timing Thresholds
    VERIFICATION_WINDOW_SEC: float = 5.0
    CAMERA_DEBOUNCE_MS: int = 500  # Merges CAM_LEFT & CAM_RIGHT triggers within 500ms

    # 16x4 Character LCD (PCF8574 I2C / 4-bit Parallel / Virtual ASCII Frame Fallback)
    LCD_COLS: int = 16
    LCD_ROWS: int = 4
    LCD_SIMULATION_MODE: bool = False
    LCD_PIN_RS: int = 25       # LCD Pin 4 (RS) -> Raspberry Pi GPIO 25 (Physical Pin 22)
    LCD_PIN_E: int = 24        # LCD Pin 6 (E)  -> Raspberry Pi GPIO 24 (Physical Pin 18)
    LCD_PINS_DATA: list[int] = [23, 18, 15, 14]  # D4->GPIO 23, D5->GPIO 18, D6->GPIO 15, D7->GPIO 14

    # I2C PCF8574 Backpack Attributes (Optional)
    I2C_ADDRESS: int = 0x27
    I2C_PORT: int = 1

    # Dual Active Buzzers (Connected to GPIO 17 & GPIO 27)
    BUZZER_PIN_1: int = 17
    BUZZER_PIN_2: int = 27

    # USB Barcode Scanner (/dev/input/eventX path or auto-detect if None)
    BARCODE_DEVICE_PATH: Optional[str] = None

    # Hardware Simulation Flag: If True, forces console simulation. If None, auto-detects.
    SIMULATED_HARDWARE: Optional[bool] = None

    # Logging and Diagnostics
    DEBUG: bool = True


# Global Singleton Instance
settings = Settings()
