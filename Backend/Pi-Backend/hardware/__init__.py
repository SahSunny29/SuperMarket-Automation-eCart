# ==============================================================================
# Smart Shopping Cart Edge Controller - Hardware Abstraction Layer (HAL)
# ==============================================================================

"""Hardware Abstraction Layer for the Raspberry Pi 3 Model B+ Edge Controller.

Provides unified, production-ready, thread-safe hardware drivers with automatic
simulation fallbacks for non-Raspberry Pi environments:
- LCDDisplayController: 16x2 Parallel GPIO Character LCD (JHD 162A 4-bit mode).
- BuzzerController: Dual Active Buzzers wired to GPIO 17 and GPIO 27.
- BarcodeScannerDaemon: USB 1D/2D Barcode Scanner via Linux evdev HID interface.
"""

from .lcd_display import LCDDisplayController
from .buzzer_controller import BuzzerController
from .barcode_scanner import BarcodeScannerDaemon

__all__ = [
    "LCDDisplayController",
    "BuzzerController",
    "BarcodeScannerDaemon",
]
