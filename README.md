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
$ ./run.sh rak6421-kit-environment-1

Dependency virtualenv already available
Dependency lshw already available
Dependency jq already available
Installing required python packages

## TODO

Removing python packages

Ran 19 tests.

OK
```

An unsuccessful run, on the contrary, looks like this (requesting a RAK5148 that's not there):

```
$ ./rak739x_tests.sh rak6421-kit-environment-1

Dependency virtualenv already available
Dependency lshw already available
Dependency jq already available
Installing required python packages

# TODO

FAILED (failures=1)
```