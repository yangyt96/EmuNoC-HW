library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

use work.NOC_3D_PACKAGE.all;

entity top_reflect is
    generic (
        IO_POS : Integer := 0; -- the position of arm core connect to router

        M_AXIS_BUFFER_DEPTH  : Integer := 2;
        S_AXIS_ROUTER_CREDIT : Integer := 2;
        NUM_ROUTER           : Integer := max_x_dim * max_y_dim * max_z_dim;
        NUM_IO               : Integer := max_x_dim * max_y_dim * max_z_dim * max_vc_num;

        REFLECT_BUFFER_DEPTH : Integer := 1000;

        C_AXIS_TDATA_WIDTH   : Integer  := flit_size;
        C_S_AXIS_TADDR_WIDTH : Positive := bit_width(max_vc_num) -- Additional: utility for VC port
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

architecture behave of top_reflect is

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
    s_axis_tready <= s_axis_tready_vec(IO_POS);
    m_axis_tvalid <= m_axis_tvalid_vec(IO_POS);
    m_axis_tdata  <= m_axis_tdata_vec(IO_POS);
    m_axis_tstrb  <= m_axis_tstrb_vec((C_AXIS_TDATA_WIDTH/8) * (IO_POS + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * IO_POS);
    m_axis_tlast  <= m_axis_tlast_vec(IO_POS);

    s_axis_tdata_vec(IO_POS)                                                                           <= s_axis_tdata;
    s_axis_tstrb_vec((C_AXIS_TDATA_WIDTH/8) * (IO_POS + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * IO_POS) <= s_axis_tstrb;
    s_axis_tlast_vec(IO_POS)                                                                           <= s_axis_tlast;
    s_axis_tvalid_vec(IO_POS)                                                                          <= s_axis_tvalid;
    m_axis_tready_vec(IO_POS)                                                                          <= m_axis_tready;

    -- Full NoC
    inst_axis_full_noc : entity work.axis_homo_full_noc
        generic map(
            BUFFER_DEPTH  => M_AXIS_BUFFER_DEPTH,
            ROUTER_CREDIT => S_AXIS_ROUTER_CREDIT,
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

    -- Reflect instances
    inst_tile_reflect_1 : entity work.tile_reflect
        generic map(
            COORD              => (1, 0, 0),
            NUM_CONNECTION     => 2,
            CONNECTION         => ((0, 0, 0), (1, 1, 0)),
            BUFFER_DEPTH       => REFLECT_BUFFER_DEPTH,
            C_AXIS_TDATA_WIDTH => C_AXIS_TDATA_WIDTH
        )
        port map(
            clk => clk,
            rst => rst,

            s_axis_tready => m_axis_tready_vec(1),
            s_axis_tdata  => m_axis_tdata_vec(1),
            s_axis_tstrb  => m_axis_tstrb_vec((C_AXIS_TDATA_WIDTH/8) * (1 + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * 1),
            s_axis_tlast  => m_axis_tlast_vec(1),
            s_axis_tvalid => m_axis_tvalid_vec(1),

            m_axis_tvalid => s_axis_tvalid_vec(1),
            m_axis_tdata  => s_axis_tdata_vec(1),
            m_axis_tstrb  => s_axis_tstrb_vec((C_AXIS_TDATA_WIDTH/8) * (1 + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * 1),
            m_axis_tlast  => s_axis_tlast_vec(1),
            m_axis_tready => s_axis_tready_vec(1)
        );

    inst_tile_reflect_2 : entity work.tile_reflect
        generic map(
            COORD              => (0, 1, 0),
            NUM_CONNECTION     => 2,
            CONNECTION         => ((1, 1, 0), (0, 0, 0)),
            BUFFER_DEPTH       => REFLECT_BUFFER_DEPTH,
            C_AXIS_TDATA_WIDTH => C_AXIS_TDATA_WIDTH
        )
        port map(
            clk => clk,
            rst => rst,

            s_axis_tready => m_axis_tready_vec(2),
            s_axis_tdata  => m_axis_tdata_vec(2),
            s_axis_tstrb  => m_axis_tstrb_vec((C_AXIS_TDATA_WIDTH/8) * (2 + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * 2),
            s_axis_tlast  => m_axis_tlast_vec(2),
            s_axis_tvalid => m_axis_tvalid_vec(2),

            m_axis_tvalid => s_axis_tvalid_vec(2),
            m_axis_tdata  => s_axis_tdata_vec(2),
            m_axis_tstrb  => s_axis_tstrb_vec((C_AXIS_TDATA_WIDTH/8) * (2 + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * 2),
            m_axis_tlast  => s_axis_tlast_vec(2),
            m_axis_tready => s_axis_tready_vec(2)
        );

    inst_tile_reflect_3 : entity work.tile_reflect
        generic map(
            COORD              => (1, 1, 0),
            NUM_CONNECTION     => 2,
            CONNECTION         => ((0, 1, 0), (1, 0, 0)),
            BUFFER_DEPTH       => REFLECT_BUFFER_DEPTH,
            C_AXIS_TDATA_WIDTH => C_AXIS_TDATA_WIDTH
        )
        port map(
            clk => clk,
            rst => rst,

            s_axis_tready => m_axis_tready_vec(3),
            s_axis_tdata  => m_axis_tdata_vec(3),
            s_axis_tstrb  => m_axis_tstrb_vec((C_AXIS_TDATA_WIDTH/8) * (3 + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * 3),
            s_axis_tlast  => m_axis_tlast_vec(3),
            s_axis_tvalid => m_axis_tvalid_vec(3),

            m_axis_tvalid => s_axis_tvalid_vec(3),
            m_axis_tdata  => s_axis_tdata_vec(3),
            m_axis_tstrb  => s_axis_tstrb_vec((C_AXIS_TDATA_WIDTH/8) * (3 + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * 3),
            m_axis_tlast  => s_axis_tlast_vec(3),
            m_axis_tready => s_axis_tready_vec(3)
        );

end architecture;