#!/bin/sh

# -----------------------------------------------------------------------------
# RAK5801 4-20mA Interface Test Script
# This module converts 4-20mA sensor signals to voltage that can be read by ADC
# -----------------------------------------------------------------------------

# Arguments
ENABLE_PIN=${ENABLE_PIN:-17}  # GPIO pin for Slot#1
SAMPLE_NUM=${SAMPLE_NUM:-1}   # Number of samples
THRESHOLD=1.5                  # Voltage threshold (V)

# Get script directory
DIR=$( cd "$( dirname "$0" )" && pwd )

# Enable RAK5801 via GPIO
gpioset gpiochip0 ${ENABLE_PIN}=1 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Error: Failed to enable GPIO ${ENABLE_PIN}"
    exit 1
fi

# Small delay to allow sensor to stabilize
sleep 0.1

# Read ADC value using ads1115
OUTPUT=$($DIR/ads1115 -e shot --times=${SAMPLE_NUM} --addr=GND --channel=AIN1_GND 2>&1)
RESULT=$?

# Disable GPIO
gpioset gpiochip0 ${ENABLE_PIN}=0 2>/dev/null

# Check if ads1115 command succeeded
if [ $RESULT -ne 0 ]; then
    echo "Error: ADC read failed"
    exit 1
fi

# Extract voltage value from output (format: "ads1115: adc is 2.0078V.")
VOLTAGE=$(echo "$OUTPUT" | grep "adc is" | sed 's/.*adc is \([0-9.]*\)V.*/\1/')

if [ -z "$VOLTAGE" ]; then
    echo "Error: Failed to parse voltage from ADC output"
    exit 1
fi

# Compare voltage with threshold using awk (shell doesn't support floating point)
PASSED=$(awk -v volt="$VOLTAGE" -v thresh="$THRESHOLD" 'BEGIN { print (volt >= thresh) ? 1 : 0 }')

if [ "$PASSED" -eq 1 ]; then
    echo "Voltage=${VOLTAGE}V, passed"
    exit 0
else
    echo "Error: Voltage=${VOLTAGE}V, failed"
    exit 1
fi
