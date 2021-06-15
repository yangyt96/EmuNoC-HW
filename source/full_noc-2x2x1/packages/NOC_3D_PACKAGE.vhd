-------------------------------------------------------------------------------
-- Title      : Package for modular, heterogenous 3D NoC
-- Project    : Modular, heterogenous 3D NoC
-------------------------------------------------------------------------------
-- File       : NOC_3D_PACKAGE.vhd
-- Author     : Lennart Bamberg  <bamberg@office.item.uni-bremen.de>
-- Company    :
-- Created    : 2018-10-24
-- Last update: 2018-11-28
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Package including the constants, types, function and components
--              required for the modular, heterogenous 3D NoC.
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-10-24  1.0      bamberg Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use ieee.numeric_std.all;

package NOC_3D_PACKAGE is
  --------------------------------------------------------------------------------
  ---------------------- CONSTANTS -----------------------------------------------
  --------------------------------------------------------------------------------

  ---- The following lines can be edited to change the router architecture
  ---- With VHDL2008 these should be generic of the package
  constant flit_size      : Positive := 32; -- Flit size in bits
  constant max_vc_num     : Positive := 2;  -- Max VCs of an input phy. channel
  constant max_vc_num_out : Positive := 2;  -- Max VCs of an op. channel
  constant max_x_dim      : Positive := 2;  -- Max number of routers in X-dim
  constant max_y_dim      : Positive := 2;  -- Max number of routers in Y-dim
  constant max_Z_dim      : Positive := 1;  -- Max number of routers in Z-dim
  constant max_packet_len : Positive := 31; -- Max packet_length in flits
  -- (ideal is 2^N-1)
  constant max_port_num : Positive := 5; -- Max number of router port
  -- Which port-num belongs to witch port
  constant int_local : Natural := 0;
  constant int_north : Natural := 1;
  constant int_east  : Natural := 2;
  constant int_south : Natural := 3;
  constant int_west  : Natural := 4;
  constant int_up    : Natural := 5;
  constant int_down  : Natural := 6;

  -- General contants for the used technology
  constant RST_LVL : Std_logic := '0'; -- Level to acticate reset ('1' =>
  -- active high; '0' => active low)

  -- Derived constants that cannot be edited (there values is calculated later
  -- in the body)
  constant packet_len_width : Positive; -- Header Bits req. for packet-length
  constant x_addr_width     : Positive; -- Header Bits req. for Dest. Addr X
  constant y_addr_width     : Positive; -- Header Bits req. for Dest. Addr Y
  constant z_addr_width     : Positive; -- Header Bits req. for Dest. Addr Z
  --------------------------------------------------------------------------------
  --------------------- (SUB)TYPES -----------------------------------------------
  --------------------------------------------------------------------------------

  -- General
  type integer_vec is array (Natural range <>) of Integer;
  type integer_array is array (Natural range <>, Natural range <>) of Integer;

  -- Flit related
  subtype flit is Std_logic_vector(flit_size - 1 downto 0);
  type flit_vector is array (Natural range <>) of
  Std_logic_vector(flit_size - 1 downto 0);

  -- Virtual channel related
  subtype vc_status_vec is Std_logic_vector(max_vc_num - 1 downto 0);
  subtype vc_status_vec_enc is Std_logic_vector(
  Positive(ceil(log2(real(max_vc_num)))) - 1 downto 0);
  type vc_status_array is array (Natural range <>) of vc_status_vec;
  type vc_status_array_enc is array (Natural range <>) of vc_status_vec_enc;
  subtype vc_prop_int is integer_vec(0 to max_vc_num - 1); -- integer vc
  -- propoerties
  -- (e.g. depth)
  type vc_prop_int_array is array (Natural range <>) of vc_prop_int;

  -- Full NoC related
  -- Head Flit related
  type header_inf is record
    packet_length : Std_logic_vector(Positive(ceil(log2(real(max_packet_len + 1)))) - 1 downto 0);
    ------------------------------- (packet_len_width-1 downto 0)
    x_dest : Std_logic_vector(Positive(ceil(log2(real(max_x_dim)))) - 1 downto 0);
    ------------------------------- (x_addr_width-1 downto 0)
    y_dest : Std_logic_vector(Positive(ceil(log2(real(max_y_dim)))) - 1 downto 0);
    ------------------------------- (y_addr_width-1 downto 0)
    z_dest : Std_logic_vector(0 downto 0);
    --------------------------------- (z_addr_width-1 downto 0)
  end record;
  type header_inf_vector is array (Natural range <>) of header_inf;

  -- Head Flit related
  type address_inf is record
    x_dest : Std_logic_vector(Positive(ceil(log2(real(max_x_dim)))) - 1 downto 0);
    ------------------------------- (x_addr_width-1 downto 0)
    y_dest : Std_logic_vector(Positive(ceil(log2(real(max_y_dim)))) - 1 downto 0);
    ------------------------------- (y_addr_width-1 downto 0)
    z_dest : Std_logic_vector(0 downto 0);
    --------------------------------- (z_addr_width-1 downto 0)
  end record;
  ---------------------------------------------------------------------------------
  ------------------ FUNCTION-DEC. ------------------------------------------------
  ---------------------------------------------------------------------------------

  -- Bits required to encode x different values
  function bit_width(x : Integer) return Positive;

  -- Transfer std_logic_vector (intp. unsigned) to natural integer
  function slv2int(x : Std_logic_vector) return Natural;

  -- Transfer "one_hot" to std_logic_vector
  function one_hot2slv(x : Std_logic_vector) return Std_logic_vector;

  -- Transfer "one_hot" to natural integer
  function one_hot2int(x : Std_logic_vector) return Natural;

  -- Get the req. information from the head_flit
  function get_header_inf(x : Std_logic_vector) return header_inf;

  -- Get the dest. adress from the header information
  function extract_address_inf(x : header_inf) return address_inf;

  -- Sum all values of an integer array
  function int_vec_sum(x : integer_vec) return Integer;

  -- Upper range
  function upper_range(x : integer_vec; i : Natural) return Natural;

  -- Lower range
  function lower_range(x : integer_vec; i : Natural) return Natural;

  -- Get the i^th slice of x (slice sized defined by vec)
  function slice(x : Std_logic_vector;
    vec              : integer_vec;
    i                : Natural
  ) return Std_logic_vector;

  -- Return the index of a value in an array
  function ret_index(x : integer_vec; i : Integer) return Integer;

  -- Return the maximum value of an array
  function ret_max(x : integer_vec) return Integer;

end package NOC_3D_PACKAGE;
--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!--
--------------------- BODY -------------------------------------------------------
--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!--
package body NOC_3D_PACKAGE is
  -----------------------------------------------------------------------------------
  ------------------- FUNCTION-DEC. -------------------------------------------------
  -----------------------------------------------------------------------------------

  -- Bits required to encode x different values
  function bit_width(x : Integer) return Positive is
  begin
    if (x > 1) then
      return Positive(ceil(log2(real(x))));
    elsif x = 1 then
      return 1;
    else
      return 0;
    end if;
  end function;

  -- Derived constants using function bit_width
  constant packet_len_width : Positive := bit_width(max_packet_len + 1);
  constant x_addr_width     : Positive := bit_width(max_x_dim);
  constant y_addr_width     : Positive := bit_width(max_y_dim);
  constant z_addr_width     : Positive := bit_width(max_z_dim);
  -- Transfer "std_logic_vector" (intp. unsigned) to "natural integer"
  function slv2int(x : Std_logic_vector) return Natural is
  begin
    return to_integer(unsigned(x));
  end function;
  -- Transfer "one_hot" to "std_logic_vector"
  function one_hot2slv(x : Std_logic_vector) return Std_logic_vector is
    variable var           : Std_logic_vector(bit_width(x'length) - 1 downto 0);
  begin
    var := (others => '0');
    for i in x'range loop
      if x(i) = '1' then
        -- use "or" to avoid synthesizing a priority decoder
        var := var or Std_logic_vector(to_unsigned(i, var'length));
      end if;
    end loop;
    return var;
  end function;
  -- Transfer "one_hot" to natural
  function one_hot2int(x : Std_logic_vector) return Natural is
    variable var           : unsigned(bit_width(x'length) - 1 downto 0);
  begin
    var := (others => '0');
    for i in x'range loop
      if x(i) = '1' then
        -- use "or" to avoid synthesizing a priority decoder
        var := var or to_unsigned(i, var'length);
      end if;
    end loop;
    return to_integer(var);
  end function;

  -- The following unit has to be change if the  header structure is changes.
  -- Currently we assume that the LSBs are the packet-length: the next higher bits
  -- are the X, Y and then Z address. All higher value bith are currently used by higher
  -- layers. Important sofar is that is that the req. header informations
  -- (addr, packet_length) are not allowed to take mor then "flit_size" bits.
  function get_header_inf(x : Std_logic_vector) return header_inf is
    variable y                : header_inf;
    variable offset           : Integer;
  begin
    y.packet_length := x(packet_len_width - 1 downto 0);
    offset          := packet_len_width;
    y.x_dest        := x(x_addr_width + offset - 1 downto offset);
    offset          := offset + x_addr_width;
    y.y_dest        := x(y_addr_width + offset - 1 downto offset);
    offset          := offset + y_addr_width;
    y.z_dest        := x(z_addr_width + offset - 1 downto offset);
    return y;
  end function;

  -- Get the address information from a header
  function extract_address_inf(x : header_inf) return address_inf is
    variable y                     : address_inf;
  begin
    y.x_dest := x.x_dest;
    y.y_dest := x.y_dest;
    y.z_dest := x.z_dest;
    return y;
  end function;
  -- Sum of integer array
  function int_vec_sum(x : integer_vec) return Integer is
    variable var           : Integer;
  begin
    var := 0;
    for i in x'range loop
      var := var + x(i);
    end loop;
    return var;
  end function;

  -- Uper range
  function upper_range(x : integer_vec; i : Natural) return Natural is
    variable var : Natural;
  begin
    var := 0;
    for it in 0 to i loop
      var := var + x(it);
    end loop;
    return var - 1;
  end function;

  -- Lower range
  function lower_range(x : integer_vec; i : Natural) return Natural is
    variable var : Natural;
  begin
    var := 0;
    for it in 0 to i loop
      var := var + x(it);
    end loop;
    return var - x(i);
  end function;
  -- Slice of vector
  function slice(x : Std_logic_vector; vec : integer_vec;
    i : Natural) return Std_logic_vector is
  begin
    return x(upper_range(vec, i) downto lower_range(vec, i));
  end function;

  -- Return the position in an array
  function ret_index(x : integer_vec; i : Integer) return Integer is
    variable result : Integer := - 1;
  begin
    for index in 0 to x'length - 1 loop
      if x(x'left + index) = i then
        result := index;
      end if;
    end loop;
    if result =- 1 then
      assert false report "INDEX IS NOT FOUND" severity error;
    end if;
    return result;
  end function;

  -- Return the maximum value of an array
  function ret_max(x : integer_vec) return Integer is
    variable max_value : Integer := 0;
  begin
    for index in 0 to x'length - 1 loop
      if x(x'left + index) > max_value then
        max_value := x(x'left + index);
      end if;
    end loop;
    return max_value;
  end function;

end package body NOC_3D_PACKAGE;