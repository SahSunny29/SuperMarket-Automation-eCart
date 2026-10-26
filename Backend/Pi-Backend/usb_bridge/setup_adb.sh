#!/usr/bin/env bash
# ==============================================================================
# Smart Shopping Cart Edge Controller - USB ADB Reverse Tunnel & Bridge Setup
# Target Hardware: Raspberry Pi 3 Model B+ (Raspbian GNU/Linux / Debian)
# Connected Hardware: 2x Android Smartphones (CAM_LEFT, CAM_RIGHT)
#
# Purpose:
#   Configures ADB reverse port forwarding (tcp:5000 -> tcp:5000) over physical
#   USB cables so mounted camera phones can access the Pi's local web server
#   (YOLOv8 browser vision runtime) at http://localhost:5000 and post CROSS_IN
#   sensor events with sub-millisecond USB bus latency.
# ==============================================================================

set -eo pipefail

# ANSI Color Codes for structured terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration Constants
TARGET_PORT="${1:-${PORT:-5000}}"
EXPECTED_PHONE_COUNT=2

log_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

log_info() {
    echo -e "${BLUE}[$(log_timestamp)] [INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(log_timestamp)] [SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(log_timestamp)] [WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(log_timestamp)] [ERROR]${NC} $1" >&2
}

echo -e "${CYAN}==================================================================${NC}"
echo -e "${CYAN}   Smart Shopping Cart - USB Bridge & ADB Port Forwarding Init    ${NC}"
echo -e "${CYAN}==================================================================${NC}"

# Step 1: Verify ADB availability on the host system
log_info "Verifying Android Debug Bridge (adb) binary installation..."
if ! command -v adb >/dev/null 2>&1; then
    log_error "Android Debug Bridge ('adb') executable not found in PATH."
    log_error "Please install ADB on the Raspberry Pi via:"
    log_error "    sudo apt-get update && sudo apt-get install -y android-tools-adb"
    exit 1
fi
ADB_BIN=$(command -v adb)
log_success "ADB binary located at: ${ADB_BIN}"

# Step 2: Ensure ADB daemon server is running
log_info "Starting ADB server daemon..."
if adb start-server >/dev/null 2>&1; then
    log_success "ADB server started successfully."
else
    log_warn "ADB server start-server returned non-zero code. Attempting restart..."
    adb kill-server >/dev/null 2>&1 || true
    sleep 1
    adb start-server
    log_success "ADB server daemon restarted."
fi

# Step 3: Check for unauthorized or offline devices
UNAUTHORIZED_DEVICES=$(adb devices | awk '$2=="unauthorized" {print $1}')
OFFLINE_DEVICES=$(adb devices | awk '$2=="offline" {print $1}')

if [ -n "$UNAUTHORIZED_DEVICES" ]; then
    log_warn "Detected unauthorized device(s):"
    for dev in $UNAUTHORIZED_DEVICES; do
        log_warn "  -> Serial: ${dev} (Please accept the 'Allow USB debugging' prompt on the phone screen)"
    done
fi

if [ -n "$OFFLINE_DEVICES" ]; then
    log_warn "Detected offline device(s):"
    for dev in $OFFLINE_DEVICES; do
        log_warn "  -> Serial: ${dev} (Check USB cable connection or re-plug)"
    done
fi

# Step 4: Enumerate all connected USB Android devices in 'device' state
CONNECTED_DEVICES=$(adb devices | awk 'NR>1 && $2=="device" {print $1}')
DEVICE_COUNT=0

if [ -n "$CONNECTED_DEVICES" ]; then
    DEVICE_COUNT=$(echo "$CONNECTED_DEVICES" | grep -v '^$' | wc -l | tr -d ' ')
fi

log_info "Found ${DEVICE_COUNT} authorized Android device(s) connected over USB."

if [ "$DEVICE_COUNT" -eq 0 ]; then
    log_warn "No authorized Android devices detected over USB."
    log_info "Edge Controller will operate in HYBRID auto-verification mode (or single Wi-Fi phone mode)."
fi

# Step 5: Execute reverse port forwarding for each detected phone (0, 1, or 2)
FORWARD_SUCCESS_COUNT=0

if [ "$DEVICE_COUNT" -gt 0 ]; then
    for SERIAL in $CONNECTED_DEVICES; do
        log_info "Configuring ADB reverse socket tunnel on device [${SERIAL}] -> tcp:${TARGET_PORT}..."
        
        # Remove any existing reverse mappings on this port first
        adb -s "${SERIAL}" reverse --remove "tcp:${TARGET_PORT}" >/dev/null 2>&1 || true

        if adb -s "${SERIAL}" reverse "tcp:${TARGET_PORT}" "tcp:${TARGET_PORT}"; then
            log_success "Device [${SERIAL}]: Reversed tcp:${TARGET_PORT} -> tcp:${TARGET_PORT} successfully."
            FORWARD_SUCCESS_COUNT=$((FORWARD_SUCCESS_COUNT + 1))
        else
            log_warn "Device [${SERIAL}]: Failed to reverse port tcp:${TARGET_PORT}."
        fi
    done
fi

# Step 6: Verify active reversed sockets via adb reverse --list
if [ "$DEVICE_COUNT" -gt 0 ]; then
    log_info "Current active ADB reverse socket mappings:"
    for SERIAL in $CONNECTED_DEVICES; do
        echo -e "${CYAN}Device [${SERIAL}] mappings:${NC}"
        adb -s "${SERIAL}" reverse --list 2>/dev/null || echo "  (None)"
    done
fi

# Step 7: Inspect USB tethering network interfaces (usb0, usb1) as secondary transport check
log_info "Checking secondary transport layer: USB Tethering interfaces (usb0, usb1)..."
if command -v ip >/dev/null 2>&1; then
    ACTIVE_USB_INTERFACES=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -E '^usb[0-9]+' || true)
    
    if [ -n "$ACTIVE_USB_INTERFACES" ]; then
        for iface in $ACTIVE_USB_INTERFACES; do
            IPV4_ADDR=$(ip -o -4 addr show dev "$iface" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 || true)
            IFACE_STATE=$(cat "/sys/class/net/${iface}/operstate" 2>/dev/null || echo "unknown")
            if [ -n "$IPV4_ADDR" ]; then
                log_success "USB Network Interface [${iface}] is UP (${IFACE_STATE}) with assigned IPv4: ${IPV4_ADDR}"
            else
                log_warn "USB Network Interface [${iface}] is present (${IFACE_STATE}) but has no IPv4 lease assigned."
            fi
        done
    else
        log_info "No physical 'usbX' network interfaces found."
    fi
else
    log_warn "'ip' command not found. Skipping USB tethering interface checks."
fi

# Step 8: Final validation against hardware configuration (0, 1, or 2 cameras)
echo -e "${CYAN}------------------------------------------------------------------${NC}"
if [ "$FORWARD_SUCCESS_COUNT" -ge "$EXPECTED_PHONE_COUNT" ]; then
    log_success "All ${FORWARD_SUCCESS_COUNT}/${EXPECTED_PHONE_COUNT} camera phones (CAM_LEFT & CAM_RIGHT) successfully tunneled on tcp:${TARGET_PORT}."
    exit 0
elif [ "$FORWARD_SUCCESS_COUNT" -gt 0 ]; then
    log_warn "Single-camera mode active: ${FORWARD_SUCCESS_COUNT} phone(s) tunneled on tcp:${TARGET_PORT}."
    exit 0
else
    log_info "Zero USB phones tunneled. System ready in Wi-Fi / Hybrid vision fallback mode."
    exit 0
fi
