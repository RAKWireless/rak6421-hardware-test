#!/bin/bash
#
# RS485 Sender (Script B) - Continuously sends "hello" via RS485
# Copyright 2022, RAKwireless
#

# Configuration
RS485_PORT="/dev/ttyUSB0"
RS485_BAUD=115200

echo "RS485 Sender started on ${RS485_PORT} at ${RS485_BAUD} baud"
echo "Sending 'hello' continuously... Press Ctrl+C to stop"

# Configure serial port
stty -F ${RS485_PORT} ${RS485_BAUD} cs8 -cstopb -parenb raw -echo

# Send hello continuously
counter=0
while true; do
    counter=$((counter + 1))
    echo "hello" > ${RS485_PORT}
    echo "[${counter}] Sent: hello"
    sleep 1
done
