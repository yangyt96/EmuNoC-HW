-------------------------------------------------------------------------------
-- Title      : Mux-based crossbar (full connectivity)
-- Project    : Modular, heterogenous 3D NoC
-------------------------------------------------------------------------------
-- File       : crossbar_full.vhd
-- Author     : Lennart Bamberg  <bamberg@office.item.uni-bremen.de>
-- Company    : 
-- Created    : 2018-10-24
-- Last update: 2018-11-28
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Crossbar to connect the inputs to the outputs with the help of
--              multiplexers (U-turns are avoided).
-------------------------------------------------------------------------------
-- Copyright (c) 2018 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-10-24  1.0      bamberg Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.math_real.all;
use ieee.numeric_std.all;
use work.NOC_3D_PACKAGE.all;

entity crossbar_full is
  generic(port_num : positive := 5);
  port (crossbar_in   : in  flit_vector(port_num-1 downto 0);
        crossbar_ctrl : in  std_logic_vector(
          port_num*bit_width(port_num-1)-1 downto 0);
        crossbar_out  : out flit_vector(port_num-1 downto 0));
end entity crossbar_full;

architecture rtl of crossbar_full is
  constant port_sel_width : positive := bit_width(port_num-1);  -- bits for the
                                                                -- crossbar_ctrl signal of
                                                                -- one output port
  type multiplexer_input_type is array (port_num-1 downto 0)
    of flit_vector(port_num-2 downto 0);
  signal multiplexer_input : multiplexer_input_type;
begin


  multiplexer_input(0) <= crossbar_in(port_num-1 downto 1);
  INPUT_GEN : for i in 1 to port_num-1 generate
  begin
    multiplexer_input(i) <= crossbar_in(i-1 downto 0)
                            & crossbar_in(port_num-1 downto i+1);
  end generate;

  MULT_GEN : for i in 0 to port_num-1 generate
  begin
    crossbar_out(i) <= multiplexer_input(i)(to_integer(
      unsigned(crossbar_ctrl((i+1)*port_sel_width-1 downto i*port_sel_width)))
                                            );
  end generate;

end architecture rtl;
