library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.NOC_3D_PACKAGE.all;

entity axis_ps_eject_tb is
    generic (
        RST_LVL    : Std_logic := RST_LVL;
        CLK_PERIOD : Time      := 1 ns
    );
end entity;

architecture behave of axis_ps_eject_tb is
    -- System
    signal clk     : Std_logic := '0';
    signal rst     : Std_logic := RST_LVL;
    signal clk_cnt : Integer   := 0;

    -- Constants
    constant C_AXIS_TDATA_WIDTH : Integer := flit_size;
    constant PE_NUM             : Integer := max_x_dim * max_y_dim * max_z_dim;

    -- Signals
    signal gen_axis_tvalid : Std_logic;
    signal gen_axis_tdata  : Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal gen_axis_tstrb  : Std_logic_vector((C_AXIS_TDATA_WIDTH/8) - 1 downto 0);
    signal gen_axis_tlast  : Std_logic;
    signal gen_axis_tready : Std_logic;

    signal rec_axis_tvalid : Std_logic;
    signal rec_axis_tdata  : Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal rec_axis_tstrb  : Std_logic_vector((C_AXIS_TDATA_WIDTH/8) - 1 downto 0);
    signal rec_axis_tlast  : Std_logic;
    signal rec_axis_tready : Std_logic;

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

    --------------------------------------------------------------
    -- initiators
    initiator_m_axis_traffic_gen : entity work.M_AXIS_TRAFFIC_GEN
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

            M_AXIS_TVALID => gen_axis_tvalid,
            M_AXIS_TDATA  => gen_axis_tdata,
            M_AXIS_TSTRB  => gen_axis_tstrb,
            M_AXIS_TLAST  => gen_axis_tlast,
            M_AXIS_TREADY => gen_axis_tready
        );

    initiator_axis_sp_inject : entity work.axis_sp_inject
        generic map(
            CNT_WIDTH => 32
        )
        port map(
            clk => clk,
            rst => rst,

            s_axis_tvalid => gen_axis_tvalid,
            s_axis_tdata  => gen_axis_tdata,
            s_axis_tstrb  => gen_axis_tstrb,
            s_axis_tlast  => gen_axis_tlast,
            s_axis_tready => gen_axis_tready,

            o_fifo_wdata   => fifo_wdata,
            o_fifos_wen    => fifos_wen,
            i_fifos_wvalid => fifos_wvalid,

            o_ub_count_wen => ub_count_wen,
            o_ub_count     => ub_count,
            i_noc_count    => noc_count
        );

    gen_initiator_fifos : for i in 0 to PE_NUM - 1 generate
        initiator_fifo : entity work.ring_fifo
            generic map(
                BUFFER_DEPTH => 1,
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

    --------------------------------------------------------------
    -- Design Unit Test
    DUT : entity work.axis_ps_eject
        port map(
            clk => clk,
            rst => rst,

            m_axis_tvalid => rec_axis_tvalid,
            m_axis_tdata  => rec_axis_tdata,
            m_axis_tstrb  => rec_axis_tstrb,
            m_axis_tlast  => rec_axis_tlast,
            m_axis_tready => rec_axis_tready,

            i_fifos_rdata  => fifos_rdata,
            o_fifos_ren    => fifos_ren,
            i_fifos_rvalid => fifos_rvalid,

            o_halt      => clk_halt_in,
            i_noc_count => noc_count
        );
    --------------------------------------------------------------

    sink : entity work.S_AXIS_TRAFFIC_REC
        generic map(
            C_S_AXIS_TDATA_WIDTH => C_AXIS_TDATA_WIDTH,
            rec_time_text        => "testdata/axis_validation/out/recv_time.txt",
            rec_data_text        => "testdata/axis_validation/out/recv_flit.txt"
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