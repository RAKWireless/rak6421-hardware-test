#!/bin/sh

# Arguments
GPIO=${GPIO:-13}
FREQUENCY=${FREQUENCY:-440} # MHz
DURATION=${DURATION:-0.5} # sec

# Calculations
DELAY=$(( 500000 / $FREQUENCY ))

# Get gpiod version
DIR=$( cd "$( dirname "$0" )" && pwd )
. $DIR/utils.sh
GPIODV=$( gpiod_version )

# Play
if [ $GPIODV -eq 1 ];
then
    timeout $DURATION sh -c "while true; do gpioset -m time -u $DELAY 0 $GPIO=1 ; gpioset -m time -u $DELAY 0 $GPIO=0; done"
else
    timeout $DURATION gpioset -t ${DELAY}us -c 0 $GPIO=1
fi

return 0