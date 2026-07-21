#!/usr/bin/env python3
"""
RAK12019 UV sensor quick test script
Read UV index and ambient light data
Based on wisblock-python/sensors/rak12019/rak12019-read/rak12019-read.py
"""
__copyright__ = "Copyright 2022, RAKwireless"

import sys
import time

def test_rak12019():
    """Test RAK12019 UV sensor"""
    try:
        import board
        from adafruit_ltr390 import LTR390
        
        i2c = board.I2C()
        ltr = LTR390(i2c)
        
        # Wait for sensor to stabilize
        time.sleep(0.5)
        
        # Read 1-2 samples and average
        uv_sum = 0
        light_sum = 0
        samples = 2
        
        for _ in range(samples):
            uv_sum += ltr.uvs
            light_sum += ltr.light
            time.sleep(0.5)
        
        uv_avg = uv_sum / samples
        light_avg = light_sum / samples
        
        # Format output
        print(f"UV: {uv_avg:.0f} | Ambient Light: {light_avg:.0f}")
        return True
        
    except ImportError as e:
        print(f"Missing dependency: {e}")
        print("  Please install: pip3 install adafruit-circuitpython-ltr390")
        return False
    except Exception as e:
        print(f"RAK12019 test failed: {e}")
        return False

if __name__ == "__main__":
    success = test_rak12019()
    sys.exit(0 if success else 1)

