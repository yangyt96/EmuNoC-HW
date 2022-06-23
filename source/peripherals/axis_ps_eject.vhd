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
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.NOC_3D_PACKAGE.all;

entity axis_ps_eject is
    generic (
        CNT_WIDTH          : Integer := flit_size;
        C_AXIS_TDATA_WIDTH : Integer := flit_size;

        PE_NUM           : Integer := max_x_dim * max_y_dim * max_z_dim;
        PE_ADDR_WIDTH    : Integer := bit_width(max_x_dim * max_y_dim * max_z_dim);
        MAX_X_DIM        : Integer := max_x_dim;
        MAX_Y_DIM        : Integer := max_y_dim;
        MAX_Z_DIM        : Integer := max_Z_dim;
        PACKET_LEN_WIDTH : Integer := packet_len_width;
        X_ADDR_WIDTH     : Integer := x_addr_width;
        Y_ADDR_WIDTH     : Integer := y_addr_width;
        Z_ADDR_WIDTH     : Integer := z_addr_width;

        RST_LVL : Std_logic := RST_LVL
    );
    port (
        clk : in Std_logic;
        rst : in Std_logic;

        m_axis_tvalid : out Std_logic;
        m_axis_tdata  : out Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
        m_axis_tstrb  : out Std_logic_vector((C_AXIS_TDATA_WIDTH/8) - 1 downto 0);
        m_axis_tlast  : out Std_logic;
        m_axis_tready : in Std_logic;

        i_fifos_rdata  : in flit_vector(PE_NUM - 1 downto 0);
        o_fifos_ren    : out Std_logic_vector(PE_NUM - 1 downto 0);
        i_fifos_rvalid : in Std_logic_vector(PE_NUM - 1 downto 0);

        i_halt      : in Std_logic;
        o_halt      : out Std_logic;
        i_noc_count : in Std_logic_vector(CNT_WIDTH - 1 downto 0)
    );
end entity;

architecture implementation of axis_ps_eject is
    function iconv_hdr(var : flit) return flit is
        variable ret           : flit := (others => '0');
        variable offset_var    : Integer;
        variable offset_ret    : Integer;
        variable dst           : Integer;
        variable xd, yd, zd    : Integer;
        variable xs, ys, zs    : Integer;
    begin
        offset_var := PACKET_LEN_WIDTH;
        xd         := to_integer(unsigned(var(offset_var + X_ADDR_WIDTH - 1 downto offset_var)));
        offset_var := offset_var + X_ADDR_WIDTH;
        yd         := to_integer(unsigned(var(offset_var + Y_ADDR_WIDTH - 1 downto offset_var)));
        offset_var := offset_var + Y_ADDR_WIDTH;
        zd         := to_integer(unsigned(var(offset_var + Z_ADDR_WIDTH - 1 downto offset_var)));
        offset_var := offset_var + Z_ADDR_WIDTH;
        xs         := to_integer(unsigned(var(offset_var + X_ADDR_WIDTH - 1 downto offset_var)));
        offset_var := offset_var + X_ADDR_WIDTH;
        ys         := to_integer(unsigned(var(offset_var + Y_ADDR_WIDTH - 1 downto offset_var)));
        offset_var := offset_var + Y_ADDR_WIDTH;
        zs         := to_integer(unsigned(var(offset_var + Z_ADDR_WIDTH - 1 downto offset_var)));
        offset_var := offset_var + Z_ADDR_WIDTH;

        offset_ret                   := PACKET_LEN_WIDTH;
        ret(offset_ret - 1 downto 0) := var(offset_ret - 1 downto 0);

        -- dst pos conversion
        ret(PE_ADDR_WIDTH + offset_ret - 1 downto offset_ret) := Std_logic_vector(to_unsigned(xd + yd * MAX_X_DIM + zd * MAX_X_DIM * MAX_Y_DIM, PE_ADDR_WIDTH));
        offset_ret                                            := offset_ret + PE_ADDR_WIDTH;
        -- src pos conversion
        ret(PE_ADDR_WIDTH + offset_ret - 1 downto offset_ret) := Std_logic_vector(to_unsigned(xs + ys * MAX_X_DIM + zs * MAX_X_DIM * MAX_Y_DIM, PE_ADDR_WIDTH));
        offset_ret                                            := offset_ret + PE_ADDR_WIDTH;

        if offset_var = offset_ret then
            ret(C_AXIS_TDATA_WIDTH - 1 downto offset_ret) := var(C_AXIS_TDATA_WIDTH - 1 downto offset_var);
        elsif offset_var > offset_ret then
            ret(C_AXIS_TDATA_WIDTH - (offset_var - offset_ret) - 1 downto offset_ret) := var(C_AXIS_TDATA_WIDTH - 1 downto offset_var);
        elsif offset_var < offset_ret then
            ret(C_AXIS_TDATA_WIDTH - 1 downto offset_ret) := var(C_AXIS_TDATA_WIDTH - (offset_ret - offset_var) - 1 downto offset_var);
        end if;

        return ret;
    end function;

    type t_STATE is (
        s_IDLE,
        s_CYC,
        s_ADDR,
        s_TRAN,
        s_ZERO
    );
    signal state : t_STATE;
    signal halt  : Std_logic;

    signal fifo_addr   : Integer range 0 to PE_NUM - 1;
    signal shift_fifo  : Std_logic_vector(PE_NUM - 1 downto 0);
    signal rotate_fifo : Std_logic_vector(PE_NUM - 1 downto 0);

    signal clz_data  : Std_logic_vector(PE_NUM - 1 downto 0); -- this need to be reversed assigned
    signal clz_valid : Std_logic;
    signal clz_count : Std_logic_vector(bit_width(PE_NUM) - 1 downto 0);
begin
    -- I/O
    m_axis_tstrb <= (others => '1');
    m_axis_tlast <= '1' when state = s_ZERO else
        '0';
    m_axis_tvalid <= '1' when state = s_CYC or state = s_TRAN or state = s_ZERO else
        '0';
    m_axis_tdata <= iconv_hdr(i_fifos_rdata(fifo_addr)) when state = s_TRAN else
        i_noc_count when state = s_CYC else
        (others => '0');

    o_fifos_ren <= shift_fifo when state = s_TRAN and m_axis_tready = '1' else
        (others => '0');
    o_halt <= halt;

    -- Internal wire
    halt        <= or_reduce(i_fifos_rvalid);
    shift_fifo  <= Std_logic_vector(shift_left(to_unsigned(1, shift_fifo'length), fifo_addr));
    rotate_fifo <= Std_logic_vector(rotate_right(unsigned(i_fifos_rvalid), fifo_addr));
    gen_swap_endian : for i in 0 to PE_NUM - 1 generate
        clz_data(i) <= rotate_fifo(PE_NUM - 1 - i);
    end generate;

    -- Internal register
    process (clk, rst)
    begin
        if rst = RST_LVL then
            fifo_addr <= 0;
        elsif rising_edge(clk) then

            if state = s_ADDR and halt = '1' then
                fifo_addr <= (fifo_addr + to_integer(unsigned(clz_count))) mod PE_NUM;
            end if;

            if state = s_TRAN and m_axis_tready = '1' then
                fifo_addr <= (fifo_addr + 1) mod PE_NUM;
            end if;

        end if;
    end process;

    -- fsm
    process (clk, rst)
    begin
        if rst = RST_LVL then
            state <= s_IDLE;
        elsif rising_edge(clk) then
            case state is
                when s_IDLE =>
                    if halt = '1' and i_halt = '1' then
                        state <= s_CYC;
                    end if;

                when s_CYC =>
                    if m_axis_tready = '1' then
                        state <= s_ADDR;
                    end if;

                when s_ADDR =>
                    if halt = '1' then
                        state <= s_TRAN;
                    elsif halt = '0' then
                        state <= s_ZERO;
                    end if;

                when s_TRAN =>
                    if m_axis_tready = '1' then
                        state <= s_ADDR;
                    end if;

                when s_ZERO =>
                    if m_axis_tready = '1' then
                        state <= s_IDLE;
                    end if;

            end case;
        end if;
    end process;

    -- instances
    inst_clz : entity work.count_lead_zero
        generic map(
            DATA_WIDTH => PE_NUM,
            CNT_WIDTH  => bit_width(PE_NUM)
        )
        port map(
            i_data  => clz_data,
            o_valid => clz_valid,
            o_count => clz_count
        );

end implementation;