library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;
use work.NOC_3D_PACKAGE.all;
use work.TESTBENCH_PACKAGE.all;

entity fifo_tb is

end entity;

architecture behave of fifo_tb is

    signal clk     : Std_logic := '0';
    signal rst     : Std_logic := '1';
    signal counter : Integer   := 0;

    signal data_in    : Std_logic_vector(flit_size - 1 downto 0);
    signal data_out   : Std_logic_vector(flit_size - 1 downto 0);
    signal write_en   : Std_logic := '0';
    signal read_en    : Std_logic := '0';
    signal valid_data : Std_logic;

begin
    DUT : entity work.fifo
        generic map(
            buff_depth => 4
        )
        port map(
            clk        => clk,
            rst        => rst,
            write_en   => write_en,
            data_in    => data_in,
            read_en    => read_en,
            data_out   => data_out,
            valid_data => valid_data
        );

    data_in <= Std_logic_vector(to_unsigned(counter, data_in'length));

    process (clk)
    begin
        if rising_edge(clk) then

            if counter >= 1 and counter < 8 then
                write_en <= '1';
            elsif counter >= 20 and counter < 30 then
                write_en <= '1';
            elsif counter >= 31 and counter < 40 then
                write_en <= '1';
            else
                write_en <= '0';
            end if;

            if counter >= 10 and counter < 16 then
                read_en <= '1';
            elsif counter >= 20 and counter < 30 then
                read_en <= '1';
            elsif counter >= 30 and counter < 40 then
                read_en <= '1';
            else
                read_en <= '0';
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