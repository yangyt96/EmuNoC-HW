library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.NOC_3D_PACKAGE.all;
use work.TESTBENCH_PACKAGE.all;

entity m_axis_ni_tb is
    generic (
        DATA_WIDTH   : Integer := 32;
        VC_NUM       : Integer := 2;
        BUFFER_DEPTH : Integer := 2
    );
end entity;

architecture behave of m_axis_ni_tb is
    -- System
    signal clk     : Std_logic := '0';
    signal rst     : Std_logic := RST_LVL;
    signal clk_cnt : Integer   := 0;

    signal rec_axis_tvalid : Std_logic;
    signal rec_axis_tdata  : Std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal rec_axis_tstrb  : Std_logic_vector((DATA_WIDTH/8) - 1 downto 0);
    signal rec_axis_tlast  : Std_logic;
    signal rec_axis_tready : Std_logic;

    signal local_flit  : Std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal local_write : Std_logic_vector(VC_NUM - 1 downto 0);
    signal local_incr  : Std_logic_vector(VC_NUM - 1 downto 0);

begin

    inst_generator : entity work.generator_router_local
        generic map(
            vc_depth_out_array => ((BUFFER_DEPTH, BUFFER_DEPTH), (2, 2), (2, 2), (2, 2), (2, 2))
        )
        port map(
            clk => clk,
            rst => rst,

            o_local_tx          => local_flit,
            o_local_vc_write_tx => local_write,
            i_local_incr_rx     => local_incr
        );

    inst_ni_master : entity work.m_axis_ni
        generic map(
            C_M_AXIS_TDATA_WIDTH => DATA_WIDTH,
            FLIT_SIZE            => DATA_WIDTH,
            VC_NUM               => VC_NUM,
            BUFFER_DEPTH         => BUFFER_DEPTH,

            RST_LVL => RST_LVL -- NOC_3D_PKG
        )
        port map(
            i_local_rx          => local_flit,
            i_local_vc_write_rx => local_write,
            o_local_incr_tx_vec => local_incr,

            M_AXIS_ACLK    => clk,
            M_AXIS_ARESETN => rst,

            M_AXIS_TVALID => rec_axis_tvalid,
            M_AXIS_TDATA  => rec_axis_tdata,
            M_AXIS_TSTRB  => rec_axis_tstrb,
            M_AXIS_TLAST  => rec_axis_tlast,
            M_AXIS_TREADY => rec_axis_tready
        );

    -- rec Slave
    inst_s_axi_traffic_rec : entity work.S_AXIS_TRAFFIC_REC
        generic map(
            C_S_AXIS_TDATA_WIDTH => flit_size,
            rec_time_text        => "testdata/m_axis_ni_tb/out/rec_time_text.txt",
            rec_data_text        => "testdata/m_axis_ni_tb/out/rec_data_text.txt"
        )
        port map(
            S_AXIS_ACLK    => clk,
            S_AXIS_ARESETN => rst,
            S_AXIS_TVALID  => rec_axis_tvalid,
            S_AXIS_TDATA   => rec_axis_tdata,
            S_AXIS_TSTRB   => rec_axis_tstrb,
            S_AXIS_TLAST   => rec_axis_tlast,
            S_AXIS_TREADY  => rec_axis_tready
        );

    -- System
    clk     <= not(clk) after clk_period/2;
    clk_cnt <= clk_cnt + 1 after clk_period;

    proc_rst : process
    begin
        rst <= RST_LVL;
        wait for (clk_period * 2);
        rst <= not(RST_LVL);
        wait;
    end process proc_rst;

end architecture;