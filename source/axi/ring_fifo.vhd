-------------------------------------------------------------------------------
-- Title      :
-- Project    :
-------------------------------------------------------------------------------
-- File       : ring_fifo.vhd
-- Author     : Yee Yang Tan  <yee.yang.tan@ice.rwth-aachen.de>
-- Company    : RWTH Aachen University
-- Created    : 2021-05-22
-- Last update: 2021-05-22
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Circular FIFO.
--              The data can written to the FIFO at rising_edge(clk), i_wen='1'
--              and o_wvalid='1'.
--              The data can be read from the FIFO at rising_edge(clk), i_ren='1'
--              and o_rvalid='1'.
-------------------------------------------------------------------------------
-- Copyright (c) 2021
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2021-05-22  1.0      Yang    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.NOC_3D_PACKAGE.all;

entity ring_fifo is
    generic (
        BUFFER_DEPTH : Integer   := 6;
        DATA_WIDTH   : Integer   := 32;
        CNT_WIDTH    : Integer   := 3;  -- bit_width(BUFFER_DEPTH)
        RST_LVL      : Std_logic := '0' -- reset level
    );
    port (
        clk : in Std_logic;
        rst : in Std_logic;

        i_wdata  : in Std_logic_vector(DATA_WIDTH - 1 downto 0);
        i_wen    : in Std_logic;
        o_wvalid : out Std_logic; -- whenever the buffer can be written data, this will always be 1

        i_ren    : in Std_logic;
        o_rdata  : out Std_logic_vector(DATA_WIDTH - 1 downto 0);
        o_rvalid : out Std_logic; -- whenever the buffer contains data to be read, this will always be 1

        count : out Std_logic_vector(CNT_WIDTH - 1 downto 0) -- Indicate the amount of buffer can be written
    );
end entity ring_fifo;

architecture rtl of ring_fifo is
    type t_Memory is array (BUFFER_DEPTH - 1 downto 0) of Std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal memory : t_Memory;

    signal read_pointer  : Integer range 0 to BUFFER_DEPTH - 1;
    signal write_pointer : Integer range 0 to BUFFER_DEPTH - 1;
    signal counter       : Integer range 0 to BUFFER_DEPTH;

begin
    o_rdata <= memory(read_pointer) when counter /= 0 else
        (others => '0');
    o_rvalid <= '1' when counter > 0 else
        '0';
    o_wvalid <= '1' when counter < BUFFER_DEPTH else
        '0';

    count <= Std_logic_vector(to_unsigned(counter, CNT_WIDTH));

    process (clk, rst)
    begin
        if rst = RST_LVL then
            write_pointer <= 0;
            read_pointer  <= 0;
            memory        <= (others => (others => '0'));
        elsif rising_edge(clk) then

            if i_wen = '1' and counter < BUFFER_DEPTH then
                memory(write_pointer) <= i_wdata;
                write_pointer         <= (write_pointer + 1) mod BUFFER_DEPTH;
            end if;

            if i_ren = '1' and counter > 0 then
                read_pointer <= (read_pointer + 1) mod BUFFER_DEPTH;
            end if;

        end if;
    end process;

    process (clk, rst, i_wen, i_ren)
    begin
        if rst = RST_LVL then
            counter <= 0;
        elsif rising_edge(clk) then
            if i_wen = '1' and i_ren = '0' and counter < BUFFER_DEPTH then
                counter <= counter + 1;
            elsif i_wen = '0' and i_ren = '1' and counter > 0 then
                counter <= counter - 1;
            elsif i_wen = '1' and i_ren = '1' and counter = 0 then
                counter <= counter + 1;
            elsif i_wen = '1' and i_ren = '1' and counter = BUFFER_DEPTH then
                counter <= counter - 1;
            end if;
        end if;
    end process;

end architecture;