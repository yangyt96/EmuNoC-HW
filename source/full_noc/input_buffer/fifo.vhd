-------------------------------------------------------------------------------
-- Title      : FiFo buffer regular (no moving of data in buffer;
--              for credit based flow-control) 
-- Project    : Modular, heterogenous 3D NoC
-------------------------------------------------------------------------------
-- File       : fifo.vhd
-- Author     : Lennart Bamberg  <bamberg@office.item.uni-bremen.de>
-- Company    : 
-- Created    : 2018-05-24
-- Last update: 2018-11-28
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Buffer to read or write one flit (credit-based flow ctrl)
--              when read_enable is set the first word is already fetched in 
--              the same clock cycle (NOT THE NEXT CYCLE!)
-------------------------------------------------------------------------------
-- Copyright (c) 2018 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-05-24  1.0      bamberg Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use work.NOC_3D_PACKAGE.all;

entity fifo is
  generic (
    buff_depth : integer := 6);         -- buffer depths
  port (
    data_in    : in  flit;              -- Data in
    write_en   : in  std_logic;         -- Write enable
    read_en    : in  std_logic;         -- Read enable
    clk, rst   : in  std_logic;
    data_out   : out flit;              -- Output data
    valid_data : out std_logic);        -- Buffer not empty
end entity fifo;

architecture rtl of fifo is
  signal read_pointer, write_pointer :
    unsigned(bit_width(buff_depth)-1 downto 0);
  type buffer_type is array (buff_depth-1 downto 0) of flit;
  signal fifo : buffer_type;
begin

  -- BUFFER + READ/WRITE POINTER
  process(clk, rst)
  begin
    if rst = RST_LVL then
      write_pointer <= (others => '0');
      read_pointer  <= (others => '0');
      fifo          <= (others => (others => '0'));
    elsif clk'event and clk = '1' then
      if write_en = '1' then
        fifo(to_integer(write_pointer)) <= data_in;
        write_pointer                   <= (write_pointer + 1) mod buff_depth;
      end if;
      if read_en = '1' then
        read_pointer <= (read_pointer + 1) mod buff_depth;
      end if;
    end if;
  end process;
  data_out <= fifo(to_integer(read_pointer));

  process(clk, rst)
  begin
    if rst = RST_LVL then
      valid_data <= '0';
    elsif clk = '1' and clk'event then
      if write_en = '1' then
        valid_data <= '1';
      elsif (write_pointer = ((read_pointer+1) mod buff_depth) and read_en = '1')
        or (buff_depth = 1 and read_en = '1') then
        valid_data <= '0';
      end if;
    end if;
  end process;
end architecture;
