library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

entity clock_halter_tb is
    generic (
        RST_LVL    : Std_logic := '0';
        CLK_PERIOD : Time      := 1 ns
    );
end entity;

architecture behave of clock_halter_tb is
    -- System
    signal clk     : Std_logic := '1';
    signal rst     : Std_logic := RST_LVL;
    signal clk_cnt : Integer   := 0;

    -- Constants
    constant CNT_WIDTH : Integer := 64;

    -- Signals
    signal clk_halt  : Std_logic;
    signal ubcnt_wen : Std_logic;
    signal ubcnt     : Std_logic_vector(CNT_WIDTH - 1 downto 0);
    signal runcnt    : Std_logic_vector(CNT_WIDTH - 1 downto 0);
    signal in_halt   : Std_logic;
    signal out_halt  : Std_logic;

begin
    process (clk, rst)
    begin
        if rising_edge(clk) then

            if (clk_cnt mod 15) = 0 then
                ubcnt     <= (others => '1');
                ubcnt_wen <= '1';
            else
                ubcnt     <= (others => '0');
                ubcnt_wen <= '0';
            end if;

            if (clk_cnt mod 3) = 0 then
                in_halt <= '1';
            else
                in_halt <= '0';
            end if;
        end if;
    end process;

    DUT : entity work.clock_halter
        generic map(
            CNT_WIDTH => CNT_WIDTH,
            RST_LVL   => RST_LVL
        )
        port map(
            clk => clk,
            rst => rst,

            i_halt => in_halt,
            o_halt => out_halt,
            clkh   => clk_halt,

            i_ub_count_wen => ubcnt_wen,
            i_ub_count     => ubcnt,
            o_run_count    => runcnt
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