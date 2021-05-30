library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

use work.NOC_3D_PACKAGE.all;

entity top1 is
    generic (
        ROUTER_CREDIT      : Integer := 2;
        BUFFER_DEPTH       : Integer := 2;
        C_AXIS_TDATA_WIDTH : Integer := flit_size
    );
    port (
        clk : in Std_logic;
        rst : in Std_logic;

        s_axis_tready : out Std_logic;
        s_axis_tdata  : in Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
        s_axis_tstrb  : in Std_logic_vector((C_AXIS_TDATA_WIDTH/8) - 1 downto 0);
        s_axis_tlast  : in Std_logic;
        s_axis_tvalid : in Std_logic;

        m_axis_tvalid : out Std_logic;
        m_axis_tdata  : out Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
        m_axis_tstrb  : out Std_logic_vector((C_AXIS_TDATA_WIDTH/8) - 1 downto 0);
        m_axis_tlast  : out Std_logic;
        m_axis_tready : in Std_logic
    );
end entity;

architecture behave of top1 is

    constant num_router : Positive := max_x_dim * max_y_dim * max_z_dim;
    constant num_io     : Positive := num_router * max_vc_num;

    signal local_rx          : flit_vector(num_router - 1 downto 0)  := (others => (others => '0'));
    signal local_vc_write_rx : Std_logic_vector(num_io - 1 downto 0) := (others => '0');
    signal local_incr_rx_vec : Std_logic_vector(num_io - 1 downto 0) := (others => '0');
    signal local_tx          : flit_vector(num_router - 1 downto 0);
    signal local_vc_write_tx : Std_logic_vector(num_io - 1 downto 0);
    signal local_incr_tx_vec : Std_logic_vector(num_io - 1 downto 0);

    signal a_axis_tready_1d_arr : Std_logic_vector(num_router - 1 downto 0);
    signal a_axis_tdata_1d_arr  : Std_logic_vector(num_router * C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal a_axis_tstrb_1d_arr  : Std_logic_vector(num_router * (C_AXIS_TDATA_WIDTH/8) - 1 downto 0);
    signal a_axis_tlast_1d_arr  : Std_logic_vector(num_router - 1 downto 0);
    signal a_axis_tvalid_1d_arr : Std_logic_vector(num_router - 1 downto 0);

    signal b_axis_tready_1d_arr : Std_logic_vector(num_router - 1 downto 0);
    signal b_axis_tdata_1d_arr  : Std_logic_vector(num_router * C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal b_axis_tstrb_1d_arr  : Std_logic_vector(num_router * (C_AXIS_TDATA_WIDTH/8) - 1 downto 0);
    signal b_axis_tlast_1d_arr  : Std_logic_vector(num_router - 1 downto 0);
    signal b_axis_tvalid_1d_arr : Std_logic_vector(num_router - 1 downto 0);

begin

    -- I/O connection
    s_axis_tready <= a_axis_tready_1d_arr(0);
    m_axis_tvalid <= b_axis_tvalid_1d_arr(0);
    m_axis_tdata  <= b_axis_tdata_1d_arr(C_AXIS_TDATA_WIDTH * (0 + 1) - 1 downto C_AXIS_TDATA_WIDTH * 0);
    m_axis_tstrb  <= b_axis_tstrb_1d_arr((C_AXIS_TDATA_WIDTH/8) * (0 + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * 0);
    m_axis_tlast  <= b_axis_tlast_1d_arr(0);

    b_axis_tready_1d_arr(0)                                                                     <= m_axis_tready;
    a_axis_tvalid_1d_arr(0)                                                                     <= s_axis_tvalid;
    a_axis_tdata_1d_arr(C_AXIS_TDATA_WIDTH * (0 + 1) - 1 downto C_AXIS_TDATA_WIDTH * 0)         <= s_axis_tdata;
    a_axis_tstrb_1d_arr((C_AXIS_TDATA_WIDTH/8) * (0 + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * 0) <= s_axis_tstrb;
    a_axis_tlast_1d_arr(0)                                                                      <= s_axis_tlast;

    -- Modules

    gen_s_axis_router_local : for i in 0 to num_router - 1 generate
        inst_s_axis_router_local : entity work.S_AXIS_ROUTER_LOCAL
            generic map(
                FLIT_SIZE     => flit_size,
                VC_NUM        => max_vc_num,
                ROUTER_CREDIT => ROUTER_CREDIT,

                C_S_AXIS_TDATA_WIDTH => C_AXIS_TDATA_WIDTH
            )
            port map(
                -- port to router local input flit
                o_local_rx          => local_rx(i),
                o_local_vc_write_rx => local_vc_write_rx(max_vc_num * (i + 1) - 1 downto max_vc_num * i),
                i_local_incr_tx_vec => local_incr_tx_vec(max_vc_num * (i + 1) - 1 downto max_vc_num * i),

                -- External
                S_AXIS_TADDR => (others => '0'),

                -- AXI Stream Slave interface
                S_AXIS_ACLK    => clk,
                S_AXIS_ARESETN => rst,
                S_AXIS_TREADY  => a_axis_tready_1d_arr(i),
                S_AXIS_TDATA   => a_axis_tdata_1d_arr(flit_size * (i + 1) - 1 downto flit_size * i),
                S_AXIS_TSTRB   => a_axis_tstrb_1d_arr((flit_size/8) * (i + 1) - 1 downto (flit_size/8) * i),
                S_AXIS_TLAST   => a_axis_tlast_1d_arr(i),
                S_AXIS_TVALID  => a_axis_tvalid_1d_arr(i)
            );
    end generate gen_s_axis_router_local;

    gen_m_axis_router_local : for i in 0 to num_router - 1 generate
        inst_m_axis_router_local : entity work.M_AXIS_ROUTER_LOCAL
            generic map(
                FLIT_SIZE    => flit_size,
                VC_NUM       => max_vc_num,
                BUFFER_DEPTH => BUFFER_DEPTH,

                C_M_AXIS_TDATA_WIDTH => C_AXIS_TDATA_WIDTH
            )
            port map(
                -- port to router local input flit
                i_local_tx          => local_tx(i),
                i_local_vc_write_tx => local_vc_write_tx(max_vc_num * (i + 1) - 1 downto max_vc_num * i),
                o_local_incr_rx_vec => local_incr_rx_vec(max_vc_num * (i + 1) - 1 downto max_vc_num * i),

                -- AXI Stream Slave interface
                M_AXIS_ACLK    => clk,
                M_AXIS_ARESETN => rst,
                M_AXIS_TREADY  => b_axis_tready_1d_arr(i),
                M_AXIS_TDATA   => b_axis_tdata_1d_arr(flit_size * (i + 1) - 1 downto flit_size * i),
                M_AXIS_TSTRB   => b_axis_tstrb_1d_arr((flit_size/8) * (i + 1) - 1 downto (flit_size/8) * i),
                M_AXIS_TLAST   => b_axis_tlast_1d_arr(i),
                M_AXIS_TVALID  => b_axis_tvalid_1d_arr(i)
            );
    end generate gen_m_axis_router_local;

    gen_sm_return_axis : for i in 1 to num_router - 1 generate
        inst_m_axis_router_local : entity work.return_axis
            generic map(
                C_AXIS_TDATA_WIDTH => C_AXIS_TDATA_WIDTH
            )
            port map(
                clk => clk,
                rst => rst,

                S_AXIS_TREADY => b_axis_tready_1d_arr(i),
                S_AXIS_TDATA  => b_axis_tdata_1d_arr(flit_size * (i + 1) - 1 downto flit_size * i),
                S_AXIS_TSTRB  => b_axis_tstrb_1d_arr((flit_size/8) * (i + 1) - 1 downto (flit_size/8) * i),
                S_AXIS_TLAST  => b_axis_tlast_1d_arr(i),
                S_AXIS_TVALID => b_axis_tvalid_1d_arr(i),

                M_AXIS_TREADY => a_axis_tready_1d_arr(i),
                M_AXIS_TDATA  => a_axis_tdata_1d_arr(flit_size * (i + 1) - 1 downto flit_size * i),
                M_AXIS_TSTRB  => a_axis_tstrb_1d_arr((flit_size/8) * (i + 1) - 1 downto (flit_size/8) * i),
                M_AXIS_TLAST  => a_axis_tlast_1d_arr(i),
                M_AXIS_TVALID => a_axis_tvalid_1d_arr(i)
            );
    end generate gen_sm_return_axis;

    ----------------------------------------------------------------
    -- NoC
    ----------------------------------------------------------------
    full_noc_comp : entity work.full_noc
        port map(
            clk               => clk,
            rst               => rst,
            local_rx          => local_rx,
            local_vc_write_rx => local_vc_write_rx,
            local_incr_rx_vec => local_incr_rx_vec,
            local_tx          => local_tx,
            local_vc_write_tx => local_vc_write_tx,
            local_incr_tx_vec => local_incr_tx_vec
        );

end architecture;