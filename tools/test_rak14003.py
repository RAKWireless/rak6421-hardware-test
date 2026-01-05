#!/usr/bin/env python3
"""
RAK14003 LED Button Module quick test script
Test LED control via MCP23017 GPIO expander
Based on wisblock-python/interface/rak13003/rak13003-blink/rak13003-blink.py
"""
__copyright__ = "Copyright 2026, RAKwireless"

import sys
import time

def test_rak14003(reset_pin=16):
    """Test RAK14003 LED Button Module
    
    Args:
        reset_pin: GPIO pin number for reset (16 for slot 1, 24 for slot 2)
    """
    try:
        import board
        import busio
        from adafruit_mcp230xx.mcp23017 import MCP23017
        import RPi.GPIO as GPIO
        
        # Reset device first
        GPIO.setup(reset_pin, GPIO.OUT)
        GPIO.output(reset_pin, GPIO.HIGH)
        time.sleep(0.1)
        GPIO.output(reset_pin, GPIO.LOW)
        time.sleep(0.1)
        GPIO.output(reset_pin, GPIO.HIGH)
        time.sleep(0.1)
        
        # Initialize the I2C bus
        i2c = busio.I2C(board.SCL, board.SDA)
        
        # Create MCP23017 instance at address 0x24
        mcp = MCP23017(i2c, address=0x24, reset=True)
        
        # Get pin 0 and set as output
        pin = mcp.get_pin(0)
        pin.switch_to_output(value=True)
        
        # Blink LED 2 times (quick test)
        for i in range(5):
            pin.value = True
            time.sleep(0.3)
            pin.value = False
            time.sleep(0.3)
        
        # Cleanup
        GPIO.cleanup()
        
        # Format output
        print(f"LED blinked successfully (reset pin: GPIO{reset_pin})")
        return True
        
    except ImportError as e:
        print(f"Missing dependency: {e}")
        print("  Please install: pip3 install adafruit-circuitpython-mcp230xx RPi.GPIO")
        return False
    except Exception as e:
        print(f"RAK14003 test failed: {e}")
        try:
            GPIO.cleanup()
        except:
            pass
        return False

if __name__ == "__main__":
    # Get reset pin from environment or use default
    import os
    reset_pin = int(os.environ.get('RAK14003_RESET_PIN', '16'))
    success = test_rak14003(reset_pin)
    sys.exit(0 if success else 1)


