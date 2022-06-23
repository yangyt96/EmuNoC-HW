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

entity pe_inject_tb is
    generic (
        RST_LVL    : Std_logic := '0';
        CLK_PERIOD : Time      := 1 ns
    );
end entity;

architecture behave of pe_inject_tb is
    -- System
    signal clk     : Std_logic := '1';
    signal rst     : Std_logic := RST_LVL;
    signal clk_cnt : Integer   := 0;

    -- Variables
    constant C_AXIS_TDATA_WIDTH : Integer := 32;

    -- Signals
    signal halt : Std_logic;

    signal fifo_wdata  : Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal fifo_wen    : Std_logic;
    signal fifo_wvalid : Std_logic;

    signal axis_tvalid : Std_logic;
    signal axis_tdata  : Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal axis_tstrb  : Std_logic_vector((C_AXIS_TDATA_WIDTH/8) - 1 downto 0);
    signal axis_tlast  : Std_logic;
    signal axis_tready : Std_logic;

begin

    axis_tready <= '1' when (clk_cnt > 41 and clk_cnt < 50) else
        axis_tvalid;

    halt <= '1' when
        (clk_cnt > 25 and clk_cnt < 27) or
        (clk_cnt > 41 and clk_cnt < 50) or
        (clk_cnt > 70 and clk_cnt < 80) or
        (clk_cnt > 84 and clk_cnt < 95)
        else
        '0';

    process
    begin
        -- reset init
        fifo_wdata <= (others => '0');
        fifo_wen   <= '0';

        wait until rst /= RST_LVL;

        -- test normal cycle
        wait until clk_cnt = 1;
        fifo_wdata <= Std_logic_vector(to_unsigned(10, C_AXIS_TDATA_WIDTH));
        fifo_wen   <= '1';
        wait until rising_edge(clk);
        fifo_wdata <= (others => '0');
        fifo_wen   <= '0';

        -- test with halt
        wait until clk_cnt = 20;
        fifo_wdata <= Std_logic_vector(to_unsigned(10, C_AXIS_TDATA_WIDTH));
        fifo_wen   <= '1';
        wait until rising_edge(clk);
        fifo_wdata <= (others => '0');
        fifo_wen   <= '0';

        -- test with halt = '1' and axis_tready latch to '1'
        wait until clk_cnt = 40;
        fifo_wdata <= Std_logic_vector(to_unsigned(10, C_AXIS_TDATA_WIDTH));
        fifo_wen   <= '1';
        wait until rising_edge(clk);
        fifo_wdata <= (others => '0');
        fifo_wen   <= '0';

        -- test with halt = '1' at other state apart from s_WORK
        wait until clk_cnt = 70;
        fifo_wdata <= Std_logic_vector(to_unsigned(5, C_AXIS_TDATA_WIDTH));
        fifo_wen   <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        fifo_wdata <= (others => '0');
        fifo_wen   <= '0';

        wait;
    end process;

    -- process (clk, rst)
    -- begin
    --     if rst = RST_LVL then
    --         halt        <= '0';
    --         fifo_wdata  <= (others => '0');
    --         fifo_wen    <= '0';
    --         axis_tready <= '0';
    --     elsif rising_edge(clk) then

    --         if clk_cnt < 5 then
    --             halt       <= '0';
    --             fifo_wdata <= Std_logic_vector(to_unsigned(clk_cnt + 5, C_AXIS_TDATA_WIDTH));
    --             fifo_wen   <= '1' when fifo_wvalid = '1' else
    --                 '0';
    --             axis_tready <= axis_tvalid;
    --         else
    --             halt        <= '0';
    --             fifo_wdata  <= (others => '0');
    --             fifo_wen    <= '0';
    --             axis_tready <= axis_tvalid;
    --         end if;

    --     end if;
    -- end process;

    -- halt <= '1' when (clk_cnt mod 4) /= 0 else
    --     '0';

    -- fifo_wdata <= Std_logic_vector(to_unsigned(clk_cnt, C_AXIS_TDATA_WIDTH));
    -- fifo_wen   <= '1' when (clk_cnt mod 5) = 0 else
    --     '0';

    -- axis_tready <= axis_tvalid;

    -- Instance
    DUT : entity work.pe_inject
        generic map(
            BUFFER_DEPTH       => 32,
            C_AXIS_TDATA_WIDTH => C_AXIS_TDATA_WIDTH,
            RST_LVL            => RST_LVL
        )
        port map(
            clk    => clk,
            rst    => rst,
            i_halt => halt,

            i_fifo_wdata  => fifo_wdata,
            i_fifo_wen    => fifo_wen,
            o_fifo_wvalid => fifo_wvalid,

            m_axis_tvalid => axis_tvalid,
            m_axis_tdata  => axis_tdata,
            m_axis_tstrb  => axis_tstrb,
            m_axis_tlast  => axis_tlast,
            m_axis_tready => axis_tready
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