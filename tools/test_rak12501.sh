#!/bin/sh
#
# RAK12501 GNSS GPS Module Test - Check serial port connectivity and data output
# Copyright 2025, RAKwireless
#

# Detect Pi 5: primary UART is ttyAMA0; Pi 4 and earlier use ttyS0
_detect_gnss_port() {
    if [ -n "$GNSS_PORT" ]; then
        return  # User override
    fi
    if [ -r /proc/device-tree/model ]; then
        model=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null)
        case "$model" in
            *"Pi 5"*|*"Raspberry Pi 5"*) GNSS_PORT="/dev/ttyAMA0" ;;
            *) GNSS_PORT="/dev/ttyS0" ;;
        esac
    else
        GNSS_PORT="/dev/ttyS0"
    fi
}
_detect_gnss_port

# Configuration
GNSS_PORT="${GNSS_PORT:-/dev/ttyS0}"
GNSS_BAUD="${GNSS_BAUD:-9600}"
TIMEOUT="${TIMEOUT:-10}"  # Maximum wait time in seconds
MIN_LINES="${MIN_LINES:-3}"  # Minimum number of lines to receive

# Configure serial port (suppress error output for cleaner JSON mode)
stty -F ${GNSS_PORT} ${GNSS_BAUD} cs8 -cstopb -parenb raw -echo 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Error: Failed to open serial port ${GNSS_PORT}"
    exit 1
fi

# Read from serial port with timeout to verify continuous output
START_TIME=$(date +%s)
LINE_COUNT=0

while true; do
    # Check timeout
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    if [ $ELAPSED -ge $TIMEOUT ]; then
        if [ $LINE_COUNT -ge $MIN_LINES ]; then
            echo "GNSS module test passed: received ${LINE_COUNT} lines in ${ELAPSED}s"
            exit 0
        else
            echo "Error: Timeout - only received ${LINE_COUNT} lines (expected at least ${MIN_LINES})"
            exit 1
        fi
    fi
    
    # Read line with timeout (using timeout command if available)
    if command -v timeout >/dev/null 2>&1; then
        line=$(timeout 2 head -n 1 < ${GNSS_PORT} 2>/dev/null)
    else
        line=$(head -n 1 < ${GNSS_PORT} 2>/dev/null)
    fi
    
    # Check if we received data
    if [ -n "$line" ]; then
        LINE_COUNT=$((LINE_COUNT + 1))
        
        # If we have enough lines, test passed
        if [ $LINE_COUNT -ge $MIN_LINES ]; then
            echo "GNSS module test passed: received ${LINE_COUNT} lines with continuous output"
            exit 0
        fi
    fi
done

exit 1
