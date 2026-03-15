#!/bin/sh
#
# RAK12501 GNSS GPS Module Test - Direct serial port output
# Copyright 2025, RAKwireless
#

# Configuration
GNSS_PORT="${GNSS_PORT:-/dev/ttyS0}"
GNSS_BAUD="${GNSS_BAUD:-9600}"

# Configure serial port
stty -F ${GNSS_PORT} ${GNSS_BAUD} cs8 -cstopb -parenb raw -echo 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Error: Failed to open serial port ${GNSS_PORT}"
    exit 1
fi

# Read and output serial port data continuously
cat ${GNSS_PORT}