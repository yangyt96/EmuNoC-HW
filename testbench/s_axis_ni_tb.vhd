library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.NOC_3D_PACKAGE.all;
use work.TESTBENCH_PACKAGE.all;

entity s_axis_ni_tb is
    generic (
        DATA_WIDTH    : Integer := 32;
        VC_NUM        : Integer := 2;
        ROUTER_CREDIT : Integer := 2
    );
end entity;

architecture behave of s_axis_ni_tb is

    constant cnt_flit_width          : Positive := flit_size;
    constant cnt_srl_fifo_depth      : Integer  := 16;
    constant cnt_inj_time_text       : String   := "testdata/s_axis_ni_tb/in/inj_time.txt";   -- r
    constant cnt_packet_length_text  : String   := "testdata/s_axis_ni_tb/in/pkt_len.txt";    -- r
    constant cnt_image_2_flits_text  : String   := "testdata/s_axis_ni_tb/in/flit_data.txt";  -- r
    constant cnt_rec_time_text       : String   := "testdata/s_axis_ni_tb/out/recv_time.txt"; -- w
    constant cnt_rec_data_text       : String   := "testdata/s_axis_ni_tb/out/recv_data.txt"; -- w
    constant cnt_inj_time_2_noc_text : String   := "testdata/s_axis_ni_tb/out/inj_time.txt";  -- w

    -- System
    signal clk     : Std_logic := '0';
    signal rst     : Std_logic := RST_LVL;
    signal clk_cnt : Integer   := 0;

    signal gen_axis_tvalid : Std_logic;
    signal gen_axis_tdata  : Std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal gen_axis_tstrb  : Std_logic_vector((DATA_WIDTH/8) - 1 downto 0);
    signal gen_axis_tlast  : Std_logic;
    signal gen_axis_tready : Std_logic;

    signal local_flit  : Std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal local_write : Std_logic_vector(VC_NUM - 1 downto 0);
    signal local_incr  : Std_logic_vector(VC_NUM - 1 downto 0);

    signal fifo_data_in    : Std_logic_vector(VC_NUM - 1 downto 0);
    signal fifo_write_en   : Std_logic;
    signal fifo_read_en    : Std_logic;
    signal fifo_data_out   : Std_logic_vector(VC_NUM - 1 downto 0);
    signal fifo_read_valid : Std_logic;
begin

    fifo_data_in  <= local_write;
    fifo_write_en <= or_reduce(local_write);

    local_incr <= fifo_data_out when fifo_read_en = '1' else
        (others => '0');

    process (clk, rst)
    begin
        if rst = RST_LVL then
            fifo_read_en <= '0';
        elsif rising_edge(clk) then

            if 0 < clk_cnt and clk_cnt < 100 then
                fifo_read_en <= fifo_read_valid;
            elsif 100 < clk_cnt and clk_cnt < 200 then
                fifo_read_en <= '1' when (fifo_read_valid = '1' and clk_cnt mod 3 = 0) else
                    '0';
            elsif 400 < clk_cnt and clk_cnt < 450 then
                -- create zero credit condition
                fifo_read_en <= '0';
            else
                fifo_read_en <= fifo_read_valid;
            end if;
        end if;
    end process;

    -- component
    inst_ni_slave : entity work.s_axis_ni
        generic map(
            FLIT_SIZE            => DATA_WIDTH,
            VC_NUM               => VC_NUM,
            ROUTER_CREDIT        => ROUTER_CREDIT,
            C_S_AXIS_TDATA_WIDTH => DATA_WIDTH,
            RST_LVL              => RST_LVL
        )
        port map(
            -- port to router local input flit
            o_local_tx          => local_flit,
            o_local_vc_write_tx => local_write,
            i_local_incr_rx_vec => local_incr,

            -- AXI Stream Slave interface
            S_AXIS_ACLK    => clk,
            S_AXIS_ARESETN => rst,

            S_AXIS_TREADY => gen_axis_tready,
            S_AXIS_TDATA  => gen_axis_tdata,
            S_AXIS_TSTRB  => gen_axis_tstrb,
            S_AXIS_TLAST  => gen_axis_tlast,
            S_AXIS_TVALID => gen_axis_tvalid
        );

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
            M_AXIS_ACLK    => clk,
            M_AXIS_ARESETN => rst,
            M_AXIS_TVALID  => gen_axis_tvalid,
            M_AXIS_TDATA   => gen_axis_tdata,
            M_AXIS_TSTRB   => gen_axis_tstrb,
            M_AXIS_TLAST   => gen_axis_tlast,
            M_AXIS_TREADY  => gen_axis_tready
        );

    -- store the vc write signal
    inst_fifo : entity work.ring_fifo
        generic map(
            BUFFER_DEPTH => ROUTER_CREDIT,
            DATA_WIDTH   => VC_NUM,
            RST_LVL      => RST_LVL
        )
        port map(
            clk => clk,
            rst => rst,

            i_wdata => fifo_data_in,
            i_wen   => fifo_write_en,

            i_ren    => fifo_read_en,
            o_rdata  => fifo_data_out,
            o_rvalid => fifo_read_valid
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