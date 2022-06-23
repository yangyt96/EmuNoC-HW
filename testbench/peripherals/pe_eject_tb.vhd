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

entity pe_eject_tb is
    generic (
        RST_LVL    : Std_logic := '0';
        CLK_PERIOD : Time      := 1 ns
    );
end entity;

architecture behave of pe_eject_tb is
    -- System
    signal clk     : Std_logic := '1';
    signal rst     : Std_logic := RST_LVL;
    signal clk_cnt : Integer   := 0;

    -- Variables
    constant C_AXIS_TDATA_WIDTH : Integer := 32;

    -- Signals
    signal halt : Std_logic;

    signal fifo_rdata  : Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal fifo_ren    : Std_logic;
    signal fifo_rvalid : Std_logic;

    signal axis_tvalid : Std_logic;
    signal axis_tdata  : Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal axis_tstrb  : Std_logic_vector((C_AXIS_TDATA_WIDTH/8) - 1 downto 0);
    signal axis_tlast  : Std_logic;
    signal axis_tready : Std_logic;

begin
    -- decription of the
    -----------------------------------------------------------------------------
    -- 0~20 normal transaction and fill the output fifo without emptying it
    -- 20~40 normal transaction but the output fifo is full
    -- 40 empty the output fifo
    -- 45 empty the output fifo which is full again due to the data in period 20~40
    -- >50 : transaction with halt
    -- 66,67 where is the last flit transaction, it is halted
    -- 68 unhalt
    -- 69~79 halt again until the next ejection
    -- 77~89 ejection with initial halt

    halt <= '1' when
        (clk_cnt >= 53 and clk_cnt < 58) or
        (clk_cnt >= 66 and clk_cnt < 68) or
        (clk_cnt >= 69 and clk_cnt < 80) else
        '0';

    fifo_ren <= '1' when
        (clk_cnt = 40) or
        (clk_cnt = 45) else
        '0';

    -- Initiator
    initiator : entity work.M_AXIS_TRAFFIC_GEN
        generic map(
            flit_width           => C_AXIS_TDATA_WIDTH,
            srl_fifo_depth       => 200,
            inj_time_text        => "testdata/pe_eject/in/inj_time.txt",
            packet_length_text   => "testdata/pe_eject/in/pkt_len.txt",
            image_2_flits_text   => "testdata/pe_eject/in/flit_data.txt",
            inj_time_2_noc_text  => "testdata/pe_eject/out/inj_time.txt",
            C_M_AXIS_TDATA_WIDTH => C_AXIS_TDATA_WIDTH
        )
        port map(
            M_AXIS_ACLK    => clk,
            M_AXIS_ARESETN => rst,

            M_AXIS_TVALID => axis_tvalid,
            M_AXIS_TDATA  => axis_tdata,
            M_AXIS_TSTRB  => axis_tstrb,
            M_AXIS_TLAST  => axis_tlast,
            M_AXIS_TREADY => axis_tready
        );

    -- Instance
    DUT : entity work.pe_eject
        generic map(
            BUFFER_DEPTH       => 1,
            C_AXIS_TDATA_WIDTH => C_AXIS_TDATA_WIDTH,
            RST_LVL            => RST_LVL
        )
        port map(
            clk    => clk,
            rst    => rst,
            i_halt => halt,

            o_fifo_rdata  => fifo_rdata,
            i_fifo_ren    => fifo_ren,
            o_fifo_rvalid => fifo_rvalid,

            s_axis_tvalid => axis_tvalid,
            s_axis_tdata  => axis_tdata,
            s_axis_tstrb  => axis_tstrb,
            s_axis_tlast  => axis_tlast,
            s_axis_tready => axis_tready
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