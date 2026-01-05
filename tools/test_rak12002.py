#!/usr/bin/env python3
"""Quick health-check script for the RAK12002 RTC (RV3028-C7)."""
__copyright__ = "Copyright 2026, RAKwireless"

import sys
from datetime import datetime


def format_timestamp(ts: datetime) -> str:
    """Return a human friendly timestamp string."""
    return ts.strftime("%Y-%m-%d %H:%M:%S")


def test_rak12002() -> bool:
    """Probe the RV3028 device and print the current RTC time."""
    try:
        import rv3028  # pylint: disable=import-error
    except ImportError as exc:  # pragma: no cover - dependency missing on host machine
        print(f"Missing dependency: {exc}")
        print("  Please install: pip3 install rv3028")
        return False

    try:
        rtc = rv3028.RV3028()
        rtc.set_battery_switchover('level_switching_mode')
        rtc_time = rtc.get_time_and_date()
    except OSError as exc:
        print(f"I2C communication error: {exc}")
        print("  Ensure the RAK12002 is fitted, powered, and visible at address 0x52.")
        return False
    except Exception as exc:  # pragma: no cover - unexpected hardware failure
        print(f"RAK12002 test failed: {exc}")
        return False

    print(f"RTC time: {format_timestamp(rtc_time)}")
    return True


def main() -> int:
    return 0 if test_rak12002() else 1


if __name__ == "__main__":
    sys.exit(main())

