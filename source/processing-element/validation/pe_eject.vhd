library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

use work.NOC_3D_PACKAGE.all;

entity pe_eject is
    generic (
        BUFFER_DEPTH       : Integer   := 1;
        C_AXIS_TDATA_WIDTH : Integer   := flit_size;
        RST_LVL            : Std_logic := RST_LVL
    );
    port (
        clk  : in Std_logic;
        rst  : in Std_logic;
        clkh : in Std_logic;

        o_fifo_rdata  : out Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
        i_fifo_ren    : in Std_logic;
        o_fifo_rvalid : out Std_logic;

        s_axis_tvalid : in Std_logic;
        s_axis_tdata  : in Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
        s_axis_tstrb  : in Std_logic_vector((C_AXIS_TDATA_WIDTH/8) - 1 downto 0);
        s_axis_tlast  : in Std_logic;
        s_axis_tready : out Std_logic
    );
end entity;

architecture implementation of pe_eject is

    type t_STATE is (
        s_IDLE,
        s_WORK,
        s_WDONE
    );

    signal state : t_STATE;

    signal axis_tready : Std_logic;

    signal fifo_wen      : Std_logic;
    signal fifo_wen_flag : Std_logic;
    signal fifo_wdata    : Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal fifo_wvalid   : Std_logic;

begin
    -- IO
    s_axis_tready <= axis_tready;

    -- Internal wire
    axis_tready <= '1' when state = s_WORK and s_axis_tvalid = '1' else
        '0';

    -- Internal register
    process (clk, rst, fifo_wen, fifo_wen_flag)
    begin
        if rst = RST_LVL then
            fifo_wen      <= '0';
            fifo_wen_flag <= '0';
        elsif rising_edge(clk) then

            if state = s_WDONE and fifo_wen = '0' and fifo_wen_flag = '0' and fifo_wvalid = '1' then
                fifo_wen <= '1';
            else
                fifo_wen <= '0';
            end if;

            if state = s_WDONE and fifo_wen_flag = '0' and fifo_wvalid = '1' then
                fifo_wen_flag <= '1';
            elsif state = s_IDLE then
                fifo_wen_flag <= '0';
            end if;

        end if;
    end process;

    process (clkh, rst, fifo_wdata)
    begin
        if rst = RST_LVL then
            fifo_wdata <= (others => '0');
        elsif rising_edge(clkh) then
            if state = s_WORK and s_axis_tvalid = '1' and axis_tready = '1' then
                fifo_wdata <= s_axis_tdata;
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
                    if s_axis_tvalid = '1' then
                        state <= s_WORK;
                    end if;

                when s_WORK => --! if halted, stop it at here to prevent fifo_wen halted at '1'
                    if s_axis_tvalid = '1' and s_axis_tlast = '1' and axis_tready = '1' then
                        state <= s_WDONE;
                    end if;

                when s_WDONE =>
                    if fifo_wen_flag = '1' and fifo_wen = '0' then
                        state <= s_IDLE;
                    end if;

            end case;
        end if;
    end process;

    -- Instances
    inst_ring_fifo : entity work.ring_fifo
        generic map(
            BUFFER_DEPTH => BUFFER_DEPTH,
            DATA_WIDTH   => C_AXIS_TDATA_WIDTH,
            RST_LVL      => RST_LVL
        )
        port map(
            clk => clk,
            rst => rst,

            i_wdata  => fifo_wdata,
            i_wen    => fifo_wen,
            o_wvalid => fifo_wvalid,

            o_rdata  => o_fifo_rdata,
            i_ren    => i_fifo_ren,
            o_rvalid => o_fifo_rvalid

        );

end implementation;