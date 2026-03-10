# -----------------------------------------------------------------------------
# Colors
# -----------------------------------------------------------------------------

# Reset
COLOR_RESET='\033[0m'

# Regular Colors
COLOR_BLACK='\033[0;30m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_PURPLE='\033[0;35m'
COLOR_CYAN='\033[0;36m'
COLOR_WHITE='\033[0;37m'

# Bold
COLOR_BLACK_BOLD='\033[1;30m'
COLOR_RED_BOLD='\033[1;31m'
COLOR_GREEN_BOLD='\033[1;32m'
COLOR_YELLOW_BOLD='\033[1;33m'
COLOR_BLUE_BOLD='\033[1;34m'
COLOR_PURPLE_BOLD='\033[1;35m'
COLOR_CYAN_BOLD='\033[1;36m'
COLOR_WHITE_BOLD='\033[1;37m'

# Alias
COLOR_INFO=$COLOR_GREEN_BOLD
COLOR_WARNING=$COLOR_YELLOW_BOLD
COLOR_ERROR=$COLOR_RED_BOLD
COLOR_END=$COLOR_RESET

# -----------------------------------------------------------------------------
# Dependency management
# -----------------------------------------------------------------------------

INSTALLED_DEPENDENCIES=""
PACKAGES_CACHED=0

dependencyInstalled() {
    echo "${COLOR_INFO}Installed packages: $INSTALLED_DEPENDENCIES${COLOR_END}"
}

dependencyRemove() {
    if [ "$INSTALLED_DEPENDENCIES" != "" ];
    then
        echo
        echo "${COLOR_INFO}Removing installed dependencies: $INSTALLED_DEPENDENCIES${COLOR_END}"
        sudo apt remove -y $INSTALLED_DEPENDENCIES
    fi
}

dependencyCheck() {
    
    COMMAND=$1
    PACKAGE=${2:-$COMMAND}

    if command -v $COMMAND >/dev/null 2>&1
    then
        echo "${COLOR_INFO}Dependency $COMMAND already available${COLOR_END}"
    else
        echo "${COLOR_INFO}Installing $COMMAND dependency${COLOR_END}"
        if [ $PACKAGES_CACHED -eq 0 ] 
        then
            sudo apt update
            PACKAGES_CACHED=1
        fi
        sudo apt install -y $PACKAGE
        INSTALLED_DEPENDENCIES="${INSTALLED_DEPENDENCIES}${PACKAGE} "
    fi

}

pythonEnvSetup() {
    echo "${COLOR_INFO}Installing required python packages${COLOR_END}"
    
    # Check if USE_VENV is set to 0 (no virtual environment)
    if [ "${USE_VENV:-1}" = "0" ]; then
        echo "${COLOR_INFO}Installing packages system-wide (no virtual environment)${COLOR_END}"
        
        # Check if pip supports --break-system-packages flag
        PIP_FLAGS=""
        if pip3 install --help | grep -q "break-system-packages" 2>/dev/null; then
            PIP_FLAGS="--break-system-packages"
            echo "${COLOR_INFO}Using --break-system-packages flag${COLOR_END}"
        fi
        
        # Install packages system-wide
        # Suppress pip root-user warning noise (keep real errors visible)
        sudo PIP_ROOT_USER_ACTION=ignore PIP_DISABLE_PIP_VERSION_CHECK=1 \
            pip3 install -q $PIP_FLAGS -r tools/requirements.txt 2>&1 \
          | grep -v -E "already satisfied|Running pip as the 'root' user|broken permissions|It is recommended to use a virtual environment instead|https://pip\\.pypa\\.io/warnings/venv" \
          || true
        return 0
    fi
    
    # Default: Use virtual environment
    echo "${COLOR_INFO}Using virtual environment${COLOR_END}"
    
    # Check if .env exists and has correct ownership
    if [ -d .env ]; then
        # Check if current user owns the .env directory
        if [ ! -O .env ]; then
            echo "${COLOR_WARNING}Removing .env directory with wrong ownership${COLOR_END}"
            rm -rf .env
        fi
    fi
    
    # Create virtual environment if it doesn't exist
    if [ ! -d .env ]; then
        virtualenv .env  > /dev/null 2>&1
    fi
    
    # Activate and install dependencies
    . .env/bin/activate
    pip install -q -r tools/requirements.txt 2>&1 | grep -v "already satisfied" || true
}

pythonEnvRemove() {
  if [ -d .env ] 
  then
    echo
    echo "${COLOR_INFO}Removing python packages${COLOR_END}"
    rm -rf .env
  fi
}

systemInfo() {
    
    . /etc/os-release

    # Info
    echo "${COLOR_YELLOW}"
    echo "CPU:" $( lshw -quiet -json -c system 2>/dev/null | jq '.[].product' | sed 's/"//g' )
    echo "CPU Serial Number:" $( lshw -quiet -json -c system 2>/dev/null | jq '.[].serial' | sed 's/"//g' )
    echo "Memory:" $( free -h | tail -2 | head -1 | awk '{print $2}' )
    echo "Storage:" $( df -h | grep -w "/" | awk '{print $2}' )
    echo "Device EUI:" $( ip link show eth0 | awk '/ether/ {print $2}' | awk -F: '{print $1$2$3"FFFE"$4$5$6}' )
    echo "OS: $VERSION_ID"
    echo "${COLOR_END}"

}

strindex() { 
    local STR="$1"
    local SEARCH="$2"
    local INDEX=1
    while true
    do
        WORD=$( echo "$STR" | cut -d' ' -f$INDEX )
        [ "$WORD" = "" ] && break
        [ "$WORD" = "$SEARCH" ] && echo $INDEX && return
        INDEX=$(( INDEX+1 ))
    done
    echo 0
}

gpiod_version() {
    OUTPUT=$( gpioset -v )
    VERSION=$( echo $OUTPUT | cut -d' ' -f 3 |  cut -d'.' -f1 | sed 's/v//' )
    echo $VERSION
}
