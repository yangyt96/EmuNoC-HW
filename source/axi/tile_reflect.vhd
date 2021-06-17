library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

use work.NOC_3D_PACKAGE.all;

entity tile_reflect is
    generic (
        C_AXIS_TDATA_WIDTH : Integer := flit_size;

        BUFFER_DEPTH : Integer := 2;

        COORD             : integer_vec   := (0, 0, 0);
        NUM_CONNECTION    : Integer       := 2;
        CONNECTION        : integer_array := ((1, 1, 1), (2, 2, 2));
        MAX_X_DIM         : Integer       := max_x_dim;
        MAX_Y_DIM         : Integer       := max_y_dim;
        MAX_Z_DIM         : Integer       := max_Z_dim;
        PKT_LEN_BIT_WIDTH : Integer       := packet_len_width;
        X_ADDR_WIDTH      : Integer       := x_addr_width;
        Y_ADDR_WIDTH      : Integer       := y_addr_width;
        Z_ADDR_WIDTH      : Integer       := z_addr_width
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

architecture behave of tile_reflect is

    function create_header(xs : Integer; ys : Integer; zs : Integer; xd : Integer; yd : Integer; zd : Integer; len : Integer) return flit is
        variable ret    : flit := (others => '0');
        variable offset : Integer;
    begin
        ret(packet_len_width - 1 downto 0) := Std_logic_vector(to_unsigned(len, packet_len_width));

        offset                                       := packet_len_width;
        ret(x_addr_width + offset - 1 downto offset) := Std_logic_vector(to_unsigned(xd, x_addr_width));
        offset                                       := offset + x_addr_width;
        ret(y_addr_width + offset - 1 downto offset) := Std_logic_vector(to_unsigned(yd, y_addr_width));
        offset                                       := offset + y_addr_width;
        ret(z_addr_width + offset - 1 downto offset) := Std_logic_vector(to_unsigned(zd, z_addr_width));

        offset                                       := offset + z_addr_width;
        ret(x_addr_width + offset - 1 downto offset) := Std_logic_vector(to_unsigned(xs, x_addr_width));
        offset                                       := offset + x_addr_width;
        ret(y_addr_width + offset - 1 downto offset) := Std_logic_vector(to_unsigned(ys, y_addr_width));
        offset                                       := offset + y_addr_width;
        ret(z_addr_width + offset - 1 downto offset) := Std_logic_vector(to_unsigned(zs, z_addr_width));

        return ret;
    end function;

    type t_STATE is(
    s_IDLE,
    s_INIT,
    s_WORK,
    s_WDONE
    );

    signal state_recv : t_STATE;
    signal state_tran : t_STATE;

    signal tran_data      : flit;
    signal tran_data_tmp  : flit;
    signal tran_tlast_ctr : Integer;
    signal tran_num_ctr   : Integer;

    signal fifo_write_en    : Std_logic;
    signal fifo_write_valid : Std_logic;
    signal fifo_data_in     : Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal fifo_read_en     : Std_logic;
    signal fifo_read_valid  : Std_logic;
    signal fifo_data_out    : Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal fifo_count       : Integer;

begin
    -- temporary
    -- I/O connection
    s_axis_tready <= '1' when state_recv = s_WORK else
        '0';
    m_axis_tstrb  <= (others => '1');
    m_axis_tdata  <= tran_data_tmp;
    m_axis_tvalid <= '1' when state_tran = s_WORK and tran_tlast_ctr > 0 else
        '0';
    m_axis_tlast <= '1' when tran_tlast_ctr = 1 else
        '0';

    -- Internal connection
    fifo_data_in  <= s_axis_tdata;
    fifo_write_en <= '1' when state_recv = s_IDLE and s_axis_tvalid = '1' else
        '0';
    fifo_read_en <= '1' when state_tran = s_WDONE and tran_num_ctr < 0 else
        '0';

    tran_data_tmp(tran_data_tmp'length - 1 downto tran_data_tmp'length - packet_len_width) <= Std_logic_vector(to_unsigned(tran_tlast_ctr mod (max_packet_len + 1), packet_len_width));
    tran_data_tmp(tran_data_tmp'length - packet_len_width - 1 downto 0)                    <= tran_data(tran_data_tmp'length - packet_len_width - 1 downto 0);
    -- tran_data_tmp <= tran_data;

    -- fsm recv
    process (clk, rst)
    begin
        if rst = RST_LVL then
            state_recv <= s_IDLE;
        elsif rising_edge(clk) then
            case state_recv is

                when s_IDLE =>
                    if s_axis_tvalid = '1' and fifo_write_valid = '1' then
                        state_recv <= s_INIT;
                    end if;

                when s_INIT =>
                    state_recv <= s_WORK;

                when s_WORK =>
                    if s_axis_tlast = '1' and s_axis_tvalid = '1' then
                        state_recv <= s_WDONE;
                    end if;

                when s_WDONE =>
                    state_recv <= s_IDLE;

            end case;
        end if;
    end process;

    -- fsm tran
    process (clk, rst)
    begin
        if rst = RST_LVL then
            state_tran <= s_IDLE;
        elsif rising_edge(clk) then

            case state_tran is

                when s_IDLE =>
                    if fifo_read_valid = '1' then
                        state_tran <= s_INIT;
                    end if;

                when s_INIT =>
                    state_tran <= s_WORK;

                when s_WORK =>
                    if tran_tlast_ctr = 0 then
                        state_tran <= s_WDONE;
                    end if;

                when s_WDONE =>
                    if tran_num_ctr >= 0 then
                        state_tran <= s_INIT;
                    elsif tran_num_ctr < 0 then
                        state_tran <= s_IDLE;
                    end if;

            end case;
        end if;
    end process;

    -- tlast ctr
    process (clk, rst)
    begin
        if rst = RST_LVL then
            tran_tlast_ctr <= 0;
        elsif rising_edge(clk) then
            if (state_tran = s_IDLE and fifo_read_valid = '1') or (state_tran = s_WDONE and tran_num_ctr >= 0) then
                tran_tlast_ctr <= to_integer(unsigned(get_header_inf(fifo_data_out).packet_length)) - 1;
            elsif state_tran = s_WORK and m_axis_tready = '1' and tran_tlast_ctr > 0 then
                tran_tlast_ctr <= tran_tlast_ctr - 1;
            end if;
        end if;
    end process;

    -- tran num ctr
    process (clk, rst)
    begin
        if rst = RST_LVL then
            tran_num_ctr <= NUM_CONNECTION - 1;
        elsif rising_edge(clk) then
            if state_tran = s_INIT then
                tran_num_ctr <= tran_num_ctr - 1;
            elsif state_tran = s_WDONE and tran_num_ctr < 0 then -- tran_num_ctr = -1
                tran_num_ctr <= NUM_CONNECTION - 1;
            end if;
        end if;
    end process;

    -- tran data
    process (clk, rst)
    begin
        if rst = RST_LVL then
            tran_data <= (others => '0');
        elsif rising_edge(clk) then
            if (state_tran = s_IDLE and fifo_read_valid = '1') or (state_tran = s_WDONE and tran_num_ctr >= 0) then
                tran_data <= create_header(
                    COORD(0), COORD(1), COORD(2),
                    CONNECTION(tran_num_ctr, 0),
                    CONNECTION(tran_num_ctr, 1),
                    CONNECTION(tran_num_ctr, 2),
                    to_integer(unsigned(get_header_inf(fifo_data_out).packet_length)) - 1
                    );
            end if;
        end if;
    end process;

    inst_fifo : entity work.ring_fifo
        generic map(
            BUFFER_DEPTH => BUFFER_DEPTH,
            DATA_WIDTH   => C_AXIS_TDATA_WIDTH,
            RST_LVL      => RST_LVL
        )
        port map(
            clk => clk,
            rst => rst,

            write_en    => fifo_write_en,
            write_valid => fifo_write_valid,
            data_in     => fifo_data_in,

            read_en    => fifo_read_en,
            read_valid => fifo_read_valid,
            data_out   => fifo_data_out,

            count => fifo_count
        );

end architecture;