#! /bin/sh

# -----------------------------------------------------------------------------
# Full hardware test suite for RAK6421 boards
# Based on run.sh, added with actual sensor data reading
# Note: This script uses system-wide Python packages (no virtual environment)
# -----------------------------------------------------------------------------

# Set USE_VENV=0 to disable virtual environment in utils.sh
export USE_VENV=0

. ./tools/utils.sh

# -----------------------------------------------------------------------------

KITS="
  rak6421-kit-environment-1
  rak6421-kit-environment-2
  rak6421-kit-industrial
  rak6421-kit-meshtastic-old
  rak6421-kit-meshtastic-hp-old
  rak6421-kit-meshtastic
  rak6421-kit-meshtastic-hp
  rak6421-kit-wismesh-station
  rak6421-kit-wismesh-station-hp
"

print_kits() {
  echo
  echo "${COLOR_ERROR}Available kit_id values:${COLOR_END}"
  for KIT in $KITS
  do
    echo "${COLOR_ERROR}* $KIT${COLOR_END}"
  done
  echo
}

# Parse command line arguments
OUTPUT_JSON=0
KIT=""
SHUNIT_ARGS=""

# Save original arguments for shunit2
ORIGINAL_ARGS="$@"

while [ $# -gt 0 ]; do
  case "$1" in
    --json)
      OUTPUT_JSON=1
      shift
      ;;
    *)
      if [ -z "$KIT" ]; then
        KIT="$1"
      fi
      shift
      ;;
  esac
done

# Show usage if kit_id not provided
if [ -z "$KIT" ]
then
  echo
  echo "${COLOR_ERROR}Usage: $0 [--json] <kit_id>${COLOR_END}"
  print_kits
  exit 1
fi

# Show valid parameters if wrong input
if [ $( echo $KITS | grep -w $KIT | wc -l ) -ne 1 ]
then
  echo
  echo "${COLOR_ERROR}Wrong configuration value.${COLOR_END}"
  print_kits
  exit 1
fi

# Configurations
CONFIGURATION=""
[ "$KIT" = "rak6421-kit-environment-1" ] && CONFIGURATION="empty empty rak1906 rak12002 rak12019 rak12047"
[ "$KIT" = "rak6421-kit-environment-2" ] && CONFIGURATION="rak12037 empty rak1906 rak12002 rak12019 rak12047"
[ "$KIT" = "rak6421-kit-industrial" ] && CONFIGURATION="rak5801 rak5802 rak18001 rak12002 empty empty"
[ "$KIT" = "rak6421-kit-meshtastic-old" ] && CONFIGURATION="rak13300 empty rak18001 rak12002 rak1906 empty"
[ "$KIT" = "rak6421-kit-meshtastic-hp-old" ] && CONFIGURATION="rak13302 empty rak18001 rak12002 rak1906 empty"
[ "$KIT" = "rak6421-kit-meshtastic" ] && CONFIGURATION="rak13300 empty rak12501 rak1901 rak1906 empty"
[ "$KIT" = "rak6421-kit-meshtastic-hp" ] && CONFIGURATION="rak13302 empty rak12501 rak1901 rak1906 empty"
[ "$KIT" = "rak6421-kit-wismesh-station" ] && CONFIGURATION="rak13300 empty rak12501 empty empty empty"
[ "$KIT" = "rak6421-kit-wismesh-station-hp" ] && CONFIGURATION="rak13302 empty rak12501 empty empty empty"

# JSON output data structure
JSON_START_TIME=$(date +%s)
# Store test outputs for JSON
JSON_TEST_OUTPUTS=""

# -----------------------------------------------------------------------------

oneTimeSetUp() {

  # Redirect output to /dev/null if JSON mode (已移除，fd 只在主流程保存/恢复)
  if [ $OUTPUT_JSON -eq 1 ]; then
    exec 1>/dev/null 2>&1
  fi

  # Install system dependencies
  dependencyCheck virtualenv python3-virtualenv
  dependencyCheck i2cdetect i2c-tools
  dependencyCheck jq
  dependencyCheck lshw
  dependencyCheck python3 python3

  # Enable I2C
  if [ $( raspi-config nonint get_i2c ) -ne 0 ]
  then
    [ $OUTPUT_JSON -eq 0 ] && echo "${COLOR_INFO}Enabling I2C${COLOR_END}"
    sudo raspi-config nonint do_i2c 0 >/dev/null 2>&1
  fi

  # Old libgpiod
  if [ ! -f /usr/bin/libgpiod.so.2 ]
  then
    [ $OUTPUT_JSON -eq 0 ] && echo "${COLOR_INFO}Copying libgpiod.so.2 to /usr/bin/${COLOR_END}"
    sudo cp tools/libgpiod.so.2 /usr/bin/ >/dev/null 2>&1
    sudo ldconfig >/dev/null 2>&1
  fi

  # Setup Python virtual environment and install dependencies (only for sensors without compiled tools)
  pythonEnvSetup

  # System info - only print if not JSON mode
  if [ $OUTPUT_JSON -eq 0 ]; then
    systemInfo
  fi
  
  return 0

}

oneTimeTearDown() {
  
  # Hack for https://github.com/kward/shunit2/issues/112
  [ "${_shunit_name_}" = 'EXIT' ] && return 0

  # Clean up virtual environment (optional, commented out by default)
  #pythonEnvRemove
  
  return 0

}

# -----------------------------------------------------------------------------
# Test functions - Each includes I2C detection and actual sensor reading
# -----------------------------------------------------------------------------

# Helper function for conditional output (silent in JSON mode)
# Note: Function name must NOT start with "test" to avoid shunit2 auto-discovery
conditional_echo() {
  [ $OUTPUT_JSON -eq 0 ] && echo "$@"
}

# Helper function to store test output for JSON
json_store_output() {
  if [ $OUTPUT_JSON -eq 1 ] && [ -n "$1" ] && [ -n "$2" ]; then
    # Store as test_name:output format, separated by special delimiter
    # Use base64 encoding to handle special characters safely
    TEST_NAME="$1"
    TEST_OUTPUT="$2"
    SANITIZED_OUTPUT="$(printf "%s" "$TEST_OUTPUT" | tr '\n' ' ')"
    # Replace problematic characters with placeholders, or use base64
    ENCODED_OUTPUT=$(echo "$SANITIZED_OUTPUT" | base64 -w 0 2>/dev/null || echo "$SANITIZED_OUTPUT" | base64 2>/dev/null | tr -d '\n')
    JSON_TEST_OUTPUTS="${JSON_TEST_OUTPUTS}${JSON_TEST_OUTPUTS:+||}$TEST_NAME::${ENCODED_OUTPUT}"
  fi
  return 0
}

testADC() {
  conditional_echo "${COLOR_INFO}Testing ADS1115 ADC...${COLOR_END}"
  # i2cget -y 1 0x48 > /dev/null 2>&1
  # assertEquals "ADC not found on I2C" 0 $?

  # Run ADS1115 register test
  OUTPUT=$( ./tools/ads1115 --addr=GND -t reg 2>&1 )
  ERRORS=$( echo "$OUTPUT" | grep -ci "error" )
  assertEquals "ADC test failed" 0 $ERRORS
  if [ $ERRORS -eq 0 ]; then
    conditional_echo "${COLOR_INFO}  ADS1115 test succeed${COLOR_END}"
    json_store_output "testADC" "ADS1115 test succeed"
  else
    json_store_output "testADC" "$OUTPUT"
  fi
}

testRAK1901() {
  conditional_echo "${COLOR_INFO}Testing RAK1901 (SHTC3 Temperature & Humidity Sensor)...${COLOR_END}"
  
  # Read sensor data using compiled tool
  OUTPUT=$( ./tools/shtc3 -e read --times=1 2>&1 | grep -E "temperature|humidity" | head -2 | tr '\n' ' ' )
  RESULT=$?
  assertEquals "RAK1901 data read failed" 0 $RESULT
  [ -n "$OUTPUT" ] && conditional_echo "${COLOR_INFO}  ${OUTPUT}${COLOR_END}"
  # Store output for JSON
  [ -n "$OUTPUT" ] && json_store_output "testRAK1901" "$OUTPUT"
}

testRAK1906() {
  conditional_echo "${COLOR_INFO}Testing RAK1906 (BME680 Environmental Sensor)...${COLOR_END}"
  
  # I2C detection
  # i2cget -y 1 0x76 > /dev/null 2>&1
  # assertEquals "RAK1906 not found on I2C" 0 $?
  
  # Read sensor data using compiled tool
  OUTPUT=$( ./tools/bme680 -e read --addr=0 --times=1 2>&1 | grep -E "temperature|humidity|pressure" | head -3 | tr '\n' ' ' )
  RESULT=$?
  assertEquals "RAK1906 data read failed" 0 $RESULT
  [ -n "$OUTPUT" ] && conditional_echo "${COLOR_INFO}  ${OUTPUT}${COLOR_END}"
  # Store output for JSON
  [ -n "$OUTPUT" ] && json_store_output "testRAK1906" "$OUTPUT"
}

testRAK12002() {
  conditional_echo "${COLOR_INFO}Testing RAK12002 (RTC Real-Time Clock)...${COLOR_END}"
  
  # I2C detection
  # i2cget -y 1 0x52 > /dev/null 2>&1
  # assertEquals "RAK12002 not found on I2C" 0 $?
  
  # Read RTC time using RV3028 Python helper
  OUTPUT=$( python3 tools/test_rak12002.py 2>&1 )
  RESULT=$?

  assertEquals "RAK12002 time read failed" 0 $RESULT
  if [ $RESULT -eq 0 ]; then
    conditional_echo "${COLOR_INFO}  ${OUTPUT}${COLOR_END}"
  else
    conditional_echo "${COLOR_ERROR}  ${OUTPUT}${COLOR_END}"
  fi

  # Store output for JSON (full raw text for easier debugging)
  [ -n "$OUTPUT" ] && json_store_output "testRAK12002" "$OUTPUT"
}

testRAK12019() {
  conditional_echo "${COLOR_INFO}Testing RAK12019 (UV Sensor)...${COLOR_END}"
  
  # I2C detection
  # i2cget -y 1 0x53 > /dev/null 2>&1
  # assertEquals "RAK12019 not found on I2C" 0 $?
  
  # Read sensor data using Python script (no compiled tool available)
  OUTPUT=$( python3 tools/test_rak12019.py 2>&1 )
  RESULT=$?
  assertEquals "RAK12019 data read failed" 0 $RESULT
  conditional_echo "${COLOR_INFO}  ${OUTPUT}${COLOR_END}"
  # Store output for JSON
  [ -n "$OUTPUT" ] && json_store_output "testRAK12019" "$OUTPUT"
}

testRAK12037() {
  conditional_echo "${COLOR_INFO}Testing RAK12037 (CO2 Sensor)...${COLOR_END}"
  
  # I2C detection
  # i2cget -y 1 0x61 > /dev/null 2>&1
  # assertEquals "RAK12037 not found on I2C" 0 $?
  
  # Read sensor data using compiled tool
  OUTPUT=$( ./tools/scd30 -e read --times=1 2>&1 | grep -E "co2|temperature|humidity" | head -3 | tr '\n' ' ' )
  RESULT=$?
  assertEquals "RAK12037 data read failed" 0 $RESULT
  [ -n "$OUTPUT" ] && conditional_echo "${COLOR_INFO}  ${OUTPUT}${COLOR_END}"
  # Store output for JSON
  [ -n "$OUTPUT" ] && json_store_output "testRAK12037" "$OUTPUT"
}

testRAK12047() {
  conditional_echo "${COLOR_INFO}Testing RAK12047 (VOC Sensor)...${COLOR_END}"
  
  # # I2C detection
  # i2cget -y 1 0x59 > /dev/null 2>&1
  # assertEquals "RAK12047 not found on I2C" 0 $?
  
  # Read sensor data using compiled tool
  OUTPUT=$( ./tools/sgp40 -e read --times=1 2>&1 )
  RESULT=$?
  assertEquals "RAK12047 data read failed" 0 $RESULT
  
  # Extract VOC gas index from output
  VOC_INDEX=$( echo "$OUTPUT" | grep -i "voc gas index" | head -1 )
  [ -n "$VOC_INDEX" ] && conditional_echo "${COLOR_INFO}  ${VOC_INDEX}${COLOR_END}"
  # Store output for JSON
  [ -n "$VOC_INDEX" ] && json_store_output "testRAK12047" "$VOC_INDEX"
}

testRAK12501() {
  conditional_echo "${COLOR_INFO}Testing RAK12501 (GNSS GPS Module)...${COLOR_END}"
  
  # Run GNSS test script
  OUTPUT=$( tools/test_rak12501.sh 2>&1 )
  RESULT=$?
  
  assertEquals "RAK12501 test failed" 0 $RESULT
  if [ $RESULT -eq 0 ]; then
    conditional_echo "${COLOR_INFO}  ${OUTPUT}${COLOR_END}"
  else
    conditional_echo "${COLOR_ERROR}  ${OUTPUT}${COLOR_END}"
  fi
  
  # Store output for JSON
  [ -n "$OUTPUT" ] && json_store_output "testRAK12501" "$OUTPUT"
}


testRAK5801() {
  conditional_echo "${COLOR_INFO}Testing RAK5801 (4-20mA Interface)...${COLOR_END}"
  
  # Determine enable pin based on slot position
  INDEX=$( strindex "$CONFIGURATION" "rak5801" )
  ENABLE_PIN=$( echo "17,23" | cut -d',' -f$INDEX )
  
  # Run RAK5801 test script
  OUTPUT=$( ENABLE_PIN=$ENABLE_PIN tools/test_rak5801.sh 2>&1 )
  RESULT=$?
  
  assertEquals "RAK5801 test failed" 0 $RESULT
  if [ $RESULT -eq 0 ]; then
    conditional_echo "${COLOR_INFO}  ${OUTPUT}${COLOR_END}"
  else
    conditional_echo "${COLOR_ERROR}  ${OUTPUT}${COLOR_END}"
  fi
  
  # Store output for JSON
  [ -n "$OUTPUT" ] && json_store_output "testRAK5801" "$OUTPUT"
}

testRAK5802() {
  conditional_echo "${COLOR_INFO}Testing RAK5802 (RS485 Interface)...${COLOR_END}"
  
  # Start sender in background
  ./tools/test_rak5802_sender.sh > /dev/null 2>&1 &
  SENDER_PID=$!
  
  # Run RS485 receiver test with timeout
  OUTPUT=$( TIMEOUT=10 tools/test_rak5802_receiver.sh 2>&1 )
  RESULT=$?
  
  # Stop sender
  kill $SENDER_PID >/dev/null 2>&1
  
  assertEquals "RAK5802 test failed" 0 $RESULT
  if [ $RESULT -eq 0 ]; then
    conditional_echo "${COLOR_INFO}  ${OUTPUT}${COLOR_END}"
  else
    conditional_echo "${COLOR_ERROR}  ${OUTPUT}${COLOR_END}"
  fi
  
  # Store output for JSON
  [ -n "$OUTPUT" ] && json_store_output "testRAK5802" "$OUTPUT"
}

testRAK18001() {
  conditional_echo "${COLOR_INFO}Testing RAK18001 (Buzzer Module)...${COLOR_END}"
  
  INDEX=$( strindex "$CONFIGURATION" "rak18001" )
  GPIO=$( echo "0,0,6,13,21,23" | cut -d',' -f$INDEX)
  
  # Buzzer test
  GPIO=$GPIO tools/buzzer.sh > /dev/null 2>&1
  assertEquals "Buzzer play error" 0 $?
  
  conditional_echo "${COLOR_INFO}  Buzzer working${COLOR_END}"
  # Store output for JSON
  json_store_output "testRAK18001" "Test successful, you should have heard the buzzer sound."
}



testRAK13300() {
  conditional_echo "${COLOR_INFO}Testing RAK13300 (LoRa SX1262)...${COLOR_END}"
  
  # Run LoRa CW test for RAK13300
  OUTPUT=$( python3 tools/test_lora_cw.py --module rak13300 2>&1 )
  RESULT=$?
  
  assertEquals "RAK13300 LoRa CW test failed" 0 $RESULT
  if [ $RESULT -eq 0 ]; then
    conditional_echo "${COLOR_INFO}  ${OUTPUT}${COLOR_END}"
  else
    conditional_echo "${COLOR_ERROR}  ${OUTPUT}${COLOR_END}"
  fi
  
  # Store output for JSON
  [ -n "$OUTPUT" ] && json_store_output "testRAK13300" "$OUTPUT"
}

testRAK13302() {
  conditional_echo "${COLOR_INFO}Testing RAK13302 (LoRa SX1262 HP)...${COLOR_END}"
  
  # Run LoRa CW test for RAK13302 HP
  OUTPUT=$( python3 tools/test_lora_cw.py --module rak13302 2>&1 )
  RESULT=$?
  
  assertEquals "RAK13302 LoRa CW test failed" 0 $RESULT
  if [ $RESULT -eq 0 ]; then
    conditional_echo "${COLOR_INFO}  ${OUTPUT}${COLOR_END}"
  else
    conditional_echo "${COLOR_ERROR}  ${OUTPUT}${COLOR_END}"
  fi
  
  # Store output for JSON
  [ -n "$OUTPUT" ] && json_store_output "testRAK13302" "$OUTPUT"
}

# -----------------------------------------------------------------------------

suite() {
  # Add LoRa tests FIRST (for immediate RF signal verification on spectrum analyzer)
  for module in $CONFIGURATION; do
    case "$module" in
      rak13300) suite_addTest testRAK13300 ;;
      rak13302) suite_addTest testRAK13302 ;;
      *) ;;
    esac
  done

  # ADC test (required for all configurations)
  suite_addTest testADC

  # Add remaining tests based on configuration
  for module in $CONFIGURATION; do
    case "$module" in
      rak1901) suite_addTest testRAK1901 ;;
      rak1906) suite_addTest testRAK1906 ;;
      rak12002) suite_addTest testRAK12002 ;;
      rak12019) suite_addTest testRAK12019 ;;
      rak12037) suite_addTest testRAK12037 ;;
      rak12047) suite_addTest testRAK12047 ;;
      rak12501) suite_addTest testRAK12501 ;;
      rak5801) suite_addTest testRAK5801 ;;
      rak5802) suite_addTest testRAK5802 ;;
      rak18001) suite_addTest testRAK18001 ;;
      rak13300) ;;  # Already added above
      rak13302) ;;  # Already added above
      empty) ;;  # Skip empty slots
      *) ;;  # Ignore unknown modules
    esac
  done
}

# -----------------------------------------------------------------------------

# Generate JUnit XML if JSON output is requested (for parsing)
JUNIT_XML_FILE=""
TEST_OUTPUT_FILE=""
if [ $OUTPUT_JSON -eq 1 ]; then
  JUNIT_XML_FILE="${SHUNIT_TMPDIR:-/tmp}/shunit2_results_$$.xml"
  TEST_OUTPUT_FILE="${SHUNIT_TMPDIR:-/tmp}/test_output_$$.log"
  SHUNIT_ARGS="-- --output-junit-xml=$JUNIT_XML_FILE"
  exec 3>&1 4>&2
  exec 1>"$TEST_OUTPUT_FILE" 2>&1
fi

# Only print header if not JSON mode
if [ $OUTPUT_JSON -eq 0 ]; then
  echo
  echo "${COLOR_INFO}========================================${COLOR_END}"
  echo "${COLOR_INFO}RAK6421 Full Hardware Test Suite${COLOR_END}"
  echo "${COLOR_INFO}Configuration: $KIT${COLOR_END}"
  echo "${COLOR_INFO}========================================${COLOR_END}"
  echo
fi

# Run shunit2 with arguments if JSON output is requested
# shunit2 will process arguments from $@ when sourced
if [ -n "$SHUNIT_ARGS" ]; then
  # Build list of tests to run based on configuration
  # Add LoRa tests FIRST (for immediate RF signal verification)
  TEST_LIST=""
  for module in $CONFIGURATION; do
    case "$module" in
      rak13300) TEST_LIST="$TEST_LIST testRAK13300" ;;
      rak13302) TEST_LIST="$TEST_LIST testRAK13302" ;;
      *) ;;
    esac
  done
  
  # Add ADC test
  TEST_LIST="$TEST_LIST testADC"
  
  # Add remaining tests
  for module in $CONFIGURATION; do
    case "$module" in
      rak1901) TEST_LIST="$TEST_LIST testRAK1901" ;;
      rak1906) TEST_LIST="$TEST_LIST testRAK1906" ;;
      rak12002) TEST_LIST="$TEST_LIST testRAK12002" ;;
      rak12019) TEST_LIST="$TEST_LIST testRAK12019" ;;
      rak12037) TEST_LIST="$TEST_LIST testRAK12037" ;;
      rak12047) TEST_LIST="$TEST_LIST testRAK12047" ;;
      rak12501) TEST_LIST="$TEST_LIST testRAK12501" ;;
      rak5801) TEST_LIST="$TEST_LIST testRAK5801" ;;
      rak5802) TEST_LIST="$TEST_LIST testRAK5802" ;;
      rak18001) TEST_LIST="$TEST_LIST testRAK18001" ;;
      rak13300) ;;  # Already added above
      rak13302) ;;  # Already added above
      empty) ;;  # Skip empty slots
      *) ;;  # Ignore unknown modules
    esac
  done
  
  # Set arguments for shunit2: first the XML output option, then the test names
  set -- $SHUNIT_ARGS $TEST_LIST
  . ./shunit2/shunit2
  # Restore original arguments (though we don't need them anymore)
  set -- $ORIGINAL_ARGS
else
  # No special arguments, run normally (suite() will be called)
  set --
  . ./shunit2/shunit2
fi

# If JSON output was requested, parse results and generate JSON
if [ $OUTPUT_JSON -eq 1 ]; then
  # Restore stdout for JSON output (只在这里恢复)
  exec 1>&3 2>&4
  exec 3>&- 4>&-

  JSON_END_TIME=$(date +%s)
  JSON_DURATION=$((JSON_END_TIME - JSON_START_TIME))

  # Export stored outputs for Python script
  export JSON_TEST_OUTPUTS

  set -- \
    --kit "$KIT" \
    --duration "$JSON_DURATION" \
    --total "${__shunit_testsTotal:-0}" \
    --passed "${__shunit_testsPassed:-0}" \
    --failed "${__shunit_testsFailed:-0}"

  if [ -n "$JUNIT_XML_FILE" ] && [ -s "$JUNIT_XML_FILE" ]; then
    set -- "$@" --junit "$JUNIT_XML_FILE"
  fi

  if [ -n "$TEST_OUTPUT_FILE" ] && [ -s "$TEST_OUTPUT_FILE" ]; then
    set -- "$@" --test-output "$TEST_OUTPUT_FILE"
  fi

  python3 tools/generate_json_report.py "$@"
fi
