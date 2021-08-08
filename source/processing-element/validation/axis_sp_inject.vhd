library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.NOC_3D_PACKAGE.all;

entity axis_sp_inject is
    generic (
        CNT_WIDTH : Integer := flit_size; -- only support 32-bit

        -- NOC
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

        s_axis_tvalid : in Std_logic;
        s_axis_tdata  : in Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
        s_axis_tstrb  : in Std_logic_vector((C_AXIS_TDATA_WIDTH/8) - 1 downto 0);
        s_axis_tlast  : in Std_logic;
        s_axis_tready : out Std_logic;

        o_fifo_wdata   : out Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
        o_fifos_wen    : out Std_logic_vector(PE_NUM - 1 downto 0);
        i_fifos_wvalid : in Std_logic_vector(PE_NUM - 1 downto 0);

        o_ub_count_wen : out Std_logic;
        o_ub_count     : out Std_logic_vector(CNT_WIDTH - 1 downto 0);
        i_noc_count    : in Std_logic_vector(CNT_WIDTH - 1 downto 0)
    );
end entity;

architecture implementation of axis_sp_inject is
    function conv_hdr(var : flit) return flit is
        variable ret          : flit := (others => '0');
        variable offset_var   : Integer;
        variable offset_ret   : Integer;
        variable dst          : Integer;
        variable src          : Integer;
    begin
        offset_ret := PACKET_LEN_WIDTH; -- might different length width
        offset_var := PACKET_LEN_WIDTH; -- might different length width

        dst        := to_integer(unsigned(var(PE_ADDR_WIDTH + offset_var - 1 downto offset_var)));
        offset_var := offset_var + PE_ADDR_WIDTH;
        src        := to_integer(unsigned(var(PE_ADDR_WIDTH + offset_var - 1 downto offset_var)));

        ret(offset_ret - 1 downto 0) := var(offset_ret - 1 downto 0);

        ret(X_ADDR_WIDTH + offset_ret - 1 downto offset_ret) := Std_logic_vector(to_unsigned(dst mod (MAX_X_DIM * MAX_Y_DIM) mod MAX_X_DIM, X_ADDR_WIDTH));
        offset_ret                                           := offset_ret + X_ADDR_WIDTH;
        ret(Y_ADDR_WIDTH + offset_ret - 1 downto offset_ret) := Std_logic_vector(to_unsigned(dst mod (MAX_X_DIM * MAX_Y_DIM) / MAX_X_DIM, Y_ADDR_WIDTH));
        offset_ret                                           := offset_ret + Y_ADDR_WIDTH;
        ret(Z_ADDR_WIDTH + offset_ret - 1 downto offset_ret) := Std_logic_vector(to_unsigned(dst / (MAX_X_DIM * MAX_Y_DIM), Z_ADDR_WIDTH));
        offset_ret                                           := offset_ret + Z_ADDR_WIDTH;
        ret(x_addr_width + offset_ret - 1 downto offset_ret) := Std_logic_vector(to_unsigned(src mod (MAX_X_DIM * MAX_Y_DIM) mod MAX_X_DIM, X_ADDR_WIDTH));
        offset_ret                                           := offset_ret + X_ADDR_WIDTH;
        ret(Y_ADDR_WIDTH + offset_ret - 1 downto offset_ret) := Std_logic_vector(to_unsigned(src mod (MAX_X_DIM * MAX_Y_DIM) / MAX_X_DIM, Y_ADDR_WIDTH));
        offset_ret                                           := offset_ret + Y_ADDR_WIDTH;
        ret(Z_ADDR_WIDTH + offset_ret - 1 downto offset_ret) := Std_logic_vector(to_unsigned(src / (MAX_X_DIM * MAX_Y_DIM), Z_ADDR_WIDTH));
        offset_ret                                           := offset_ret + Z_ADDR_WIDTH;

        offset_var := PACKET_LEN_WIDTH + 2 * PE_ADDR_WIDTH;
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
        s_RUN,
        s_INJECT,
        s_IDONE
    );
    signal state : t_STATE;

    signal count_flag : Std_logic;
    signal ub_count   : unsigned(CNT_WIDTH - 1 downto 0);

    signal axis_tready : Std_logic;
    signal fifos_wen   : Std_logic_vector(PE_NUM - 1 downto 0);

    signal src_id : Integer range 0 to PE_NUM - 1 := 0;

begin
    -- I/O
    s_axis_tready <= axis_tready;

    o_ub_count_wen <= '1' when state = s_RUN and axis_tready = '1' else
        '0';
    o_ub_count <= s_axis_tdata when state = s_RUN else
        (others => '0');
    o_fifo_wdata <= conv_hdr(s_axis_tdata) when state = s_INJECT else
        (others => '0');
    o_fifos_wen <= fifos_wen when state = s_INJECT and axis_tready = '1' else
        (others => '0');

    -- Internal wire
    src_id    <= to_integer(unsigned(s_axis_tdata(PACKET_LEN_WIDTH + PE_ADDR_WIDTH * 2 - 1 downto PACKET_LEN_WIDTH + PE_ADDR_WIDTH))) mod PE_NUM;
    fifos_wen <= Std_logic_vector(shift_left(to_unsigned(1, PE_NUM), src_id));

    -- Internal register
    process (clk, rst)
    begin
        if rst = RST_LVL then
            count_flag <= '0';
            ub_count   <= (others => '0');
        elsif rising_edge(clk) then

            if state = s_IDLE and s_axis_tvalid = '1' then
                count_flag <= '0';
            elsif state = s_RUN and s_axis_tvalid = '1' and axis_tready = '1' and count_flag = '0' then
                count_flag <= '1';
            elsif state = s_IDONE then
                count_flag <= '0';
            end if;

            if state = s_RUN and s_axis_tlast = '1' and s_axis_tvalid = '1' and axis_tready = '1' and count_flag = '0' then
                ub_count <= unsigned(s_axis_tdata);
            elsif state = s_RUN and s_axis_tvalid = '1' and axis_tready = '1' and count_flag = '0' then
                ub_count <= unsigned(s_axis_tdata);
            end if;

        end if;
    end process;

    process (clk, rst, count_flag)
    begin
        if rst = RST_LVL then
            axis_tready <= '0';
        elsif rising_edge(clk) then
            if state = s_RUN and axis_tready = '0' and s_axis_tvalid = '1' and count_flag = '0' then
                axis_tready <= '1';
            elsif state = s_INJECT and axis_tready = '0' and s_axis_tvalid = '1' and i_fifos_wvalid(src_id) = '1' then
                axis_tready <= '1';
            else
                axis_tready <= '0';
            end if;
        end if;
    end process;

    -- FSM
    process (clk, rst)
    begin
        if rst = RST_LVL then
            state <= s_IDLE;
        elsif rising_edge(clk) then
            case state is

                when s_IDLE =>
                    if s_axis_tvalid = '1' then
                        state <= s_RUN;
                    end if;

                when s_RUN =>
                    if s_axis_tvalid = '1' and s_axis_tlast = '1' and count_flag = '0' and axis_tready = '1' then
                        state <= s_IDLE;
                    elsif unsigned(i_noc_count) >= ub_count and count_flag = '1' then
                        state <= s_INJECT;
                    end if;

                when s_INJECT =>
                    if s_axis_tvalid = '1' and s_axis_tlast = '1' and axis_tready = '1' then
                        state <= s_IDONE;
                    end if;

                when s_IDONE =>
                    state <= s_IDLE;

            end case;
        end if;
    end process;

end implementation;