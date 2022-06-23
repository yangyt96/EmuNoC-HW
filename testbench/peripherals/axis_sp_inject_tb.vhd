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

use work.NOC_3D_PACKAGE.all;

entity axis_sp_inject_tb is
    generic (
        RST_LVL    : Std_logic := RST_LVL;
        CLK_PERIOD : Time      := 1 ns
    );
end entity;

architecture behave of axis_sp_inject_tb is
    -- System
    signal clk     : Std_logic := '0';
    signal rst     : Std_logic := RST_LVL;
    signal clk_cnt : Integer   := 0;

    -- Constants
    constant C_AXIS_TDATA_WIDTH : Integer := flit_size;
    constant PE_NUM             : Integer := max_x_dim * max_y_dim * max_z_dim;

    -- Signals
    signal axis_tvalid : Std_logic;
    signal axis_tdata  : Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal axis_tstrb  : Std_logic_vector((C_AXIS_TDATA_WIDTH/8) - 1 downto 0);
    signal axis_tlast  : Std_logic;
    signal axis_tready : Std_logic;

    signal fifo_wdata   : Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal fifos_wen    : Std_logic_vector(PE_NUM - 1 downto 0);
    signal fifos_wvalid : Std_logic_vector(PE_NUM - 1 downto 0);

    signal fifos_rdata  : flit_vector(PE_NUM - 1 downto 0);
    signal fifos_ren    : Std_logic_vector(PE_NUM - 1 downto 0);
    signal fifos_rvalid : Std_logic_vector(PE_NUM - 1 downto 0);

    signal clk_halt_in  : Std_logic := '0';
    signal ub_count_wen : Std_logic;
    signal ub_count     : Std_logic_vector(31 downto 0);
    signal noc_count    : Std_logic_vector(31 downto 0);

begin
    clk_halt_in <= '1' when (clk_cnt mod 3) = 0 else
        '0';

    process (clk)
    begin
        if rising_edge(clk) then
            fifos_ren <= fifos_rvalid;
        end if;
    end process;

    -- initiator
    initiator : entity work.M_AXIS_TRAFFIC_GEN
        generic map(
            flit_width           => C_AXIS_TDATA_WIDTH,
            srl_fifo_depth       => 200,
            inj_time_text        => "testdata/axis_validation/in/inj_time.txt",
            packet_length_text   => "testdata/axis_validation/in/pkt_len.txt",
            image_2_flits_text   => "testdata/axis_validation/in/flit_data.txt",
            inj_time_2_noc_text  => "testdata/axis_validation/out/inj_time.txt",
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

    inst_clock_halter : entity work.clock_halter
        generic map(
            CNT_WIDTH => 32,
            RST_LVL   => RST_LVL
        )
        port map(
            clk => clk,
            rst => rst,
            -- clkh =>

            i_halt => clk_halt_in,
            -- o_halt : out Std_logic;

            i_ub_count_wen => ub_count_wen,
            i_ub_count     => ub_count,
            o_run_count    => noc_count
        );

    -- DUT
    DUT : entity work.axis_sp_inject
        generic map(
            CNT_WIDTH => 32
        )
        port map(
            clk => clk,
            rst => rst,

            s_axis_tvalid => axis_tvalid,
            s_axis_tdata  => axis_tdata,
            s_axis_tstrb  => axis_tstrb,
            s_axis_tlast  => axis_tlast,
            s_axis_tready => axis_tready,

            o_fifo_wdata   => fifo_wdata,
            o_fifos_wen    => fifos_wen,
            i_fifos_wvalid => fifos_wvalid,

            o_ub_count_wen => ub_count_wen,
            o_ub_count     => ub_count,
            i_noc_count    => noc_count
        );

    -- instance
    gen_fifos : for i in 0 to PE_NUM - 1 generate
        inst_fifo : entity work.ring_fifo
            generic map(
                BUFFER_DEPTH => 2,
                DATA_WIDTH   => C_AXIS_TDATA_WIDTH,
                RST_LVL      => RST_LVL
            )
            port map(
                clk => clk,
                rst => rst,

                i_wdata  => fifo_wdata,
                i_wen    => fifos_wen(i),
                o_wvalid => fifos_wvalid(i),

                o_rdata  => fifos_rdata(i),
                i_ren    => fifos_ren(i),
                o_rvalid => fifos_rvalid(i)

            );
    end generate;

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