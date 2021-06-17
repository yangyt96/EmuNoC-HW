library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

use work.NOC_3D_PACKAGE.all;

entity top_return is
    generic (
        IO_POS : Integer := 0; -- the position of arm core connect to router

        M_AXIS_BUFFER_DEPTH  : Integer := 31;
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

architecture behave of top_return is

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

            C_AXIS_TDATA_WIDTH   => C_AXIS_TDATA_WIDTH,
            C_S_AXIS_TADDR_WIDTH => C_S_AXIS_TADDR_WIDTH
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

    gen_reflect : for i in 0 to NUM_ROUTER - 1 generate
        gen_inst : if i /= IO_POS generate
            inst_reflect : entity work.tile_return
                generic map(
                    C_AXIS_TDATA_WIDTH => C_AXIS_TDATA_WIDTH
                )
                port map(
                    clk => clk,
                    rst => rst,

                    s_axis_tready => m_axis_tready_vec(i),
                    s_axis_tdata  => m_axis_tdata_vec(i),
                    s_axis_tstrb  => m_axis_tstrb_vec((C_AXIS_TDATA_WIDTH/8) * (i + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * i),
                    s_axis_tlast  => m_axis_tlast_vec(i),
                    s_axis_tvalid => m_axis_tvalid_vec(i),

                    m_axis_tvalid => s_axis_tvalid_vec(i),
                    m_axis_tdata  => s_axis_tdata_vec(i),
                    m_axis_tstrb  => s_axis_tstrb_vec((C_AXIS_TDATA_WIDTH/8) * (i + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * i),
                    m_axis_tlast  => s_axis_tlast_vec(i),
                    m_axis_tready => s_axis_tready_vec(i)
                );
        end generate gen_inst;
    end generate gen_reflect;

end architecture;