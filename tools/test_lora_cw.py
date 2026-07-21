#!/usr/bin/env python3
"""
LoRa CW transmission script - compatible with Raspberry Pi 4 and Pi 5.

Uses libgpiod for pin 12/13 and rpi-lgpio for reset/busy (LoRaRF uses RPi.GPIO).
Requires rpi-lgpio instead of RPi.GPIO - works on both Pi 4 and Pi 5.
  pip install rpi-lgpio
  pip uninstall RPi.GPIO  # if previously installed
"""

__copyright__ = "Copyright 2026, RAKwireless"

import sys
import argparse
import time
import gpiod
from LoRaRF import SX126x


def lora_cw_simple(module_type="rak13300"):
    """Simple LoRa CW transmission that exits after completion"""
    
    # GPIO setup for pin 13 and pin 12 using official libgpiod 2.x
    # Open the GPIO chip
    chip = gpiod.Chip('/dev/gpiochip0')
    
    # Configure lines 13 and 12 as output
    line_settings = gpiod.LineSettings(
        direction=gpiod.line.Direction.OUTPUT,
        output_value=gpiod.line.Value.INACTIVE
    )
    
    # Request both lines
    line_request = chip.request_lines(
        consumer="lora_cw_simple",
        config={13: line_settings, 12: line_settings}
    )
    
    try:
        # Set pin 13 and pin 12 high at the start
        line_request.set_value(13, gpiod.line.Value.ACTIVE)
        line_request.set_value(12, gpiod.line.Value.ACTIVE)
        
        # Wait for hardware to stabilize
        time.sleep(0.1)
        
        # LoRa radio setup
        busId = 0
        csId = 0
        resetPin = 16
        busyPin = 24
        irqPin = -1
        txenPin = -1
        rxenPin = -1
        LoRa = SX126x()
        
        if not LoRa.begin(busId, csId, resetPin, busyPin, irqPin, txenPin, rxenPin):
            return False, "LoRa radio initialization failed"
        
        # Configure LoRa to use TCXO with DIO3 as control
        LoRa.setDio3TcxoCtrl(LoRa.DIO3_OUTPUT_1_8, LoRa.TCXO_DELAY_10)
        
        # Set RF switch controlled by DIO2
        LoRa.setDio2AsRfSwitchCtrl(LoRa.DIO2_AS_RF_SWITCH)
        
        # Set frequency to 917 MHz
        frequency_hz = int(917.0 * 1000000)
        LoRa.setFrequency(frequency_hz)
        
        # Set TX power based on module type
        if module_type == "rak13302":
            power_idx = 22  # High power for RAK13302
            expected_power = "30dBm"
        else:
            power_idx = 22  # Standard power for RAK13300
            expected_power = "22dBm"
            
        LoRa.setTxPower(power_idx, LoRa.TX_POWER_SX1262)
        
        # Configure modulation: SF12, BW125kHz, CR4/5
        sf = 12
        bw = 125000
        cr = 5
        LoRa.setLoRaModulation(sf, bw, cr)
        
        # Configure packet with preamble_length=450
        preamble_length = 450
        LoRa.setLoRaPacket(LoRa.HEADER_EXPLICIT, preamble_length, 1, True, False)
        LoRa.setSyncWord(0x3444)
        
        # Start transmission with minimal payload
        minimal_payload = [0x00]
        
        # Begin the packet transmission
        LoRa.beginPacket()
        LoRa.write(minimal_payload, 1)
        LoRa.endPacket()
        
        # Wait for transmission to complete
        LoRa.wait()
        
        # Generate output message based on module type
        if module_type == "rak13302":
            output_msg = f"LoRa HP CW test passed. You should measure {expected_power} output power."
        else:
            output_msg = f"LoRa CW test passed. You should measure {expected_power} output power."
        print(output_msg)
        
        return True, output_msg
        
    except Exception as e:
        import traceback
        error_details = traceback.format_exc()
        print(f"LoRa CW transmission failed: {e}")
        print(f"Error details:\n{error_details}")
        return False, str(e)
        
    finally:
        # Cleanup: Stop LoRa radio and set GPIO low
        try:
            if 'LoRa' in locals():
                LoRa.setStandby(LoRa.STANDBY_RC)
                LoRa.end()
        except Exception:
            pass
        
        # Cleanup GPIO
        try:
            line_request.set_value(13, gpiod.line.Value.INACTIVE)
            line_request.set_value(12, gpiod.line.Value.INACTIVE)
            line_request.release()
            chip.close()
        except Exception:
            pass


def main():
    parser = argparse.ArgumentParser(
        description='LoRa CW Transmission (Pi 4 & Pi 5 compatible)'
    )
    parser.add_argument('--module', type=str, default='rak13300', 
                       choices=['rak13300', 'rak13302'],
                       help='Module type (rak13300 or rak13302)')
    
    args = parser.parse_args()
    
    success, message = lora_cw_simple(args.module)
    
    if success:
        return 0
    else:
        return 1


if __name__ == "__main__":
    sys.exit(main())
