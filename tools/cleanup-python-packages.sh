#!/bin/bash

# -----------------------------------------------------------------------------
# Cleanup Python packages for RAK6421 hardware test
# Removes Python packages installed system-wide (without virtual environment)
# Output: JSON format
# -----------------------------------------------------------------------------

set -e  # Exit on any error

# Check if requirements.txt exists
if [ ! -f tools/requirements.txt ]; then
  echo '{"error": "tools/requirements.txt not found", "status": "FAIL"}'
  exit 1
fi

# Check if pip supports --break-system-packages flag
PIP_FLAGS=""
if pip3 uninstall --help | grep -q "break-system-packages" 2>/dev/null; then
  PIP_FLAGS="--break-system-packages"
fi

# Extract package names from requirements.txt
PACKAGE_LIST=()
while IFS= read -r line; do
  # Skip comments and empty lines
  [[ "$line" =~ ^#.*$ ]] && continue
  [[ -z "$line" ]] && continue
  
  # Extract package name (before == or >=)
  PACKAGE=$(echo "$line" | sed 's/\([^>=]*\).*/\1/')
  PACKAGE_LIST+=("$PACKAGE")
done < tools/requirements.txt

# Exit if no packages found
if [ ${#PACKAGE_LIST[@]} -eq 0 ]; then
  echo '{"error": "No packages found in requirements.txt", "status": "FAIL"}'
  exit 1
fi

# Packages to skip (not to be removed)
SKIP_PACKAGES=("gpiod" "Adafruit-PureIO" "spidev")

# Initialize counters
TOTAL=${#PACKAGE_LIST[@]}
REMOVED=0
NOT_INSTALLED=0
SKIPPED=0
FAILED=0

# Array to store package results
PACKAGE_RESULTS=()

# Process each package individually
for PACKAGE in "${PACKAGE_LIST[@]}"; do
  # Check if package is in skip list
  SKIP=0
  for SKIP_PKG in "${SKIP_PACKAGES[@]}"; do
    if [ "$PACKAGE" = "$SKIP_PKG" ]; then
      SKIP=1
      break
    fi
  done
  
  if [ $SKIP -eq 1 ]; then
    SKIPPED=$((SKIPPED + 1))
    PACKAGE_RESULTS+=("{\"name\":\"$PACKAGE\",\"result\":\"skipped\",\"status\":\"PASS\"}")
    continue
  fi
  
  # Check if package is installed
  if pip3 show "$PACKAGE" >/dev/null 2>&1; then
    # Try to uninstall
    OUTPUT=$(sudo pip3 uninstall -y $PIP_FLAGS "$PACKAGE" 2>&1)
    if [ $? -eq 0 ]; then
      REMOVED=$((REMOVED + 1))
      PACKAGE_RESULTS+=("{\"name\":\"$PACKAGE\",\"result\":\"removed\",\"status\":\"PASS\"}")
    else
      FAILED=$((FAILED + 1))
      PACKAGE_RESULTS+=("{\"name\":\"$PACKAGE\",\"result\":\"failed\",\"status\":\"FAIL\"}")
    fi
  else
    NOT_INSTALLED=$((NOT_INSTALLED + 1))
    PACKAGE_RESULTS+=("{\"name\":\"$PACKAGE\",\"result\":\"not_installed\",\"status\":\"PASS\"}")
  fi
done

# Clean pip cache silently
pip3 cache purge >/dev/null 2>&1 || true
sudo pip3 cache purge >/dev/null 2>&1 || true

# Determine overall status
OVERALL_STATUS="PASS"
if [ $FAILED -gt 0 ]; then
  OVERALL_STATUS="FAIL"
fi

# Build JSON output
echo "{"
echo "  \"summary\": {"
echo "    \"total\": $TOTAL,"
echo "    \"removed\": $REMOVED,"
echo "    \"not_installed\": $NOT_INSTALLED,"
echo "    \"skipped\": $SKIPPED,"
echo "    \"failed\": $FAILED,"
echo "    \"status\": \"$OVERALL_STATUS\""
echo "  },"
echo "  \"packages\": ["

# Output package results
for i in "${!PACKAGE_RESULTS[@]}"; do
  echo -n "    ${PACKAGE_RESULTS[$i]}"
  if [ $i -lt $((${#PACKAGE_RESULTS[@]} - 1)) ]; then
    echo ","
  else
    echo ""
  fi
done

echo "  ]"
echo "}"
