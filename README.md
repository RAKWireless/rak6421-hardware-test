# Hardware tests for RAK6421 kits

This is a shell script that uses shutil2 to perform unit tests on different predefined configurations based on a RAK6421. Different tests are run based on the different possible configurations. Conofiguration are defined by their configuration ID, a string that uniquely identifies the features in a device.

Current configuration IDs are:

```
$ ./run.sh 

Usage: ./run.sh <configuration_id>

Posible configuration_id values:
* rak6421-kit-environment-1
* rak6421-kit-environment-2
* rak6421-kit-industrial
* rak6421-kit-meshtastic
* rak6421-kit-meshtastic-hp
```

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

An unsuccessful run, on the contrary, looks like this (using a different kit id with different set of modules):

```
$ ./run.sh rak6421-kit-environment-1

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
testRAK1906
ASSERT:RAK1906 not found expected:<0> but was:<2>
shunit2:ERROR testRAK1906() returned non-zero return code.
testRAK12002
testRAK12019
ASSERT:RAK12019 not found expected:<0> but was:<2>
shunit2:ERROR testRAK12019() returned non-zero return code.
testRAK12047
ASSERT:RAK12047 not found expected:<0> but was:<2>
shunit2:ERROR testRAK12047() returned non-zero return code.
testRAK14003
ASSERT:RAK14003 not found expected:<0> but was:<2>
shunit2:ERROR testRAK14003() returned non-zero return code.

Ran 6 tests.

FAILED (failures=4)

```