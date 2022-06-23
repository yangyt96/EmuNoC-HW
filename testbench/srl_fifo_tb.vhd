------------------------------------------------------------------
-- COPYRIGHT(c) 2022
-- INSTITUTE FOR COMMUNICATION TECHNOLOGIES AND EMBEDDED SYSTEMS
-- RWTH AACHEN
-- GERMANY
--
-- This confidential and proprietary software may be used, copied,
-- modified, merged, published or distributed according to the
-- permissions and/or limitations granted by an authorizing license
-- agreement.
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- Author: 1. Tan Yee Yang (tan@ice.rwth-aachen.de)
--         2. Jan Moritz Joseph (joseph@ice.rwth-aachen.de)
------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;
use work.NOC_3D_PACKAGE.all;
use work.TESTBENCH_PACKAGE.all;

entity srl_fifo_tb is

end entity;

architecture behave of srl_fifo_tb is

    signal clk     : Std_logic := '0';
    signal rst     : Std_logic := '1';
    signal counter : Integer   := 0;

    signal data_in    : Std_logic_vector(flit_size - 1 downto 0);
    signal data_out   : Std_logic_vector(flit_size - 1 downto 0);
    signal write_en   : Std_logic := '0';
    signal read_en    : Std_logic := '0';
    signal valid_data : Std_logic;

    signal buffer_full  : Std_logic;
    signal buffer_empty : Std_logic;

begin
    DUT : entity work.srl_fifo
        generic map(
            buffer_depth => 9
        )
        port map(
            clk          => clk,
            rst          => rst,
            write_en     => write_en,
            data_in      => data_in,
            read_en      => read_en,
            data_out     => data_out,
            buffer_full  => buffer_full,
            buffer_empty => buffer_empty
        );

    data_in <= Std_logic_vector(to_unsigned(counter, data_in'length));

    process (clk)
    begin
        if rising_edge(clk) then
            if counter = 5 then
                write_en <= '1';
            end if;

            if counter = 3 then
                read_en <= '1';
            end if;

        end if;

    end process;
    -------------------------------------------------------------------
    ------------------ RST & CLK & INCR generation --------------------

    clk <= not(clk) after clk_period/2;

    p_rst : process
    begin
        rst <= RST_LVL;
        wait for (clk_period * 2);
        rst <= not(RST_LVL);
        wait;
    end process;

    p_counter : process (clk, rst)
    begin
        if rising_edge(clk) then
            if (rst = RST_LVL) then
                counter <= 0;
            else
                counter <= counter + 1;
            end if;
        end if;
    end process;

end architecture;