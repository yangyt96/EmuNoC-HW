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
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

use work.NOC_3D_PACKAGE.all;

entity top_peripherals is
    generic (
        INJ_PE_BUFFER_DEPTH : Integer := 16;
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

architecture behave of top_peripherals is
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
    signal clkh_run     : Std_logic;
    signal ps_halt      : Std_logic;
    signal clk_halt     : Std_logic;
    signal ub_count_wen : Std_logic;
    signal ub_count     : Std_logic_vector(31 downto 0);
    signal noc_count    : Std_logic_vector(31 downto 0);

begin

    ejects_axis_tvalid <= injects_axis_tvalid;
    ejects_axis_tdata  <= injects_axis_tdata;
    ejects_axis_tstrb  <= injects_axis_tstrb;
    ejects_axis_tlast  <= injects_axis_tlast;

    injects_axis_tready <= ejects_axis_tready;

    -- CLK CTRL
    -- inst_clock_halter : entity work.clock_halter_xilinx
    inst_clock_halter : entity work.clock_halter
        generic map(
            CNT_WIDTH => C_AXIS_TDATA_WIDTH,
            RST_LVL   => RST_LVL
        )
        port map(
            clk  => clk,
            rst  => rst,
            clkh => clkh,

            i_halt => ps_halt,
            o_halt => clk_halt,
            o_run  => clkh_run,

            i_ub_count_wen => ub_count_wen,
            i_ub_count     => ub_count,
            o_run_count    => noc_count
        );

    -- SP
    inst_axis_sp_inject : entity work.axis_sp_inject
        port map(
            clk => clk,
            rst => rst,

            i_run     => clkh_run,
            i_ps_halt => ps_halt,

            s_axis_tvalid => s_axis_tvalid,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tstrb  => s_axis_tstrb,
            s_axis_tlast  => s_axis_tlast,
            s_axis_tready => s_axis_tready,

            o_fifo_wdata   => fifo_wdata,
            o_fifos_wen    => fifos_wen,
            i_fifos_wvalid => fifos_wvalid,

            o_ub_count_wen => ub_count_wen,
            o_ub_count     => ub_count
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
                clk  => clk,
                rst  => rst,
                clkh => clkh,

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

    -- HALT PE
    gen_pe_eject : for i in 0 to PE_NUM - 1 generate
        inst_pe_eject : entity work.pe_eject
            generic map(
                BUFFER_DEPTH       => 1,
                C_AXIS_TDATA_WIDTH => flit_size,
                RST_LVL            => RST_LVL
            )
            port map(
                clk  => clk,
                rst  => rst,
                clkh => clkh,

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

            i_halt      => clk_halt,
            o_halt      => ps_halt,
            i_noc_count => noc_count
        );

end architecture;