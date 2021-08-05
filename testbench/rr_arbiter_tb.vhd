library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

entity rr_arbiter_tb is
    generic (
        RST_LVL    : Std_logic := '0';
        CLK_PERIOD : Time      := 1 ns
    );
end entity;

architecture behave of rr_arbiter_tb is
    -- System
    signal clk     : Std_logic := '1';
    signal rst     : Std_logic := RST_LVL;
    signal clk_cnt : Integer   := 0;

    -- Constant
    constant CNT : Integer := 6;

    -- Signals

    signal req : Std_logic_vector(CNT - 1 downto 0);
    signal ack : Std_logic;

begin

    process
    begin
        req <= (others => '0');
        ack <= '0';

        wait until rst /= RST_LVL;

        req <= (0 => '1', others => '0');
        wait until rising_edge(clk);

        ack <= '1';
        wait until rising_edge(clk);
        ack <= '0';
        wait until rising_edge(clk);
        ack <= '1';
        wait until rising_edge(clk);
        ack <= '0';

        req <= (1 => '1', others => '0');
        wait until rising_edge(clk);

        ack <= '1';
        wait until rising_edge(clk);
        ack <= '0';
        req <= (0 => '1', 1 => '1', CNT - 1 => '1', others => '0');
        wait until rising_edge(clk);

        ack <= '1';
        wait until rising_edge(clk);
        ack <= '0';

        wait;
    end process;

    DUT_rr_arbiter : entity work.rr_arbiter
        generic map(
            CNT => CNT
        )
        port map(
            clk => clk,
            rst => rst,

            req => req,
            ack => ack
        );

    DUT_rr_arbiter_no_delay : entity work.rr_arbiter_no_delay
        generic map(
            CNT => CNT
        )
        port map(
            clk => clk,
            rst => rst,

            req => req,
            ack => ack
        );

    DUT_rr_arbiter_clz : entity work.rr_arbiter_clz
        generic map(
            CNT => CNT
        )
        port map(
            clk => clk,
            rst => rst,

            req => req,
            ack => ack
        );

    -- System
    clk <= not(clk) after CLK_PERIOD/2;

    proc_clk_cnt : process (clk, rst)
    begin
        if rst = RST_LVL then
            clk_cnt <= 0;
        elsif rising_edge(clk) then
            clk_cnt <= clk_cnt + 1;
        end if;
    end process;

    proc_rst : process
    begin
        rst <= RST_LVL;
        wait for (CLK_PERIOD * 2);
        rst <= not(RST_LVL);
        wait;
    end process proc_rst;

end architecture;