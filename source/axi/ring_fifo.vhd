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
--              The data can written to the FIFO at rising_edge(clk), write_en='1'
--              and write_valid='1'.
--              The data can be read from the FIFO at rising_edge(clk), read_en='1'
--              and read_valid='1'.
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

entity ring_fifo is
    generic (
        BUFFER_DEPTH : Integer   := 6;
        DATA_WIDTH   : Integer   := 32;
        RST_LVL      : Std_logic := '0' -- reset level
    );
    port (
        clk : in Std_logic;
        rst : in Std_logic;

        data_in     : in Std_logic_vector(DATA_WIDTH - 1 downto 0);
        write_en    : in Std_logic;
        write_valid : out Std_logic; -- whenever the buffer can be written data, this will always be 1

        read_en    : in Std_logic;
        data_out   : out Std_logic_vector(DATA_WIDTH - 1 downto 0);
        read_valid : out Std_logic; -- whenever the buffer contains data to be read, this will always be 1

        count : out Integer -- Indicate the amount of buffer can be written
    );
end entity ring_fifo;

architecture rtl of ring_fifo is
    type t_Memory is array (BUFFER_DEPTH - 1 downto 0) of Std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal memory : t_Memory;

    signal read_pointer  : Integer range 0 to BUFFER_DEPTH - 1;
    signal write_pointer : Integer range 0 to BUFFER_DEPTH - 1;
    signal counter       : Integer range 0 to BUFFER_DEPTH;

begin
    data_out <= memory(read_pointer) when counter /= BUFFER_DEPTH else
        (others => '0');
    read_valid <= '1' when counter < BUFFER_DEPTH else
        '0';
    write_valid <= '1' when counter > 0 else
        '0';
    count <= counter;

    process (clk, rst)
    begin
        if rst = RST_LVL then
            write_pointer <= 0;
            read_pointer  <= 0;
            memory        <= (others => (others => '0'));
        elsif rising_edge(clk) then

            if write_en = '1' and counter > 0 then
                memory(write_pointer) <= data_in;
                write_pointer         <= (write_pointer + 1) mod BUFFER_DEPTH;
            end if;

            if read_en = '1' and counter < BUFFER_DEPTH then
                read_pointer <= (read_pointer + 1) mod BUFFER_DEPTH;
            end if;

        end if;
    end process;

    process (clk, rst, write_en, read_en)
    begin
        if rst = RST_LVL then
            counter <= BUFFER_DEPTH;
        elsif rising_edge(clk) then
            if write_en = '1' and read_en = '0' and counter > 0 then
                counter <= counter - 1;
            elsif write_en = '0' and read_en = '1' and counter < BUFFER_DEPTH then
                counter <= counter + 1;
            elsif write_en = '1' and read_en = '1' and counter = BUFFER_DEPTH then
                counter <= counter - 1;
            elsif write_en = '1' and read_en = '1' and counter = 0 then
                counter <= counter + 1;
            end if;
        end if;
    end process;

end architecture;