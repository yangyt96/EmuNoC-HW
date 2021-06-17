library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

use work.NOC_3D_PACKAGE.all;

entity tile_return is
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

architecture behave of tile_return is

    function address_interchange(x : flit) return flit is
        constant addr_width            : Integer := x_addr_width + y_addr_width + z_addr_width;
        variable ret                   : flit    := (others => '0');
        variable addr_dst              : Std_logic_vector(addr_width - 1 downto 0);
        variable addr_src              : Std_logic_vector(addr_width - 1 downto 0);
        variable pkt_len               : Std_logic_vector(packet_len_width - 1 downto 0);
        variable offset                : Integer;
    begin
        pkt_len  := x(packet_len_width - 1 downto 0);
        offset   := packet_len_width;
        addr_src := x(addr_width + offset - 1 downto offset);
        offset   := offset + addr_width;
        addr_dst := x(addr_width + offset - 1 downto offset);
        offset   := offset + addr_width;

        ret(flit_size - 1 downto offset)           := x(flit_size - 1 downto offset);
        offset                                     := offset - addr_width;
        ret(addr_width + offset - 1 downto offset) := addr_src;
        offset                                     := offset - addr_width;
        ret(addr_width + offset - 1 downto offset) := addr_dst;
        ret(packet_len_width - 1 downto 0)         := pkt_len;

        return ret;
    end function;

begin

    m_axis_tvalid <= s_axis_tvalid;
    m_axis_tstrb  <= s_axis_tstrb;
    m_axis_tlast  <= s_axis_tlast;
    s_axis_tready <= m_axis_tready;
    m_axis_tdata  <= address_interchange(s_axis_tdata);

end architecture;