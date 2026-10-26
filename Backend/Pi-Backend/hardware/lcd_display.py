#!/usr/bin/env python3
# ==============================================================================
# Smart Shopping Cart Edge Controller - 16x4 Character LCD Controller
# Hardware: 16x4 Character LCD (I2C PCF8574 or 4-Bit Parallel GPIO or Virtual ASCII)
# Target Platform: Raspberry Pi 3 Model B+ / Simulation Fallback
# ==============================================================================

import logging
import threading
from typing import Any, List, Optional

logger = logging.getLogger("LCDDisplayController")


class LCDDisplayController:
    """Thread-safe controller driving a 16x4 Character LCD (PCF8574 I2C or 4-bit GPIO)
    with seamless fallback to a clean 4-row x 16-column terminal ASCII frame renderer
    when physical I2C/GPIO hardware is absent.
    """

    ROWS = 4
    COLS = 16

    # Default BCM GPIO pin assignments
    DEFAULT_PIN_RS = 25
    DEFAULT_PIN_E = 24
    DEFAULT_PINS_DATA = [23, 18, 15, 14]

    def __init__(
        self,
        pin_rs: int = DEFAULT_PIN_RS,
        pin_e: int = DEFAULT_PIN_E,
        pins_data: Optional[List[int]] = None,
        cols: int = COLS,
        rows: int = ROWS,
        simulated: Optional[bool] = None,
        i2c_address: int = 0x27,
        i2c_port: int = 1,
        **kwargs: Any,
    ):
        """Initialize the 16x4 Character LCD controller.

        Args:
            pin_rs: BCM GPIO pin for Register Select (RS).
            pin_e: BCM GPIO pin for Enable signal (E).
            pins_data: List of 4 BCM GPIO pins for [D4, D5, D6, D7].
            cols: Number of character columns (16).
            rows: Number of character rows (4).
            simulated: If True, forces console ASCII simulation. If None, auto-detects hardware.
            i2c_address: I2C hex address for PCF8574 backpack (default 0x27).
            i2c_port: I2C bus port (default 1).
        """
        self.pin_rs = pin_rs
        self.pin_e = pin_e
        self.pins_data = pins_data or list(self.DEFAULT_PINS_DATA)
        self.cols = cols
        self.rows = rows
        self.i2c_address = i2c_address
        self.i2c_port = i2c_port
        self._lock = threading.RLock()
        self._current_lines: List[str] = [" " * self.cols for _ in range(self.rows)]
        self._lcd = None
        self.simulated = False

        if simulated is True:
            self._init_simulation("Explicitly requested simulated mode.")
        else:
            self._init_hardware()

    def _init_hardware(self) -> None:
        """Attempt initialization of physical LCD hardware (first I2C PCF8574, then Parallel GPIO)."""
        # Attempt 1: PCF8574 I2C Character LCD
        try:
            import smbus2
            from RPLCD.i2c import CharLCD as I2CCharLCD

            self._lcd = I2CCharLCD(
                i2c_expander="PCF8574",
                address=self.i2c_address,
                port=self.i2c_port,
                cols=self.cols,
                rows=self.rows,
                dotsize=8,
                charmap="A00",
                auto_linebreaks=False,
            )
            self._lcd.clear()
            self.simulated = False
            logger.info(f"[LCD] Successfully initialized physical 16x4 I2C PCF8574 LCD (Address=0x{self.i2c_address:02x}, Bus={self.i2c_port}).")
            return
        except (ImportError, ModuleNotFoundError) as err:
            logger.debug(f"[LCD] I2C/smbus2 library not available ({err}). Trying GPIO fallback.")
        except (OSError, IOError, Exception) as err:
            logger.debug(f"[LCD] No I2C LCD detected at 0x{self.i2c_address:02x} ({err}). Trying GPIO fallback.")

        # Attempt 2: 4-Bit Parallel GPIO Mode
        try:
            import RPi.GPIO as GPIO
            from RPLCD.gpio import CharLCD as GPIOCharLCD

            self._lcd = GPIOCharLCD(
                pin_rs=self.pin_rs,
                pin_e=self.pin_e,
                pins_data=self.pins_data,
                numbering_mode=GPIO.BCM,
                cols=self.cols,
                rows=self.rows,
                dotsize=8,
                charmap="A00",
                auto_linebreaks=False,
            )
            self._lcd.clear()
            self.simulated = False
            logger.info(
                f"[LCD] Successfully initialized physical 16x4 Parallel GPIO LCD "
                f"(RS=GPIO{self.pin_rs}, E=GPIO{self.pin_e}, Data=GPIO{self.pins_data})."
            )
            return
        except (ImportError, ModuleNotFoundError) as err:
            self._init_simulation(f"Missing GPIO/RPLCD driver library ({err}).")
        except (RuntimeError, PermissionError, OSError) as err:
            self._init_simulation(f"Raspberry Pi GPIO/I2C hardware access unavailable ({err}).")
        except Exception as err:
            self._init_simulation(f"Unexpected error initializing physical LCD: {err}")

    def _init_simulation(self, reason: str) -> None:
        """Fallback to clean console ASCII simulation mode."""
        self.simulated = True
        self._lcd = None
        logger.info(f"[LCD SIMULATION] {reason} Falling back to virtual 16x4 console ASCII renderer.")

    @staticmethod
    def _sanitize_row(text: str, max_cols: int = COLS) -> str:
        """Format, truncate, and pad text to strictly fit 16 characters."""
        if text is None:
            text = ""
        cleaned = str(text).replace("\r", "").replace("\n", " ").strip()
        if len(cleaned) > max_cols:
            cleaned = cleaned[:max_cols]
        return cleaned.ljust(max_cols)

    def _render_ascii_frame(self) -> None:
        """Render the 16x4 display as a clean visual ASCII frame in console logs."""
        border = "+" + "-" * self.cols + "+"
        output = [
            border,
        ]
        for row in self._current_lines:
            output.append(f"|{row}|")
        output.append(border)
        tag = "[PHYSICAL LCD + TERMINAL MIRROR]" if (not self.simulated and self._lcd is not None) else "[VIRTUAL LCD PREVIEW]"
        logger.info(f"{tag}\n" + "\n".join(output))

    def write_lines(
        self,
        line1: str = "",
        line2: str = "",
        line3: str = "",
        line4: str = "",
    ) -> None:
        """Write up to 4 lines to the 16x4 Character LCD in a thread-safe manner."""
        self.write_rows([line1, line2, line3, line4])

    def write_rows(self, rows: List[str]) -> None:
        """Write rows to the LCD display in a thread-safe manner (up to 4 rows).

        Args:
            rows: List of string lines (up to 4). Missing rows are padded with blanks.
        """
        with self._lock:
            sanitized = []
            for i in range(self.rows):
                line = rows[i] if i < len(rows) else ""
                sanitized.append(self._sanitize_row(line, self.cols))

            self._current_lines = sanitized

            # If physical hardware is attached, write to real hardware
            if not self.simulated and self._lcd is not None:
                try:
                    for row_idx, line_str in enumerate(self._current_lines):
                        self._lcd.cursor_pos = (row_idx, 0)
                        self._lcd.write_string(line_str)
                except Exception as err:
                    logger.error(f"[LCD] Error writing to physical LCD: {err}. Switching to simulation.")
                    self.simulated = True

            # Always render visual LCD preview frame in console/terminal for live observability
            self._render_ascii_frame()

    def write_line(self, row_index: int, text: str) -> None:
        """Update a single row on the display (0 to rows-1)."""
        if not (0 <= row_index < self.rows):
            raise ValueError(f"Row index must be between 0 and {self.rows - 1}")

        with self._lock:
            sanitized = self._sanitize_row(text, self.cols)
            self._current_lines[row_index] = sanitized

            # If physical hardware is attached, write to real hardware
            if not self.simulated and self._lcd is not None:
                try:
                    self._lcd.cursor_pos = (row_index, 0)
                    self._lcd.write_string(sanitized)
                except Exception as err:
                    logger.error(f"[LCD] Error writing row {row_index}: {err}")
                    self.simulated = True

            # Always render visual LCD preview frame in console/terminal for live observability
            self._render_ascii_frame()

    def clear(self) -> None:
        """Clear all lines on the LCD display safely."""
        with self._lock:
            self._current_lines = [" " * self.cols for _ in range(self.rows)]
            if not self.simulated and self._lcd is not None:
                try:
                    self._lcd.clear()
                except Exception as err:
                    logger.error(f"[LCD] Error clearing hardware LCD: {err}")
                    self.simulated = True
            self._render_ascii_frame()

    def set_backlight(self, enabled: bool) -> None:
        """Control LCD backlight."""
        logger.debug(f"[LCD] Backlight state request: {enabled}")
        if not self.simulated and self._lcd is not None:
            try:
                if hasattr(self._lcd, "backlight_enabled"):
                    self._lcd.backlight_enabled = enabled
            except Exception:
                pass

    def get_lines(self) -> List[str]:
        """Return a snapshot copy of current 4 display lines."""
        with self._lock:
            return list(self._current_lines)

    def get_current_display(self) -> List[str]:
        """Alias for get_lines()."""
        return self.get_lines()

    # --------------------------------------------------------------------------
    # Dedicated 16x4 Application Flow States
    # --------------------------------------------------------------------------

    def show_standby(self, cart_id: str = "CART_01") -> None:
        """Stage 1 Standby State: Unpaired, displaying QR prompt for mobile app."""
        self.write_lines(
            "Smart Cart Ready",
            "Scan QR on App",
            "",
            f"ID: {cart_id}",
        )

    def show_cart_synced(self, cart_id: str = "CART_01") -> None:
        """Stage 1 Paired State: Displays trolley synced state upon pairing."""
        self.write_lines(
            "Cart Synced!",
            "Scan Items",
            "",
            f"Active: {cart_id}",
        )

    def show_ready_next_item(self) -> None:
        """Stage 3 Reset: Prompts shopper that system is ready for the next product."""
        self.write_lines(
            "Ready: Scan",
            "Next Item...",
            "",
            "",
        )

    def show_pending_verification(
        self,
        barcode: str,
        item_name: str = "",
        price: Optional[float] = None,
        seconds_left: int = 5,
    ) -> None:
        """Stage 2 Item Scanned / Counting Down: Item metadata and drop countdown."""
        name = item_name.strip() if item_name else "Item Scanned"
        bc_suffix = barcode[-6:] if len(barcode) >= 6 else barcode
        self.write_lines(
            name,
            f"Drop in: {seconds_left}s...",
            "Place in basket",
            f"BC: {bc_suffix}",
        )

    def show_item_added(self, item_name: str = "") -> None:
        """Stage 2 Verify Success: Displays verified item confirmation."""
        name = item_name.strip() if item_name else "Item Added!"
        self.write_lines(
            "Item Verified!",
            name,
            "Added to Cart",
            "",
        )

    def show_scan_cancelled(self) -> None:
        """Stage 2 Timeout / Cancel: Displays scan cancellation after verification window."""
        self.write_lines(
            "Scan Cancelled",
            "Item not placed",
            "Please re-scan",
            "",
        )

    def show_unscanned_alert(self) -> None:
        """Stage 2 Unscanned Alert: Anomaly detected when object placed without scan."""
        self.write_lines(
            "* SECURITY *",
            "UNSCANNED ITEM!",
            "Sync Terminated",
            "See Store Staff",
        )

    def show_checkout_complete(self) -> None:
        """Stage 4 Session Complete / Paid: Checkout authorization confirmation."""
        self.write_lines(
            "Paid! Thank You",
            "Have a nice day!",
            "Exit pass ready",
            "",
        )

    def close(self) -> None:
        """Cleanly close hardware resources."""
        with self._lock:
            if not self.simulated and self._lcd is not None:
                try:
                    self._lcd.clear()
                    self._lcd.close(clear=True)
                except Exception as err:
                    logger.warning(f"[LCD] Error closing LCD: {err}")
                finally:
                    self._lcd = None
            self.simulated = True
            logger.info("[LCD] Display controller closed.")

    def __enter__(self) -> "LCDDisplayController":
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        self.close()
