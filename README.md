# EmuNoC Hardware
This is the hardware of EmuNoC and it is a hybrid emulation prototype to accelerate the verification of Ratatoskr router. This prototype can be configured for different types of NoC IP.

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


## Fix: Ratatoskr router

### fix 1: full_noc

1. vc_depth_out_array           => ((others => max_packet_len),

### fix 2: noc_3d_package

1. func 1

  function bit_width(x : positive) return positive is
  begin
    assert (x > 1) report "Encoding for less than two values is not possible"
      severity failure;
    return positive(ceil(log2(real(x))));
  end function;

  to

  function bit_width(x : Positive) return Positive is
  begin
    if (x > 1) then
      return Positive(ceil(log2(real(x))));
    elsif x = 1 then
      return 1;
    else
      return 0;
    end if;
  end function;

2. positive(ceil(log2(real(max_z_dim))))-1

  to

  0

  for max_z_dim == 1


### fix 3: switch_allocator.vhd

1. rr_arbiter at vc allocation

    -- ack   => switch_ack(i),
    ack   => '1',

2. one_hot2int --> count_trail_zero

  winner := lr + one_hot2int(channel_grant(ur downto lr));
  to
  winner := lr + count_trail_zero(channel_grant(ur downto lr)) mod vc_num_out_vec(i);

  function count_trail_zero(var : Std_logic_vector) return Integer is
    variable tmp                  : Std_logic_vector(var'length - 1 downto 0) := var;
  begin
    for i in 0 to tmp'length - 1 loop
      if tmp(i) = '1' then
        return i;
      end if;
    end loop;
    return tmp'length;
  end function;


## Requires automation
1. file: top_axis_validation.vhd
2. VARS: ROUTER_CREDIT => 2,

## Fit to FPGA
1. file:
-> entity:
a. clock_halter -> clock_halter_xilinx
2. fifo.vhd in full_noc needs to use Vivado FIFO IP
3. ring_fifo.vhd

# TODO
1. Change it to synthesizable code. Follow: https://www.youtube.com/watch?v=BIqLk23hE90
2. Use OSVVM to automate the verification. Checkout: https://github.com/OSVVM/OSVVM
