#!/bin/sh
#
# RS485 Receiver (Script A) - Receives data via RS485 and stops when "hello" is received
# Copyright 2022, RAKwireless
#

# Configuration
RS485_PORT="${RS485_PORT:-/dev/ttyS0}"
RS485_BAUD="${RS485_BAUD:-115200}"
TIMEOUT="${TIMEOUT:-5}"  # Maximum wait time in seconds

# Configure serial port (suppress error output for cleaner JSON mode)
stty -F ${RS485_PORT} ${RS485_BAUD} cs8 -cstopb -parenb raw -echo 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Error: Failed to configure serial port ${RS485_PORT}"
    exit 1
fi

# Read from serial port with timeout
START_TIME=$(date +%s)
while true; do
    # Check timeout
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo "Error: Timeout waiting for 'hello' message (${TIMEOUT}s)"
        exit 1
    fi
    
    # Read line with timeout (using read -t for bash, or timeout command for sh)
    if command -v timeout >/dev/null 2>&1; then
        line=$(timeout 1 head -n 1 < ${RS485_PORT} 2>/dev/null)
    else
        line=$(head -n 1 < ${RS485_PORT} 2>/dev/null)
    fi
    
    if [ -n "$line" ]; then
        # Check if line contains "hello" (case insensitive)
        if echo "$line" | grep -iq "hello"; then
            echo "Hello received, test passed"
            exit 0
        fi
    fi
done

exit 1
