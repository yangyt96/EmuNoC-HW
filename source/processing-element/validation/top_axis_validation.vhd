library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

use work.NOC_3D_PACKAGE.all;

entity top_axis_validation is
    generic (
        INJ_PE_BUFFER_DEPTH : Integer := max_x_dim * max_y_dim * max_z_dim;
        C_AXIS_TDATA_WIDTH  : Integer := flit_size;
        PE_NUM              : Integer := max_x_dim * max_y_dim * max_z_dim
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

architecture implementation of top_axis_validation is
    signal fifo_wdata   : Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal fifos_wen    : Std_logic_vector(PE_NUM - 1 downto 0);
    signal fifos_wvalid : Std_logic_vector(PE_NUM - 1 downto 0);

    signal fifos_rdata  : flit_vector(PE_NUM - 1 downto 0);
    signal fifos_ren    : Std_logic_vector(PE_NUM - 1 downto 0);
    signal fifos_rvalid : Std_logic_vector(PE_NUM - 1 downto 0);

    signal injects_axis_tvalid : Std_logic_vector(PE_NUM - 1 downto 0);
    signal injects_axis_tdata  : flit_vector(PE_NUM - 1 downto 0);
    signal injects_axis_tstrb  : Std_logic_vector((C_AXIS_TDATA_WIDTH/8) * PE_NUM - 1 downto 0);
    signal injects_axis_tlast  : Std_logic_vector(PE_NUM - 1 downto 0);
    signal injects_axis_tready : Std_logic_vector(PE_NUM - 1 downto 0);

    signal ejects_axis_tvalid : Std_logic_vector(PE_NUM - 1 downto 0);
    signal ejects_axis_tdata  : flit_vector(PE_NUM - 1 downto 0);
    signal ejects_axis_tstrb  : Std_logic_vector((C_AXIS_TDATA_WIDTH/8) * PE_NUM - 1 downto 0);
    signal ejects_axis_tlast  : Std_logic_vector(PE_NUM - 1 downto 0);
    signal ejects_axis_tready : Std_logic_vector(PE_NUM - 1 downto 0);

    signal clkh         : Std_logic;
    signal halt         : Std_logic;
    signal halt_pe      : Std_logic;
    signal ub_count_wen : Std_logic;
    signal ub_count     : Std_logic_vector(31 downto 0);
    signal noc_count    : Std_logic_vector(31 downto 0);

begin

    -- CLK CTRL
    inst_clock_halter : entity work.clock_halter
        generic map(
            CNT_WIDTH => 32,
            RST_LVL   => RST_LVL
        )
        port map(
            clk  => clk,
            rst  => rst,
            clkh => clkh,

            i_halt => halt,
            o_halt => halt_pe,

            i_ub_count_wen => ub_count_wen,
            i_ub_count     => ub_count,
            o_run_count    => noc_count
        );

    -- SP
    inst_axis_sp_inject : entity work.axis_sp_inject
        port map(
            clk => clk,
            rst => rst,

            s_axis_tvalid => s_axis_tvalid,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tstrb  => s_axis_tstrb,
            s_axis_tlast  => s_axis_tlast,
            s_axis_tready => s_axis_tready,

            o_fifo_wdata   => fifo_wdata,
            o_fifos_wen    => fifos_wen,
            i_fifos_wvalid => fifos_wvalid,

            o_ub_count_wen => ub_count_wen,
            o_ub_count     => ub_count,
            i_noc_count    => noc_count
        );

    -- HALT PE
    gen_pe_inject : for i in 0 to PE_NUM - 1 generate
        inst_pe_inject : entity work.pe_inject
            generic map(
                BUFFER_DEPTH       => INJ_PE_BUFFER_DEPTH,
                C_AXIS_TDATA_WIDTH => flit_size,
                RST_LVL            => RST_LVL
            )
            port map(
                clk => clk,
                rst => rst,

                i_halt => halt_pe,

                i_fifo_wdata  => fifo_wdata,
                i_fifo_wen    => fifos_wen(i),
                o_fifo_wvalid => fifos_wvalid(i),

                m_axis_tvalid => injects_axis_tvalid(i),
                m_axis_tdata  => injects_axis_tdata(i),
                m_axis_tstrb  => injects_axis_tstrb((C_AXIS_TDATA_WIDTH/8) * (i + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * i),
                m_axis_tlast  => injects_axis_tlast(i),
                m_axis_tready => injects_axis_tready(i)
            );
    end generate;

    -- CLK HALT
    inst_axis_homo_full_noc : entity work.axis_homo_full_noc
        generic map(
            BUFFER_DEPTH       => max_packet_len + 1,
            ROUTER_CREDIT      => 2,
            C_AXIS_TDATA_WIDTH => C_AXIS_TDATA_WIDTH
        )
        port map(
            clk => clkh,
            rst => rst,

            m_axis_tvalid_vec => ejects_axis_tvalid,
            m_axis_tdata_vec  => ejects_axis_tdata,
            m_axis_tstrb_vec  => ejects_axis_tstrb,
            m_axis_tlast_vec  => ejects_axis_tlast,
            m_axis_tready_vec => ejects_axis_tready,

            s_axis_tready_vec => injects_axis_tready,
            s_axis_tdata_vec  => injects_axis_tdata,
            s_axis_tstrb_vec  => injects_axis_tstrb,
            s_axis_tlast_vec  => injects_axis_tlast,
            s_axis_tvalid_vec => injects_axis_tvalid
        );

    -- HALT PE
    gen_pe_eject : for i in 0 to PE_NUM - 1 generate
        inst_pe_eject : entity work.pe_eject
            generic map(
                BUFFER_DEPTH       => 1,
                C_AXIS_TDATA_WIDTH => flit_size,
                RST_LVL            => RST_LVL
            )
            port map(
                clk => clk,
                rst => rst,

                i_halt => halt_pe,

                o_fifo_rdata  => fifos_rdata(i),
                i_fifo_ren    => fifos_ren(i),
                o_fifo_rvalid => fifos_rvalid(i),

                s_axis_tvalid => ejects_axis_tvalid(i),
                s_axis_tdata  => ejects_axis_tdata(i),
                s_axis_tstrb  => ejects_axis_tstrb((C_AXIS_TDATA_WIDTH/8) * (i + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * i),
                s_axis_tlast  => ejects_axis_tlast(i),
                s_axis_tready => ejects_axis_tready(i)
            );
    end generate;

    -- PS
    inst_axis_ps_eject : entity work.axis_ps_eject
        port map(
            clk => clk,
            rst => rst,

            m_axis_tvalid => m_axis_tvalid,
            m_axis_tdata  => m_axis_tdata,
            m_axis_tstrb  => m_axis_tstrb,
            m_axis_tlast  => m_axis_tlast,
            m_axis_tready => m_axis_tready,

            i_fifos_rdata  => fifos_rdata,
            o_fifos_ren    => fifos_ren,
            i_fifos_rvalid => fifos_rvalid,

            o_halt      => halt,
            i_noc_count => noc_count
        );

end implementation;