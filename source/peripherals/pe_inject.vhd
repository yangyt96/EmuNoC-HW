library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

use work.NOC_3D_PACKAGE.all;

entity pe_inject is
    generic (
        BUFFER_DEPTH       : Integer   := 32;
        C_AXIS_TDATA_WIDTH : Integer   := flit_size;
        RST_LVL            : Std_logic := RST_LVL
    );
    port (
        clk  : in Std_logic;
        rst  : in Std_logic;
        clkh : in Std_logic;

        i_fifo_wdata  : in Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
        i_fifo_wen    : in Std_logic;
        o_fifo_wvalid : out Std_logic;

        m_axis_tvalid : out Std_logic;
        m_axis_tdata  : out Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
        m_axis_tstrb  : out Std_logic_vector((C_AXIS_TDATA_WIDTH/8) - 1 downto 0);
        m_axis_tlast  : out Std_logic;
        m_axis_tready : in Std_logic
    );
end entity;

architecture implementation of pe_inject is
    type t_STATE is (
        s_IDLE,
        s_INIT,
        s_IDONE,
        s_WORK,
        s_WDONE
    );

    signal state         : t_STATE;
    signal tlast_counter : Integer;

    signal fifo_ren      : Std_logic;
    signal fifo_ren_flag : Std_logic;
    signal fifo_rvalid   : Std_logic;
    signal fifo_rdata    : Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);

begin
    -- I/O
    m_axis_tvalid <= '1' when state = s_WORK and tlast_counter > 0 else
        '0';
    m_axis_tdata <= fifo_rdata;
    m_axis_tstrb <= (others => '1');
    m_axis_tlast <= '1' when tlast_counter = 1 else
        '0';

    -- Internal REG
    process (clk, rst, fifo_ren, fifo_ren_flag)
    begin
        if rst = RST_LVL then
            fifo_ren      <= '0';
            fifo_ren_flag <= '0';
        elsif rising_edge(clk) then

            if state = s_WDONE and fifo_ren = '0' and fifo_ren_flag = '0' and fifo_rvalid = '1' then
                fifo_ren <= '1';
            else
                fifo_ren <= '0';
            end if;

            if state = s_WDONE and fifo_ren_flag = '0' and fifo_rvalid = '1' then
                fifo_ren_flag <= '1';
            elsif state = s_IDLE then
                fifo_ren_flag <= '0';
            end if;

        end if;
    end process;

    process (clkh, rst, state, tlast_counter)
    begin
        if rst = RST_LVL then
            tlast_counter <= 0;
        elsif rising_edge(clkh) then

            if state = s_INIT then
                tlast_counter <= to_integer(unsigned(get_header_inf(fifo_rdata).packet_length));
            elsif state = s_WORK and m_axis_tready = '1' and tlast_counter > 0 then
                tlast_counter <= tlast_counter - 1;
            end if;

        end if;
    end process;

    -- FSM
    process (clkh, rst, state)
    begin
        if rst = RST_LVL then
            state <= s_IDLE;
        elsif rising_edge(clkh) then
            case state is

                when s_IDLE =>
                    if fifo_rvalid = '1' then
                        state <= s_INIT;
                    end if;

                when s_INIT =>
                    if fifo_rvalid = '1' then
                        state <= s_IDONE;
                    end if;

                when s_IDONE =>
                    state <= s_WORK;

                when s_WORK =>
                    if tlast_counter = 0 then
                        state <= s_WDONE;
                    end if;

                when s_WDONE =>
                    if fifo_ren_flag = '1' and fifo_ren = '0' then
                        state <= s_IDLE;
                    end if;

            end case;

        end if;
    end process;

    -- Instance
    inst_ring_fifo : entity work.ring_fifo
        generic map(
            BUFFER_DEPTH => BUFFER_DEPTH,
            DATA_WIDTH   => C_AXIS_TDATA_WIDTH,
            RST_LVL      => RST_LVL
        )
        port map(
            clk => clk,
            rst => rst,

            i_wdata  => i_fifo_wdata,
            i_wen    => i_fifo_wen,
            o_wvalid => o_fifo_wvalid,

            o_rdata  => fifo_rdata,
            i_ren    => fifo_ren,
            o_rvalid => fifo_rvalid

        );

end implementation;