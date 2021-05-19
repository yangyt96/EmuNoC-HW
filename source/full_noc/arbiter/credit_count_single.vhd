-------------------------------------------------------------------------------
-- Title      : Credit counter for one vc in an output port (physcial channel)
-- Project    : Modular, heterogenous 3D NoC
-------------------------------------------------------------------------------
-- File       : credit_count_single.vhd
-- Author     : Lennart Bamberg  <lennart@t440s>
-- Company    : 
-- Created    : 2018-11-19
-- Last update: 2018-11-28
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Uses increment and vc_write_tx to determine if another flit can
--              be written to the VC in the input prot of teh adjacent router.
-------------------------------------------------------------------------------
-- Copyright (c) 2018 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-11-19  1.0      lennart Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.NOC_3D_PACKAGE.all;

entity credit_count_single is
  generic (
    -- buffer space in output vc at the other router
    vc_depth_out : positive := 6
    );
  port(
    clk, rst     : in  std_logic;
    incr_rx      : in  std_logic;
    vc_write_tx  : in  std_logic;
    credit_avail : out std_logic);
end entity credit_count_single;


architecture rtl of credit_count_single is
  signal count_val        : unsigned(bit_width(vc_depth_out+1)-1 downto 0);
  signal credit_avail_int : std_logic;
begin  -- architecture rtl

  process(clk, rst)
  begin
    if rst = RST_LVL then
      count_val <= to_unsigned(vc_depth_out, count_val'length);
    elsif rising_edge(clk) then
      if incr_rx = '1' and vc_write_tx = '0' then
        count_val <= count_val +1;
      elsif incr_rx = '0' and vc_write_tx = '1' then
        count_val <= count_val - 1;
      end if;
    end if;
  end process;

  credit_avail_int <= '1' when count_val > 0 else '0';
  -- potential infinite loop if output is not pipelined!
  credit_avail     <= credit_avail_int or incr_rx;
  -- to avoid infinite loop ...
  -- credit_avail <= credit_avail_int;

end architecture rtl;
