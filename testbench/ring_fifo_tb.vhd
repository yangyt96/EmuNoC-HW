library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.NOC_3D_PACKAGE.all;
use work.TESTBENCH_PACKAGE.all;

entity ring_fifo_tb is
end entity;

architecture behave of ring_fifo_tb is

    signal clk     : Std_logic := '0';
    signal rst     : Std_logic := '1';
    signal counter : Integer   := 0;

    signal data_in     : Std_logic_vector(32 - 1 downto 0);
    signal data_out    : Std_logic_vector(32 - 1 downto 0);
    signal write_en    : Std_logic := '0';
    signal read_en     : Std_logic := '0';
    signal read_valid  : Std_logic;
    signal write_valid : Std_logic;
    signal count       : Integer;

begin
    DUT : entity work.ring_fifo
        generic map(
            BUFFER_DEPTH => 4
        )
        port map(
            clk => clk,
            rst => rst,

            i_wdata  => data_in,
            i_wen    => write_en,
            o_wvalid => write_valid,

            o_rdata  => data_out,
            i_ren    => read_en,
            o_rvalid => read_valid

        );

    data_in <= Std_logic_vector(to_unsigned(counter, data_in'length));

    -- time 0 - 10 : test write all
    -- time 10 -20 : test read all
    -- time 20 - 30: first write then read at the same time
    -- time 30 - 40 first read then write at the same time

    process (clk)
    begin
        if rising_edge(clk) then

            if counter >= 1 and counter < 8 then
                write_en <= '1';
            elsif counter >= 20 and counter < 30 then
                write_en <= '1';
            elsif counter >= 35 and counter < 40 then
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
        if rst = RST_LVL then
            counter <= 0;
        elsif rising_edge(clk) then
            counter <= counter + 1;
        end if;
    end process;

end architecture;