#!/usr/bin/env python3
# ==============================================================================
# Smart Shopping Cart Edge Controller - USB Barcode Scanner Async Daemon
# Hardware: Fixed-mount USB 1D/2D Optical Barcode Scanner (USB HID Keyboard Mode)
# Protocol: Linux evdev (/dev/input/event*) asynchronous event loop
# ==============================================================================

import asyncio
import logging
import sys
from typing import Any, Callable, Dict, Optional

logger = logging.getLogger("BarcodeScannerDaemon")

# Scancode-to-character translation mapping for standard USB HID keyboards
# Key: evdev key name or code -> (unshifted_char, shifted_char)
KEY_MAP: Dict[str, tuple] = {
    # Number Row
    "KEY_0": ("0", ")"),
    "KEY_1": ("1", "!"),
    "KEY_2": ("2", "@"),
    "KEY_3": ("3", "#"),
    "KEY_4": ("4", "$"),
    "KEY_5": ("5", "%"),
    "KEY_6": ("6", "^"),
    "KEY_7": ("7", "&"),
    "KEY_8": ("8", "*"),
    "KEY_9": ("9", "("),
    # Letters (Scanners emit standard uppercase/lowercase ASCII)
    "KEY_A": ("a", "A"),
    "KEY_B": ("b", "B"),
    "KEY_C": ("c", "C"),
    "KEY_D": ("d", "D"),
    "KEY_E": ("e", "E"),
    "KEY_F": ("f", "F"),
    "KEY_G": ("g", "G"),
    "KEY_H": ("h", "H"),
    "KEY_I": ("i", "I"),
    "KEY_J": ("j", "J"),
    "KEY_K": ("k", "K"),
    "KEY_L": ("l", "L"),
    "KEY_M": ("m", "M"),
    "KEY_N": ("n", "N"),
    "KEY_O": ("o", "O"),
    "KEY_P": ("p", "P"),
    "KEY_Q": ("q", "Q"),
    "KEY_R": ("r", "R"),
    "KEY_S": ("s", "S"),
    "KEY_T": ("t", "T"),
    "KEY_U": ("u", "U"),
    "KEY_V": ("v", "V"),
    "KEY_W": ("w", "W"),
    "KEY_X": ("x", "X"),
    "KEY_Y": ("y", "Y"),
    "KEY_Z": ("z", "Z"),
    # Punctuation & Symbols
    "KEY_MINUS": ("-", "_"),
    "KEY_EQUAL": ("=", "+"),
    "KEY_LEFTBRACE": ("[", "{"),
    "KEY_RIGHTBRACE": ("]", "}"),
    "KEY_SEMICOLON": (";", ":"),
    "KEY_APOSTROPHE": ("'", '"'),
    "KEY_GRAVE": ("`", "~"),
    "KEY_BACKSLASH": ("\\", "|"),
    "KEY_COMMA": (",", "<"),
    "KEY_DOT": (".", ">"),
    "KEY_SLASH": ("/", "?"),
    "KEY_SPACE": (" ", " "),
    # Keypad
    "KEY_KP0": ("0", "0"),
    "KEY_KP1": ("1", "1"),
    "KEY_KP2": ("2", "2"),
    "KEY_KP3": ("3", "3"),
    "KEY_KP4": ("4", "4"),
    "KEY_KP5": ("5", "5"),
    "KEY_KP6": ("6", "6"),
    "KEY_KP7": ("7", "7"),
    "KEY_KP8": ("8", "8"),
    "KEY_KP9": ("9", "9"),
    "KEY_KPDOT": (".", "."),
    "KEY_KPSLASH": ("/", "/"),
    "KEY_KPASTERISK": ("*", "*"),
    "KEY_KPMINUS": ("-", "-"),
    "KEY_KPPLUS": ("+", "+"),
}


class BarcodeScannerDaemon:
    """Asynchronous daemon that listens for barcode scan events via USB HID evdev interface.
    
    Translates raw Linux input scancodes to ASCII strings until KEY_ENTER is observed,
    sanitizes the barcode, and invokes the configured callback. Falls back automatically
    to simulation mode with programmatic and stdin injection capabilities.
    """

    MAX_BUFFER_LENGTH = 1024

    def __init__(
        self,
        device_path: Optional[str] = None,
        on_barcode_scanned: Optional[Callable[[str], Any]] = None,
        grab_device: bool = True,
        simulated: Optional[bool] = None,
    ):
        """Initialize the barcode scanner daemon.

        Args:
            device_path: Optional explicit path to /dev/input/eventX. If None, auto-detected.
            on_barcode_scanned: Sync or async callable invoked with the sanitized barcode string.
            grab_device: If True, grabs the Linux input device exclusively (prevents console spill).
            simulated: If True, forces simulation mode. If None, auto-detects hardware.
        """
        self.device_path = device_path
        self.callback = on_barcode_scanned
        self.grab_device = grab_device
        self.simulated = False
        self._device = None
        self._running = False
        self._task: Optional[asyncio.Task] = None
        self._buffer: list = []
        self._shift_pressed = False

        if simulated is True:
            self._init_simulation("Explicitly requested simulation mode.")
        else:
            self._init_device()

    def _init_device(self) -> None:
        """Attempt discovery and opening of the USB evdev scanner device."""
        try:
            import evdev

            target_path = self.device_path
            if not target_path:
                target_path = self._auto_detect_scanner(evdev)

            if target_path:
                self.device_path = target_path
                self._device = evdev.InputDevice(target_path)
                logger.info(
                    f"[SCANNER READY] Connected to physical USB Barcode Scanner at {target_path} "
                    f"('{self._device.name}', phys={self._device.phys})."
                )
                self.simulated = False
            else:
                self._init_simulation("No USB Barcode Scanner device detected in /dev/input/.")

        except (ImportError, ModuleNotFoundError) as err:
            self._init_simulation(f"evdev library unavailable on host platform ({err}).")
        except (FileNotFoundError, PermissionError, OSError) as err:
            self._init_simulation(f"Unable to access input device ({err}).")
        except Exception as err:
            self._init_simulation(f"Unexpected error initializing scanner device: {err}")

    def _init_simulation(self, reason: str) -> None:
        """Configure simulation fallback mode."""
        self.simulated = True
        self._device = None
        logger.info(
            f"[SCANNER READY] Simulation mode active: {reason}. Barcode scans can be injected via inject_barcode() or stdin."
        )

    @staticmethod
    def _auto_detect_scanner(evdev_module) -> Optional[str]:
        """Scan available /dev/input/event* devices for barcode scanner characteristics."""
        devices = [evdev_module.InputDevice(path) for path in evdev_module.list_devices()]
        if not devices:
            return None

        # Priority 1: Device explicitly identifying as a scanner/barcode reader
        scanner_keywords = [
            "scanner", "barcode", "honeywell", "zebra", "symbol",
            "datalogic", "eyoyo", "netum", "tera", "inateck"
        ]
        for dev in devices:
            name_lower = dev.name.lower()
            if any(k in name_lower for k in scanner_keywords):
                logger.info(f"[SCANNER] Found dedicated scanner candidate: {dev.path} ({dev.name})")
                return dev.path

        # Priority 2: Generic USB HID keyboard device (scanners often register as HID Keyboard)
        for dev in devices:
            name_lower = dev.name.lower()
            caps = dev.capabilities()
            if evdev_module.ecodes.EV_KEY in caps:
                keys = caps[evdev_module.ecodes.EV_KEY]
                # Verify standard alphanumeric capabilities
                if evdev_module.ecodes.KEY_0 in keys and evdev_module.ecodes.KEY_ENTER in keys:
                    # Ignore internal power/lid/sleep buttons
                    if not any(ign in name_lower for ign in ["power", "sleep", "button", "switch"]):
                        logger.info(f"[SCANNER] Found compatible USB HID keyboard input: {dev.path} ({dev.name})")
                        return dev.path

        return None

    def set_callback(self, callback: Callable[[str], Any]) -> None:
        """Register or replace the scan event callback."""
        self.callback = callback

    async def _dispatch_barcode(self, barcode: str) -> None:
        """Sanitize and trigger the registered callback with the scanned barcode."""
        sanitized = barcode.strip()
        if not sanitized:
            return

        logger.info(f"[SCANNER SCANNED] Physical/Injected barcode: '{sanitized}' (length={len(sanitized)}). Dispatching to FSM...")

        if self.callback:
            try:
                if asyncio.iscoroutinefunction(self.callback):
                    await self.callback(sanitized)
                else:
                    self.callback(sanitized)
            except Exception as err:
                logger.error(f"[SCANNER] Error executing scan callback: {err}", exc_info=True)

    async def inject_barcode(self, barcode: str) -> None:
        """Programmatically inject a barcode scan (used for testing, simulation, or API triggers)."""
        logger.info(f"[SCANNER INJECT] Injected barcode: '{barcode}'")
        await self._dispatch_barcode(barcode)

    async def _read_hardware_loop(self) -> None:
        """Asynchronously read events from the physical Linux evdev device."""
        import evdev
        from evdev import ecodes

        if self.grab_device and self._device:
            try:
                self._device.grab()
                logger.info(f"[SCANNER] Exclusively grabbed device {self.device_path}.")
            except Exception as err:
                logger.warning(f"[SCANNER] Could not grab device exclusively: {err}")

        try:
            async for event in self._device.async_read_loop():
                if not self._running:
                    break

                if event.type != ecodes.EV_KEY:
                    continue

                # event.value: 0=UP, 1=DOWN, 2=HOLD
                key_name = ecodes.KEY[event.code] if event.code in ecodes.KEY else f"KEY_{event.code}"

                # Track Shift state
                if key_name in ("KEY_LEFTSHIFT", "KEY_RIGHTSHIFT"):
                    self._shift_pressed = (event.value in (1, 2))
                    continue

                # We only process key-down (1) or repeat (2)
                if event.value not in (1, 2):
                    continue

                # Enter signifies end of barcode scan payload
                if key_name in ("KEY_ENTER", "KEY_KPENTER"):
                    barcode_str = "".join(self._buffer)
                    self._buffer.clear()
                    await self._dispatch_barcode(barcode_str)
                    continue

                # Handle character translation
                if key_name in KEY_MAP:
                    unshifted, shifted = KEY_MAP[key_name]
                    char = shifted if self._shift_pressed else unshifted
                    self._buffer.append(char)

                    # Guard against runaway memory consumption
                    if len(self._buffer) > self.MAX_BUFFER_LENGTH:
                        logger.warning("[SCANNER] Buffer exceeded max length without Enter. Clearing.")
                        self._buffer.clear()

        except asyncio.CancelledError:
            logger.debug("[SCANNER] Read loop cancelled.")
        except Exception as err:
            logger.error(f"[SCANNER] Error reading evdev events: {err}", exc_info=True)
        finally:
            if self.grab_device and self._device:
                try:
                    self._device.ungrab()
                except Exception:
                    pass

    async def _read_stdin_loop(self) -> None:
        """Read barcode entries asynchronously from standard input (simulation mode)."""
        loop = asyncio.get_running_loop()
        logger.info("[SCANNER SIMULATION] Stdin listener started. Type barcode and press Enter:")

        while self._running:
            try:
                line = await loop.run_in_executor(None, sys.stdin.readline)
                if not line:
                    await asyncio.sleep(0.5)
                    continue
                await self._dispatch_barcode(line.strip())
            except asyncio.CancelledError:
                break
            except Exception as err:
                logger.error(f"[SCANNER SIMULATION] Stdin read error: {err}")
                break

    async def start(self, enable_stdin_simulation: bool = False) -> None:
        """Start the background scanner daemon.

        Args:
            enable_stdin_simulation: If True and in simulation mode, starts a background
                                     task listening to standard input.
        """
        if self._running:
            return

        self._running = True

        if not self.simulated and self._device is not None:
            self._task = asyncio.create_task(self._read_hardware_loop(), name="ScannerHardwareLoop")
            logger.info(f"[SCANNER LISTENING] Actively monitoring {self.device_path} ('{self._device.name}') for physical USB scans.")
        elif enable_stdin_simulation:
            self._task = asyncio.create_task(self._read_stdin_loop(), name="ScannerStdinLoop")
            logger.info("[SCANNER LISTENING] Interactive stdin listener active. Type barcode and press Enter.")
        else:
            logger.info("[SCANNER READY] Daemon ready for programmatic/API barcode injections.")

    async def stop(self) -> None:
        """Stop the background listener and clean up device handles."""
        self._running = False
        if self._task and not self._task.done():
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
            self._task = None

        if self._device is not None:
            try:
                self._device.close()
            except Exception:
                pass
            self._device = None

        logger.info("[SCANNER] Barcode scanner daemon stopped.")

    async def __aenter__(self) -> "BarcodeScannerDaemon":
        await self.start()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb) -> None:
        await self.stop()
