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
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

entity clock_halter is
    generic (
        CNT_WIDTH : Integer   := 32;
        RST_LVL   : Std_logic := '0'
    );
    port (
        clk  : in Std_logic;
        rst  : in Std_logic;
        clkh : out Std_logic;

        i_halt : in Std_logic;
        o_halt : out Std_logic;
        o_run  : out Std_logic;

        i_ub_count_wen : in Std_logic;
        i_ub_count     : in Std_logic_vector(CNT_WIDTH - 1 downto 0);
        o_run_count    : out Std_logic_vector(CNT_WIDTH - 1 downto 0)
    );
end entity;

architecture implementation of clock_halter is
    signal run_count : unsigned(CNT_WIDTH - 1 downto 0);
    signal ub_count  : unsigned(CNT_WIDTH - 1 downto 0);
    signal halt      : Std_logic;
    signal run_flag  : Std_logic;

    signal clk_count  : unsigned(0 downto 0);
    signal inner_clk  : Std_logic;
    signal halt_delay : Std_logic;
begin
    -- IO
    o_halt <= halt;
    clkh   <= inner_clk when halt = '0' and and_reduce(Std_logic_vector(clk_count)) = '1' else
        '0';

    o_run_count <= Std_logic_vector(run_count);
    o_run       <= '1' when (run_count < ub_count or run_flag = '1') else
        '0';

    -- Internal
    halt <= '1' when (i_halt = '1' or run_count >= ub_count) else
        '0';

    inner_clk <= clk when clk_count(0) = '1' and halt = '0' and halt_delay = '0' else
        '0';

    process (clk, rst)
    begin
        if rst = RST_LVL then
            clk_count <= (others => '0');
        elsif rising_edge(clk) then
            if halt = '0' and halt_delay = '0' then
                clk_count <= clk_count + 1;
            else
                clk_count <= (others => '0');
            end if;
        end if;
    end process;

    process (clk, rst)
    begin
        if rst = RST_LVL then
            ub_count   <= (others => '0');
            run_flag   <= '0';
            halt_delay <= '0';
            run_count  <= (others => '0');
        elsif rising_edge(clk) then

            -- set upper bound
            if i_ub_count_wen = '1' then
                ub_count <= unsigned(i_ub_count);
            end if;

            -- flag for 1 cycle to know that it is assigned
            if i_ub_count_wen = '1' then
                run_flag <= '1';
            else
                run_flag <= '0';
            end if;

            -- count up when no halted
            if run_count < ub_count and halt = '0' and and_reduce(Std_logic_vector(clk_count)) = '1' then
                run_count <= run_count + 1;
            elsif i_ub_count_wen = '1' and unsigned(i_ub_count) < run_count then
                -- run_count <= (others => '0');
                run_count <= unsigned(i_ub_count);
            end if;

            halt_delay <= halt;

        end if;
    end process;

end implementation;