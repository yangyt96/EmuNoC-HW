library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.NOC_3D_PACKAGE.all;

entity top_axis_validation_tb is
    generic (
        RST_LVL    : Std_logic := RST_LVL;
        CLK_PERIOD : Time      := 1 ns
    );
end entity;

architecture behave of top_axis_validation_tb is
    -- System
    signal clk     : Std_logic := '1';
    signal rst     : Std_logic := RST_LVL;
    signal clk_cnt : Integer   := 0;

    -- Constants
    constant C_AXIS_TDATA_WIDTH : Integer := flit_size;

    -- Signals
    signal rec_axis_tvalid : Std_logic;
    signal rec_axis_tdata  : Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal rec_axis_tstrb  : Std_logic_vector((C_AXIS_TDATA_WIDTH/8) - 1 downto 0);
    signal rec_axis_tlast  : Std_logic;
    signal rec_axis_tready : Std_logic;

    signal gen_axis_tvalid : Std_logic;
    signal gen_axis_tdata  : Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal gen_axis_tstrb  : Std_logic_vector((C_AXIS_TDATA_WIDTH/8) - 1 downto 0);
    signal gen_axis_tlast  : Std_logic;
    signal gen_axis_tready : Std_logic;

begin

    initiator : entity work.m_axis_sp_valid
        generic map(
            inj_time_text      => "testdata/top_axis_validation_tb/in/inj_time.txt",
            packet_length_text => "testdata/top_axis_validation_tb/in/pkt_len.txt",
            image_2_flits_text => "testdata/top_axis_validation_tb/in/flit_data.txt"
        )
        port map(
            clk => clk,
            rst => rst,

            M_AXIS_TVALID => gen_axis_tvalid,
            M_AXIS_TDATA  => gen_axis_tdata,
            M_AXIS_TSTRB  => gen_axis_tstrb,
            M_AXIS_TLAST  => gen_axis_tlast,
            M_AXIS_TREADY => gen_axis_tready
        );

    DUT : entity work.top_axis_validation
        port map(
            clk => clk,
            rst => rst,

            s_axis_tvalid => gen_axis_tvalid,
            s_axis_tdata  => gen_axis_tdata,
            s_axis_tstrb  => gen_axis_tstrb,
            s_axis_tlast  => gen_axis_tlast,
            s_axis_tready => gen_axis_tready,

            m_axis_tvalid => rec_axis_tvalid,
            m_axis_tdata  => rec_axis_tdata,
            m_axis_tstrb  => rec_axis_tstrb,
            m_axis_tlast  => rec_axis_tlast,
            m_axis_tready => rec_axis_tready
        );

    sink : entity work.S_AXIS_TRAFFIC_REC
        generic map(
            C_S_AXIS_TDATA_WIDTH => C_AXIS_TDATA_WIDTH,
            rec_time_text        => "testdata/top_axis_validation_tb/out/recv_time.txt",
            rec_data_text        => "testdata/top_axis_validation_tb/out/recv_flit.txt"
        )
        port map(
            S_AXIS_ACLK    => clk,
            S_AXIS_ARESETN => rst,

            S_AXIS_TVALID => rec_axis_tvalid,
            S_AXIS_TDATA  => rec_axis_tdata,
            S_AXIS_TSTRB  => rec_axis_tstrb,
            S_AXIS_TLAST  => rec_axis_tlast,
            S_AXIS_TREADY => rec_axis_tready
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