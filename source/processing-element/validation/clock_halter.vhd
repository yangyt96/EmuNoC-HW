library ieee;
use ieee.std_logic_1164.all;
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

        i_ub_count_wen : in Std_logic;
        i_ub_count     : in Std_logic_vector(CNT_WIDTH - 1 downto 0);
        o_run_count    : out Std_logic_vector(CNT_WIDTH - 1 downto 0)
    );
end entity;

architecture implementation of clock_halter is
    -- Constants
    constant max_count : unsigned(CNT_WIDTH - 1 downto 0) := (others => '1');

    -- Signals
    signal run_count : unsigned(CNT_WIDTH - 1 downto 0);
    signal ub_count  : unsigned(CNT_WIDTH - 1 downto 0);
    signal halt      : Std_logic;
begin

    -- IO
    o_halt      <= halt;
    o_run_count <= Std_logic_vector(run_count);
    clkh        <= clk when halt = '0' else
        '0';

    -- Inner
    halt <= '1' when i_halt = '1' or run_count >= ub_count else
        '0';

    process (clk, rst)
    begin
        if rst = RST_LVL then
            run_count <= (others => '0');
            ub_count  <= (others => '0');
        elsif rising_edge(clk) then

            if i_ub_count_wen = '1' then
                ub_count <= unsigned(i_ub_count);
            end if;

            if run_count < ub_count and halt = '0' then
                run_count <= run_count + 1;
            end if;

            if run_count = max_count and ub_count = max_count then
                run_count <= (others => '0');
                ub_count  <= (others => '0');
            end if;

        end if;
    end process;

end implementation;