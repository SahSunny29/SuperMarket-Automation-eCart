#!/usr/bin/env python3
# ==============================================================================
# Smart Shopping Cart Edge Controller - Dual Active Buzzer Controller
# Hardware: 2x Active Buzzers connected to GPIO 17 & GPIO 27 (Raspberry Pi 3 B+)
# Trigger: Digital High (Active Buzzer emits fixed frequency ~2.5kHz on HIGH)
# Requirement: Non-blocking, thread-safe, latency <300ms compliant.
# ==============================================================================

import logging
import threading
import time
from typing import List, Optional, Tuple

logger = logging.getLogger("BuzzerController")


class BuzzerController:
    """Non-blocking, thread-safe controller driving 2x Active Buzzers in parallel.
    
    All audio patterns execute on dedicated background daemon threads so that
    main-loop sensor reconciliation is never blocked. Includes automatic hardware
    fallback to a simulation logger on non-Pi platforms.
    """

    def __init__(
        self,
        pin_buzzer1: int = 17,
        pin_buzzer2: int = 27,
        active_high: bool = True,
        simulated: Optional[bool] = None,
    ):
        """Initialize the dual buzzer controller.

        Args:
            pin_buzzer1: BCM GPIO pin for primary buzzer (default GPIO 17).
            pin_buzzer2: BCM GPIO pin for secondary buzzer (default GPIO 27).
            active_high: True if HIGH activates the buzzer, False if LOW.
            simulated: If True, forces simulation mode. If None, auto-detects hardware.
        """
        self.pin1 = pin_buzzer1
        self.pin2 = pin_buzzer2
        self.active_high = active_high
        self.simulated = False
        self._driver_type = "SIMULATION"

        self._hw_lock = threading.Lock()
        self._pattern_lock = threading.Lock()
        self._stop_event = threading.Event()
        self._alarm_event = threading.Event()
        self._worker_thread: Optional[threading.Thread] = None

        # Device handle references
        self._devices = []
        self._rpi_gpio = None

        if simulated is True:
            self._init_simulation("Explicitly requested simulated mode.")
        else:
            self._init_hardware()

    def _init_hardware(self) -> None:
        """Attempt initialization of physical GPIO hardware via gpiozero, then RPi.GPIO."""
        # Method 1: Try gpiozero (preferred modern Raspberry Pi GPIO library)
        try:
            from gpiozero import DigitalOutputDevice

            d1 = DigitalOutputDevice(self.pin1, active_high=self.active_high, initial_value=False)
            d2 = DigitalOutputDevice(self.pin2, active_high=self.active_high, initial_value=False)
            self._devices = [d1, d2]
            self._driver_type = "GPIOZERO"
            self.simulated = False
            logger.info(f"[BUZZER] Initialized via gpiozero on BCM pins {self.pin1} & {self.pin2}.")
            return
        except (ImportError, ModuleNotFoundError) as err:
            logger.debug(f"[BUZZER] gpiozero not available: {err}. Trying RPi.GPIO fallback.")
        except Exception as err:
            logger.debug(f"[BUZZER] gpiozero init failed: {err}. Trying RPi.GPIO fallback.")

        # Method 2: Try RPi.GPIO
        try:
            import RPi.GPIO as GPIO

            GPIO.setmode(GPIO.BCM)
            GPIO.setwarnings(False)
            GPIO.setup(self.pin1, GPIO.OUT, initial=GPIO.LOW if self.active_high else GPIO.HIGH)
            GPIO.setup(self.pin2, GPIO.OUT, initial=GPIO.LOW if self.active_high else GPIO.HIGH)
            self._rpi_gpio = GPIO
            self._driver_type = "RPI_GPIO"
            self.simulated = False
            logger.info(f"[BUZZER] Initialized via RPi.GPIO on BCM pins {self.pin1} & {self.pin2}.")
            return
        except (ImportError, ModuleNotFoundError) as err:
            self._init_simulation(f"Missing GPIO libraries ({err}).")
        except Exception as err:
            self._init_simulation(f"GPIO hardware access failed ({err}).")

    def _init_simulation(self, reason: str) -> None:
        """Fallback to console logger simulation mode."""
        self.simulated = True
        self._driver_type = "SIMULATION"
        logger.info(
            f"[BUZZER SIMULATION] {reason} Audio patterns will be logged to console."
        )

    # --------------------------------------------------------------------------
    # Low-level Hardware Pin Controls
    # --------------------------------------------------------------------------

    def _turn_on(self) -> None:
        """Simultaneously activate both buzzers."""
        with self._hw_lock:
            if not self.simulated:
                try:
                    if self._driver_type == "GPIOZERO":
                        for dev in self._devices:
                            dev.on()
                    elif self._driver_type == "RPI_GPIO" and self._rpi_gpio is not None:
                        val = self._rpi_gpio.HIGH if self.active_high else self._rpi_gpio.LOW
                        self._rpi_gpio.output(self.pin1, val)
                        self._rpi_gpio.output(self.pin2, val)
                except Exception as err:
                    logger.error(f"[BUZZER] Hardware activation error: {err}")

    def _turn_off(self) -> None:
        """Simultaneously deactivate both buzzers."""
        with self._hw_lock:
            if not self.simulated:
                try:
                    if self._driver_type == "GPIOZERO":
                        for dev in self._devices:
                            dev.off()
                    elif self._driver_type == "RPI_GPIO" and self._rpi_gpio is not None:
                        val = self._rpi_gpio.LOW if self.active_high else self._rpi_gpio.HIGH
                        self._rpi_gpio.output(self.pin1, val)
                        self._rpi_gpio.output(self.pin2, val)
                except Exception as err:
                    logger.error(f"[BUZZER] Hardware deactivation error: {err}")

    # --------------------------------------------------------------------------
    # Background Thread Pattern Dispatcher
    # --------------------------------------------------------------------------

    def _play_pattern_threaded(
        self,
        name: str,
        pulses: List[Tuple[float, float]],
        is_alarm: bool = False,
    ) -> None:
        """Dispatch an audio pattern to a daemon worker thread.

        Args:
            name: Human-readable name of the audio pattern.
            pulses: List of (on_duration_seconds, off_duration_seconds) tuples.
            is_alarm: If True, loops pulses continuously until stop_alarm() is called.
        """
        with self._pattern_lock:
            # Stop any non-alarm pattern currently running
            self._stop_event.set()
            if not is_alarm and self._alarm_event.is_set():
                # Active alarm has highest priority; do not interrupt with short chimes
                logger.debug(f"[BUZZER] Skipping '{name}' while continuous security alarm is active.")
                return

            if is_alarm:
                self._alarm_event.set()

            # Ensure previous thread is cleaned up
            if self._worker_thread and self._worker_thread.is_alive():
                self._worker_thread.join(timeout=0.05)

            self._stop_event.clear()

            def worker():
                try:
                    if self.simulated:
                        logger.info(f"[BUZZER SIMULATION] Sounding pattern: '{name}'")

                    while True:
                        for on_time, off_time in pulses:
                            if self._stop_event.is_set():
                                return

                            self._turn_on()
                            # Interruptible sleep during ON phase
                            end_on = time.monotonic() + on_time
                            while time.monotonic() < end_on:
                                if self._stop_event.is_set():
                                    return
                                time.sleep(0.005)

                            self._turn_off()
                            # Interruptible sleep during OFF phase
                            if off_time > 0:
                                end_off = time.monotonic() + off_time
                                while time.monotonic() < end_off:
                                    if self._stop_event.is_set():
                                        return
                                    time.sleep(0.005)

                        # If not an infinite alarm loop, break after one cycle
                        if not is_alarm or not self._alarm_event.is_set():
                            break

                finally:
                    self._turn_off()

            self._worker_thread = threading.Thread(
                target=worker,
                name=f"Buzzer-{name}",
                daemon=True,
            )
            self._worker_thread.start()

    # --------------------------------------------------------------------------
    # Dedicated MVP Audio Feedback Patterns (App_flow.md & TRD Specifications)
    # --------------------------------------------------------------------------

    def play_startup_chirp(self) -> None:
        """Stage 1 Standby Init: Single short crisp chirp (80ms)."""
        self._play_pattern_threaded("STARTUP_CHIRP", [(0.08, 0.0)])

    def play_pair_success(self) -> None:
        """Stage 1 Pairing Confirmation: Short crisp success chirp when CART_01 pairs (100ms on, 60ms off, 100ms on)."""
        self._play_pattern_threaded("PAIR_SUCCESS", [(0.10, 0.06), (0.10, 0.0)])

    def play_scan_beep(self) -> None:
        """Stage 2 Scan Acknowledgment: Single short confirmation beep when barcode scanned (60ms)."""
        self._play_pattern_threaded("SCAN_BEEP", [(0.06, 0.0)])

    def play_verified_double_beep(self) -> None:
        """Stage 2 Resolution (Match): Double-beep pattern when scan + drop reconciliation succeeds (80ms on, 60ms off, 80ms on)."""
        self._play_pattern_threaded("VERIFIED_DOUBLE_BEEP", [(0.08, 0.06), (0.08, 0.0)])

    def play_timeout_error_tone(self) -> None:
        """Stage 2 Resolution (Timeout): Low/long error tone when 5.0s window expires without drop (600ms continuous)."""
        self._play_pattern_threaded("TIMEOUT_ERROR", [(0.60, 0.0)])

    def start_unscanned_alarm(self) -> None:
        """Stage 2 Resolution (Anomaly): Continuous pulsing alarm on UNSCANNED_DROP until stop_alarm() is called.
        
        Pulses 150ms ON, 150ms OFF indefinitely.
        """
        self._play_pattern_threaded(
            "UNSCANNED_DROP_ALARM",
            [(0.15, 0.15)],
            is_alarm=True,
        )

    def stop_alarm(self) -> None:
        """Stop any active continuous alarm or pattern immediately and silence buzzers."""
        with self._pattern_lock:
            self._alarm_event.clear()
            self._stop_event.set()
            if self._worker_thread and self._worker_thread.is_alive():
                self._worker_thread.join(timeout=0.1)
            self._turn_off()
            logger.info("[BUZZER] Alarm silenced and buzzers turned off.")

    def play_checkout_chime(self) -> None:
        """Stage 4 Checkout Complete: Final multi-note celebratory success chime (80ms, 80ms, 250ms)."""
        self._play_pattern_threaded(
            "CHECKOUT_CHIME",
            [(0.08, 0.05), (0.08, 0.05), (0.25, 0.0)],
        )

    # --------------------------------------------------------------------------
    # Lifecycle Management
    # --------------------------------------------------------------------------

    def cleanup(self) -> None:
        """Cleanly terminate worker threads and release GPIO hardware resources."""
        self.stop_alarm()
        with self._hw_lock:
            try:
                if self._driver_type == "GPIOZERO":
                    for dev in self._devices:
                        dev.close()
                    self._devices.clear()
                elif self._driver_type == "RPI_GPIO" and self._rpi_gpio is not None:
                    self._rpi_gpio.cleanup([self.pin1, self.pin2])
                    self._rpi_gpio = None
            except Exception as err:
                logger.warning(f"[BUZZER] Error cleaning up GPIO: {err}")
            finally:
                self.simulated = True
                logger.info("[BUZZER] Controller cleaned up.")

    def __enter__(self) -> "BuzzerController":
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        self.cleanup()
