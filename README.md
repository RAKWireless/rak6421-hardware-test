# Hardware tests for RAK6421 kits

This is a shell script that uses shunit2 to perform unit tests on different predefined configurations based on a RAK6421. Different tests are run based on the different possible configurations. Configurations are defined by their configuration ID, a string that uniquely identifies the features in a device.

## Prerequisites

### Pre-built RAKPiOS firmware (offline)

If you're using a RAKPiOS image built with pi-gen, all dependencies are pre-installed. No network needed — just run the test scripts directly on both **Raspberry Pi 4** and **Raspberry Pi 5**.

```bash
sudo ./run-full-test.sh rak6421-kit-meshtastic
```

### Manual setup (clone this repo on a fresh Raspberry Pi OS)

Run tests using `run.sh` — it automatically creates a virtualenv and installs all Python dependencies:

```bash
./run.sh <kit_id>
```

> **Note:** On Raspberry Pi 5, the old `RPi.GPIO` library is incompatible. The setup script automatically replaces it with `rpi-lgpio` inside the virtualenv.

## Usage

Available configuration IDs:

- `rak6421-kit-environment-1`
- `rak6421-kit-environment-2`
- `rak6421-kit-industrial`
- `rak6421-kit-meshtastic`
- `rak6421-kit-meshtastic-hp`
- `rak6421-kit-wismesh-station`
- `rak6421-kit-wismesh-station-hp`


Running a certain configuration executes a subset of the available tests. A successful run looks like this:

```
$ ./run.sh rak6421-kit-industrial

Dependency virtualenv already available
Dependency i2cdetect already available
Dependency jq already available
Dependency lshw already available

CPU: Raspberry Pi 4 Model B Rev 1.4
CPU Serial Number: 10000000188741e8
Memory: 3,7Gi
Storage: 15G
Device EUI: e45f01FFFE17c624
OS: 13

testADC
testRAK12002
testRAK18001

Ran 3 tests.

OK
```

An unsuccessful run looks like this:

```
$ ./run.sh rak6421-kit-environment-1

testADC
testRAK1906
ASSERT:RAK1906 not found expected:<0> but was:<2>
shunit2:ERROR testRAK1906() returned non-zero return code.
testRAK12002
testRAK12019
ASSERT:RAK12019 not found expected:<0> but was:<2>
shunit2:ERROR testRAK12019() returned non-zero return code.

Ran 6 tests.

FAILED (failures=4)
```

You can also run `run-full-test.sh` with `--json` for a structured JSON report:

## EEPROM flashing guide

For step-by-step instructions to flash and verify RAK6421 HAT EEPROM (including I2C bus 0 setup, write-enable pin shorting, and `/proc/device-tree/hat/` checks), see:

- `EEPROM-FLASHING-GUIDE.md`
