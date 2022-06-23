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

entity top_noc_axis is
    generic (
        BUFFER_DEPTH  : Integer := 2;
        ROUTER_CREDIT : Integer := 2;
        NUM_ROUTER    : Integer := max_x_dim * max_y_dim * max_z_dim;
        NUM_IO        : Integer := max_x_dim * max_y_dim * max_z_dim * max_vc_num;

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

architecture behave of top_noc_axis is

    signal m_axis_tvalid_vec : Std_logic_vector(NUM_ROUTER - 1 downto 0);
    signal m_axis_tdata_vec  : flit_vector(NUM_ROUTER - 1 downto 0);
    signal m_axis_tstrb_vec  : Std_logic_vector((C_AXIS_TDATA_WIDTH/8) * NUM_ROUTER - 1 downto 0);
    signal m_axis_tlast_vec  : Std_logic_vector(NUM_ROUTER - 1 downto 0);
    signal m_axis_tready_vec : Std_logic_vector(NUM_ROUTER - 1 downto 0);

    signal s_axis_tready_vec : Std_logic_vector(NUM_ROUTER - 1 downto 0);
    signal s_axis_tdata_vec  : flit_vector(NUM_ROUTER - 1 downto 0);
    signal s_axis_tstrb_vec  : Std_logic_vector((C_AXIS_TDATA_WIDTH/8) * NUM_ROUTER - 1 downto 0);
    signal s_axis_tlast_vec  : Std_logic_vector(NUM_ROUTER - 1 downto 0);
    signal s_axis_tvalid_vec : Std_logic_vector(NUM_ROUTER - 1 downto 0);

begin
    -- I/O connection
    s_axis_tready <= s_axis_tready_vec(0);
    m_axis_tvalid <= m_axis_tvalid_vec(1);
    m_axis_tdata  <= m_axis_tdata_vec(1);
    m_axis_tstrb  <= m_axis_tstrb_vec((C_AXIS_TDATA_WIDTH/8) * (1 + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * 1);
    m_axis_tlast  <= m_axis_tlast_vec(1);

    s_axis_tdata_vec(0)                                                                      <= s_axis_tdata;
    s_axis_tstrb_vec((C_AXIS_TDATA_WIDTH/8) * (0 + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * 0) <= s_axis_tstrb;
    s_axis_tlast_vec(0)                                                                      <= s_axis_tlast;
    s_axis_tvalid_vec(0)                                                                     <= s_axis_tvalid;
    m_axis_tready_vec(1)                                                                     <= m_axis_tready;

    -- Full NoC
    inst_axis_homo_full_noc : entity work.axis_homo_full_noc
        generic map(
            BUFFER_DEPTH  => BUFFER_DEPTH,
            ROUTER_CREDIT => ROUTER_CREDIT,
            NUM_ROUTER    => NUM_ROUTER,
            NUM_IO        => NUM_IO,

            C_AXIS_TDATA_WIDTH => C_AXIS_TDATA_WIDTH
        )
        port map(
            clk => clk,
            rst => rst,

            m_axis_tvalid_vec => m_axis_tvalid_vec,
            m_axis_tdata_vec  => m_axis_tdata_vec,
            m_axis_tstrb_vec  => m_axis_tstrb_vec,
            m_axis_tlast_vec  => m_axis_tlast_vec,
            m_axis_tready_vec => m_axis_tready_vec,

            s_axis_tready_vec => s_axis_tready_vec,
            s_axis_tdata_vec  => s_axis_tdata_vec,
            s_axis_tstrb_vec  => s_axis_tstrb_vec,
            s_axis_tlast_vec  => s_axis_tlast_vec,
            s_axis_tvalid_vec => s_axis_tvalid_vec
        );

end architecture;