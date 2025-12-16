#! /bin/sh

# -----------------------------------------------------------------------------
# Unit test suite for RAK739X boards
# -----------------------------------------------------------------------------

. ./tools/utils.sh

# -----------------------------------------------------------------------------

KITS="
  rak6421-kit-environment-1
  rak6421-kit-environment-2
  rak6421-kit-industrial
  rak6421-kit-meshtastic
  rak6421-kit-meshtastic-hp
"

print_kits() {
  echo
  echo "${COLOR_ERROR}Posible kit_id values:${COLOR_END}"
  for KIT in $KITS
  do
    echo "${COLOR_ERROR}* $KIT"
  done
  echo
}

# Show usages if called without parameters
if [ $# -ne 1 ] 
then
  echo
  echo "${COLOR_ERROR}Usage: $0 <kit_id>${COLOR_END}"
  print_kits
  exit 1
fi
KIT="$1"
shift

# Show valid parameters if wrong input
if [ $( echo $KITS | grep -w $KIT | wc -l ) -ne 1 ]
then
  echo
  echo "${COLOR_ERROR}Wrong configuration value.${COLOR_END}"
  print_configurations
  exit 1
fi

# Configurations
CONFIGURATION=""
[ "$KIT" = "rak6421-kit-environment-1" ] && CONFIGURATION="rak14003 empty rak1906 rak12002 rak12019 rak12047"
[ "$KIT" = "rak6421-kit-environment-2" ] && CONFIGURATION="rak14003 rak12037 rak1906 rak12002 rak12019 rak12047"
[ "$KIT" = "rak6421-kit-industrial" ] && CONFIGURATION="rak5801 rak5802 rak18001 rak12002 empty empty"
[ "$KIT" = "rak6421-kit-meshtastic" ] && CONFIGURATION="rak13300 empty rak18001 rak12002 rak1906 empty"
[ "$KIT" = "rak6421-kit-meshtastic-hp" ] && CONFIGURATION="rak13302 empty rak18001 rak12002 rak1906 empty"

# -----------------------------------------------------------------------------

oneTimeSetUp() {

  # Install dependencies
  dependencyCheck virtualenv python3-virtualenv
  dependencyCheck i2cdetect i2c-tools
  dependencyCheck jq
  dependencyCheck lshw

  # Enable I2C
  if [ $( raspi-config nonint get_i2c ) -ne 0 ]
  then
    echo "${COLOR_INFO}Enabling I2C${COLOR_END}"
    sudo raspi-config nonint do_i2c 0
  fi

  # Old libgpiod
  if [ ! -f /usr/bin/libgpiod.so.2 ]
  then
    echo "${COLOR_INFO}Copying libgpiod.so.2 to /usr/bin/${COLOR_END}"
    sudo cp tools/libgpiod.so.2 /usr/bin/
    sudo ldconfig
  fi

  # info
  systemInfo

  return 0

}

oneTimeTearDown() {
  
  # Hack for https://github.com/kward/shunit2/issues/112
  [ "${_shunit_name_}" = 'EXIT' ] && return 0

  # System dependencies
  #dependencyRemove

  return 0

}

# -----------------------------------------------------------------------------

testADC() {
  i2cget -y 1 0x48 > /dev/null 2>&1
  assertEquals "ADC not found" 0 $?
  ERRORS=$( ./tools/ads1115 --addr=GND -t reg | grep -ci "error" )
  assertEquals "ADC test errored" 0 $ERRORS
}

testRAK1906() {
  i2cget -y 1 0x76 > /dev/null 2>&1
  assertEquals "RAK1906 not found" 0 $?
}

testRAK1921() {
  i2cget -y 1 0x3c > /dev/null 2>&1
  assertEquals "RAK1921 not found" 0 $?
}

testRAK12002() {
  i2cget -y 1 0x52 > /dev/null 2>&1
  assertEquals "RAK12002 not found" 0 $?
}

testRAK12019() {
  i2cget -y 1 0x53 > /dev/null 2>&1
  assertEquals "RAK12019 not found" 0 $?
}

testRAK12037() {
  i2cget -y 1 0x61 > /dev/null 2>&1
  assertEquals "RAK12037 not found" 0 $?
}

testRAK12047() {
  i2cget -y 1 0x59 > /dev/null 2>&1
  assertEquals "RAK12047 not found" 0 $?
}

testRAK14003() {
  INDEX=$( strindex "$CONFIGURATION" "rak14003" )
  GPIO=$( echo "16,24" | cut -d',' -f$INDEX )
  gpioset -c gpiochip0 -t0 $GPIO=1 && sleep 0.5
  gpioset -c gpiochip0 -t0 $GPIO=0 && sleep 0.5
  gpioset -c gpiochip0 -t0 $GPIO=1 && sleep 3
  i2cget -y 1 0x24 > /dev/null 2>&1
  assertEquals "RAK14003 not found" 0 $?
}

testRAK18001() {
  INDEX=$( strindex "$CONFIGURATION" "rak18001" )
  GPIO=$( echo "0,0,6,13,21,23" | cut -d',' -f$INDEX)
  GPIO=$GPIO tools/buzzer.sh
  assertEquals "Error playing buzzer" 0 $?
}

# -----------------------------------------------------------------------------

suite() {
  
  suite_addTest testADC
  [ $( echo $CONFIGURATION | grep -c -w "rak1906" ) -eq 1 ] && suite_addTest testRAK1906
  [ $( echo $CONFIGURATION | grep -c -w "rak1921" ) -eq 1 ] && suite_addTest testRAK1921
  [ $( echo $CONFIGURATION | grep -c -w "rak12002" ) -eq 1 ] && suite_addTest testRAK12002
  [ $( echo $CONFIGURATION | grep -c -w "rak12019" ) -eq 1 ] && suite_addTest testRAK12019
  [ $( echo $CONFIGURATION | grep -c -w "rak12037" ) -eq 1 ] && suite_addTest testRAK12037
  [ $( echo $CONFIGURATION | grep -c -w "rak12047" ) -eq 1 ] && suite_addTest testRAK12047
  [ $( echo $CONFIGURATION | grep -c -w "rak14003" ) -eq 1 ] && suite_addTest testRAK14003
  [ $( echo $CONFIGURATION | grep -c -w "rak18001" ) -eq 1 ] && suite_addTest testRAK18001

}

# -----------------------------------------------------------------------------

echo
. ./shunit2/shunit2
echo