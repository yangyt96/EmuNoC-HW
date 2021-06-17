

## Install latest GHDL
```
make install
```

## Run testbench
```
make TEST_NAME=<testbench name>
```

Example to test the master axi stream network interface:
```
make TEST_NAME=m_axis_ni_tb
```

## View the simulation signal with gtkwave
```
make view TEST_NAME=m_axis_ni_tb
```

## Main test name
- m_axis_ni_tb
- s_axis_ni_tb
- top_tb