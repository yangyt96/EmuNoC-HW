library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

use std.textio.all;
use work.NOC_3D_PACKAGE.all;
use work.TESTBENCH_PACKAGE.all;

entity top_tb is

end entity;

architecture behave of top_tb is

    -- System
    signal clk     : Std_logic := '0';
    signal rst     : Std_logic := RST_LVL;
    signal clk_cnt : Integer   := 0;

    -- Constants
    constant cnt_flit_width          : Positive := flit_size;
    constant cnt_srl_fifo_depth      : Integer  := 16;
    constant cnt_inj_time_text       : String   := "testdata/gen_rec/in/inj_time.txt";   -- r
    constant cnt_packet_length_text  : String   := "testdata/gen_rec/in/pkt_len.txt";    -- r
    constant cnt_image_2_flits_text  : String   := "testdata/gen_rec/in/flit_data.txt";  -- r
    constant cnt_rec_time_text       : String   := "testdata/gen_rec/out/recv_time.txt"; -- w
    constant cnt_rec_data_text       : String   := "testdata/gen_rec/out/recv_flit.txt"; -- w
    constant cnt_inj_time_2_noc_text : String   := "testdata/gen_rec/out/inj_time.txt";  -- w

    -------------------------------------------------------------------

    signal rec_axis_tvalid : Std_logic;
    signal rec_axis_tdata  : Std_logic_vector(cnt_flit_width - 1 downto 0);
    signal rec_axis_tstrb  : Std_logic_vector((cnt_flit_width/8) - 1 downto 0);
    signal rec_axis_tlast  : Std_logic;
    signal rec_axis_tready : Std_logic;

    signal gen_axis_tvalid : Std_logic;
    signal gen_axis_tdata  : Std_logic_vector(cnt_flit_width - 1 downto 0);
    signal gen_axis_tstrb  : Std_logic_vector((cnt_flit_width/8) - 1 downto 0);
    signal gen_axis_tlast  : Std_logic;
    signal gen_axis_tready : Std_logic;
    signal gen_axis_taddr  : Std_logic_vector(4 - 1 downto 0);

begin

    -- gen Master
    inst_m_axis_traffic_gen : entity work.M_AXIS_TRAFFIC_GEN
        generic map(
            flit_width          => cnt_flit_width,
            srl_fifo_depth      => cnt_srl_fifo_depth,
            inj_time_text       => cnt_inj_time_text,
            packet_length_text  => cnt_packet_length_text,
            image_2_flits_text  => cnt_image_2_flits_text,
            inj_time_2_noc_text => cnt_inj_time_2_noc_text
        )
        port map(
            M_AXIS_TADDR => gen_axis_taddr,

            M_AXIS_ACLK    => clk,
            M_AXIS_ARESETN => rst,
            M_AXIS_TVALID  => gen_axis_tvalid,
            M_AXIS_TDATA   => gen_axis_tdata,
            M_AXIS_TSTRB   => gen_axis_tstrb,
            M_AXIS_TLAST   => gen_axis_tlast,
            M_AXIS_TREADY  => gen_axis_tready
        );

    DUT : entity work.top
        -- generic map(
        --     BUFFER_DEPTH => 1
        -- )
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

    -- rec Slave
    inst_s_axi_traffic_rec : entity work.S_AXIS_TRAFFIC_REC
        generic map(
            C_S_AXIS_TDATA_WIDTH => cnt_flit_width,
            rec_time_text        => cnt_rec_time_text,
            rec_data_text        => cnt_rec_data_text
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
    clk <= not(clk) after clk_period/2;

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
        wait for (clk_period * 2);
        rst <= not(RST_LVL);
        wait;
    end process;

end architecture;