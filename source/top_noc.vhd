-- decide different src and dst

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

use work.NOC_3D_PACKAGE.all;

entity top_noc is
    generic (
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

architecture behave of top_noc is
    type int_arr is array (Natural range <>) of Integer;

    constant num_router : Positive := max_x_dim * max_y_dim * max_z_dim;
    constant num_io     : Positive := num_router * max_vc_num;
    constant src_pos    : int_arr  := (0, 0, 0); -- z,y,x
    constant dst_pos    : int_arr  := (0, 0, 1); -- z,y,x
    constant src_router : Integer  := src_pos(0) * max_x_dim * max_y_dim + src_pos(1) * max_x_dim + src_pos(2);
    constant dst_router : Integer  := dst_pos(0) * max_x_dim * max_y_dim + dst_pos(1) * max_x_dim + dst_pos(2);
    constant src_vc     : Integer  := src_router * max_vc_num;
    constant dst_vc     : Integer  := dst_router * max_vc_num; -- always from vc port 0, its the local vc port

    signal local_rx          : flit_vector(num_router - 1 downto 0)  := (others => (others => '0'));
    signal local_vc_write_rx : Std_logic_vector(num_io - 1 downto 0) := (others => '0');
    signal local_incr_rx_vec : Std_logic_vector(num_io - 1 downto 0) := (others => '0');
    signal local_tx          : flit_vector(num_router - 1 downto 0);
    signal local_vc_write_tx : Std_logic_vector(num_io - 1 downto 0);
    signal local_incr_tx_vec : Std_logic_vector(num_io - 1 downto 0);

begin

    -- router local Slave
    inst_s_axis_ni : entity work.s_axis_ni
        generic map(
            FLIT_SIZE     => flit_size,
            VC_NUM        => max_vc_num,
            ROUTER_CREDIT => 2, -- ! need automate

            C_S_AXIS_TDATA_WIDTH => 32

        )
        port map(
            -- port to router local input flit
            o_local_tx          => local_rx(src_router),
            o_local_vc_write_tx => local_vc_write_rx(src_vc + max_vc_num - 1 downto src_vc),
            i_local_incr_rx_vec => local_incr_tx_vec(src_vc + max_vc_num - 1 downto src_vc),

            -- AXI Stream Slave interface
            S_AXIS_ACLK    => clk,
            S_AXIS_ARESETN => rst,
            S_AXIS_TREADY  => s_axis_tready,
            S_AXIS_TDATA   => s_axis_tdata,
            S_AXIS_TSTRB   => s_axis_tstrb,
            S_AXIS_TLAST   => s_axis_tlast,
            S_AXIS_TVALID  => s_axis_tvalid

        );

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

    -- router local Master
    inst_m_axis_ni : entity work.m_axis_ni
        generic map(
            FLIT_SIZE            => flit_size,
            VC_NUM               => max_vc_num,
            C_M_AXIS_TDATA_WIDTH => flit_size,
            BUFFER_DEPTH         => 2
        )
        port map(
            -- NoC router local port
            i_local_rx          => local_tx(dst_router),
            i_local_vc_write_rx => local_vc_write_tx(dst_vc + max_vc_num - 1 downto dst_vc),
            o_local_incr_tx_vec => local_incr_rx_vec(dst_vc + max_vc_num - 1 downto dst_vc),

            -- AXI Stream Master interface
            M_AXIS_ACLK    => clk,
            M_AXIS_ARESETN => rst,
            M_AXIS_TVALID  => m_axis_tvalid,
            M_AXIS_TDATA   => m_axis_tdata,
            M_AXIS_TSTRB   => m_axis_tstrb,
            M_AXIS_TLAST   => m_axis_tlast,
            M_AXIS_TREADY  => m_axis_tready

        );
end architecture;