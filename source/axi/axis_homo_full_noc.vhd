library ieee;
use ieee.std_logic_1164.all;
use IEEE.math_real.all;
use ieee.numeric_std.all;
use work.NOC_3D_PACKAGE.all;

entity axis_homo_full_noc is
    generic (
        BUFFER_DEPTH  : Integer := 31;
        ROUTER_CREDIT : Integer := 2;
        NUM_ROUTER    : Integer := max_x_dim * max_y_dim * max_z_dim;
        NUM_IO        : Integer := max_x_dim * max_y_dim * max_z_dim * max_vc_num;

        C_AXIS_TDATA_WIDTH : Integer := flit_size
    );
    port (
        clk : in Std_logic;
        rst : in Std_logic;

        m_axis_tvalid_vec : out Std_logic_vector(NUM_ROUTER - 1 downto 0);
        m_axis_tdata_vec  : out flit_vector(NUM_ROUTER - 1 downto 0);
        m_axis_tstrb_vec  : out Std_logic_vector((C_AXIS_TDATA_WIDTH/8) * NUM_ROUTER - 1 downto 0);
        m_axis_tlast_vec  : out Std_logic_vector(NUM_ROUTER - 1 downto 0);
        m_axis_tready_vec : in Std_logic_vector(NUM_ROUTER - 1 downto 0);

        s_axis_tready_vec : out Std_logic_vector(NUM_ROUTER - 1 downto 0);
        s_axis_tdata_vec  : in flit_vector(NUM_ROUTER - 1 downto 0);
        s_axis_tstrb_vec  : in Std_logic_vector((C_AXIS_TDATA_WIDTH/8) * NUM_ROUTER - 1 downto 0);
        s_axis_tlast_vec  : in Std_logic_vector(NUM_ROUTER - 1 downto 0);
        s_axis_tvalid_vec : in Std_logic_vector(NUM_ROUTER - 1 downto 0)

    );
end entity;

architecture behave of axis_homo_full_noc is
    signal local_rx          : flit_vector(NUM_ROUTER - 1 downto 0);
    signal local_tx          : flit_vector(NUM_ROUTER - 1 downto 0);
    signal local_vc_write_rx : Std_logic_vector(NUM_IO - 1 downto 0);
    signal local_vc_write_tx : Std_logic_vector(NUM_IO - 1 downto 0);
    signal local_incr_rx_vec : Std_logic_vector(NUM_IO - 1 downto 0);
    signal local_incr_tx_vec : Std_logic_vector(NUM_IO - 1 downto 0);
begin

    -- NoC
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

    -- slave port
    gen_slave : for i in 0 to NUM_ROUTER - 1 generate
        inst_slave : entity work.s_axis_ni
            generic map(
                FLIT_SIZE     => flit_size,
                VC_NUM        => max_vc_num,
                ROUTER_CREDIT => ROUTER_CREDIT,

                C_S_AXIS_TDATA_WIDTH => flit_size
            )
            port map(
                -- port to router local input flit
                o_local_tx          => local_rx(i),
                o_local_vc_write_tx => local_vc_write_rx(max_vc_num * (i + 1) - 1 downto max_vc_num * i),
                i_local_incr_rx_vec => local_incr_tx_vec(max_vc_num * (i + 1) - 1 downto max_vc_num * i),

                -- AXI Stream Slave interface
                S_AXIS_ACLK    => clk,
                S_AXIS_ARESETN => rst,

                S_AXIS_TREADY => s_axis_tready_vec(i),
                S_AXIS_TDATA  => s_axis_tdata_vec(i),
                S_AXIS_TSTRB  => s_axis_tstrb_vec((C_AXIS_TDATA_WIDTH/8) * (i + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * i),
                S_AXIS_TLAST  => s_axis_tlast_vec(i),
                S_AXIS_TVALID => s_axis_tvalid_vec(i)
            );
    end generate;

    -- master port
    gen_master : for i in 0 to NUM_ROUTER - 1 generate
        inst_master : entity work.m_axis_ni
            generic map(
                FLIT_SIZE    => flit_size,
                VC_NUM       => max_vc_num,
                BUFFER_DEPTH => BUFFER_DEPTH,

                C_M_AXIS_TDATA_WIDTH => flit_size
            )
            port map(
                -- NoC router local port
                i_local_rx          => local_tx(i),
                i_local_vc_write_rx => local_vc_write_tx(max_vc_num * (i + 1) - 1 downto max_vc_num * i),
                o_local_incr_tx_vec => local_incr_rx_vec(max_vc_num * (i + 1) - 1 downto max_vc_num * i),

                -- AXI Stream Master interface
                M_AXIS_ACLK    => clk,
                M_AXIS_ARESETN => rst,

                M_AXIS_TVALID => m_axis_tvalid_vec(i),
                M_AXIS_TDATA  => m_axis_tdata_vec(i),
                M_AXIS_TSTRB  => m_axis_tstrb_vec((C_AXIS_TDATA_WIDTH/8) * (i + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * i),
                M_AXIS_TLAST  => m_axis_tlast_vec(i),
                M_AXIS_TREADY => m_axis_tready_vec(i)
            );
    end generate;

end architecture;