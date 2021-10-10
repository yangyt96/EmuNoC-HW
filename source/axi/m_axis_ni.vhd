-------------------------------------------------------------------------------
-- Title      :
-- Project    :
-------------------------------------------------------------------------------
-- File       : m_axis_ni.vhd
-- Author     : Yee Yang Tan  <yee.yang.tan@ice.rwth-aachen.de>
-- Company    : RWTH Aachen University
-- Created    : 2021-05-23
-- Last update: 2021-05-23
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: AXI Stream port for NoC router to receive the data from NoC.
-------------------------------------------------------------------------------
-- Copyright (c) 2021
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2021-05-23  1.0      Yang    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.NOC_3D_PACKAGE.all;

entity M_AXIS_NI is
    generic (
        C_M_AXIS_TDATA_WIDTH : Integer := 32;
        FLIT_SIZE            : Integer := 32;
        VC_NUM               : Integer := 2;
        BUFFER_DEPTH         : Integer := max_packet_len;

        RST_LVL : Std_logic := '0'
    );
    port (
        -- NoC router local port
        i_local_rx          : in Std_logic_vector(FLIT_SIZE - 1 downto 0);
        i_local_vc_write_rx : in Std_logic_vector(VC_NUM - 1 downto 0);
        o_local_incr_tx_vec : out Std_logic_vector(VC_NUM - 1 downto 0);

        -- AXI Stream Master interface
        M_AXIS_ACLK    : in Std_logic;
        M_AXIS_ARESETN : in Std_logic;
        M_AXIS_TVALID  : out Std_logic;
        M_AXIS_TDATA   : out Std_logic_vector(C_M_AXIS_TDATA_WIDTH - 1 downto 0);
        M_AXIS_TSTRB   : out Std_logic_vector((C_M_AXIS_TDATA_WIDTH/8) - 1 downto 0);
        M_AXIS_TLAST   : out Std_logic;
        M_AXIS_TREADY  : in Std_logic
    );
end M_AXIS_NI;

architecture implementation of M_AXIS_NI is
    -- Constants
    constant CNT_WIDTH : Integer := bit_width(BUFFER_DEPTH + 1);

    -- Data types
    type t_STATE is (
        s_IDLE,
        s_INIT,
        s_IDONE,
        s_WORK,
        s_WDONE
    );
    subtype t_PKT_LEN is unsigned(packet_len_width - 1 downto 0);
    type t_PKT_LEN_1D_ARR is array (Natural range <>) of t_PKT_LEN;
    subtype t_FIFO_CNT is Std_logic_vector(CNT_WIDTH - 1 downto 0);
    type t_FIFO_CNT_1D_ARR is array (Natural range <>) of t_FIFO_CNT;

    -- Signals
    signal state : t_STATE;

    signal tlast_counter : Integer range 0 to max_packet_len;

    signal fifos_read_en    : Std_logic_vector(VC_NUM - 1 downto 0);
    signal fifos_read_valid : Std_logic_vector(VC_NUM - 1 downto 0);
    signal fifos_data_out   : flit_vector(VC_NUM - 1 downto 0);
    signal fifos_count      : t_FIFO_CNT_1D_ARR(VC_NUM - 1 downto 0);

    signal pkts_len    : t_PKT_LEN_1D_ARR(VC_NUM - 1 downto 0);
    signal pkts_arrive : Std_logic_vector(VC_NUM - 1 downto 0);

    signal taddr    : Integer range 0 to VC_NUM - 1;
    signal shift_vc : Std_logic_vector(VC_NUM - 1 downto 0);

    signal clz_data  : Std_logic_vector(VC_NUM - 1 downto 0); -- this need to be reversed assigned
    signal clz_valid : Std_logic;
    signal clz_count : Std_logic_vector(bit_width(VC_NUM) - 1 downto 0);

begin
    -- I/O connection
    o_local_incr_tx_vec <= fifos_read_en;

    M_AXIS_TVALID <= '1' when state = s_WORK and fifos_read_valid(taddr) = '1' and tlast_counter > 0 else
        '0';
    M_AXIS_TDATA <= fifos_data_out(taddr);
    M_AXIS_TSTRB <= (others => '1');
    M_AXIS_TLAST <= '1' when tlast_counter = 1 else
        '0';

    -- Internal signal
    fifos_read_en <= shift_vc when state = s_WORK and fifos_read_valid(taddr) = '1' and tlast_counter > 0 and M_AXIS_TREADY = '1' else
        (others => '0');
    shift_vc <= Std_logic_vector(shift_left(to_unsigned(1, shift_vc'length), taddr));

    gen_pkts_arrive : for i in 0 to VC_NUM - 1 generate
        pkts_len(i)    <= unsigned(get_header_inf(fifos_data_out(i)).packet_length);
        pkts_arrive(i) <= '1' when unsigned(fifos_count(i)) >= pkts_len(i) and fifos_read_valid(i) = '1' else
        '0';
    end generate;

    clz_data <= pkts_arrive;

    -- determine the taddr
    process (M_AXIS_ACLK, M_AXIS_ARESETN)
    begin
        if M_AXIS_ARESETN = RST_LVL then
            taddr <= 0;
        elsif rising_edge(M_AXIS_ACLK) then
            if state = s_IDLE and or_reduce(pkts_arrive) = '1' then
                taddr <= to_integer(unsigned(clz_count));
            end if;
        end if;
    end process;

    -- tlast counter
    process (M_AXIS_ACLK, M_AXIS_ARESETN)
    begin
        if M_AXIS_ARESETN = RST_LVL then
            tlast_counter <= 0;
        elsif rising_edge(M_AXIS_ACLK) then
            if state = s_INIT then
                tlast_counter <= to_integer(unsigned(get_header_inf(fifos_data_out(taddr)).packet_length));
            elsif state = s_WORK and or_reduce(fifos_read_en) = '1' then
                tlast_counter <= tlast_counter - 1;
            end if;
        end if;
    end process;

    -- fsm
    process (M_AXIS_ACLK, M_AXIS_ARESETN)
    begin
        if M_AXIS_ARESETN = RST_LVL then
            state <= s_IDLE;
        elsif rising_edge(M_AXIS_ACLK) then

            case state is

                when s_IDLE =>
                    if or_reduce(pkts_arrive) = '1' then
                        state <= s_INIT;
                    end if;

                when s_INIT =>
                    state <= s_IDONE;

                when s_IDONE =>
                    state <= s_WORK;

                when s_WORK =>
                    if tlast_counter = 0 then
                        state <= s_WDONE;
                    end if;

                when s_WDONE =>
                    state <= s_IDLE;

            end case;
        end if;
    end process;

    -- instances
    inst_clz : entity work.count_trail_zero
        generic map(
            DATA_WIDTH => VC_NUM,
            CNT_WIDTH  => bit_width(VC_NUM)
        )
        port map(
            i_data  => clz_data,
            o_valid => clz_valid,
            o_count => clz_count
        );

    gen_fifo : for i in 0 to VC_NUM - 1 generate
        inst_ring_fifo : entity work.ring_fifo
            generic map(
                BUFFER_DEPTH => BUFFER_DEPTH,
                DATA_WIDTH   => FLIT_SIZE,
                RST_LVL      => RST_LVL,
                CNT_WIDTH    => CNT_WIDTH
            )
            port map(
                clk => M_AXIS_ACLK,
                rst => M_AXIS_ARESETN,

                count => fifos_count(i),

                i_wdata => i_local_rx,
                i_wen   => i_local_vc_write_rx(i),

                o_rdata  => fifos_data_out(i),
                i_ren    => fifos_read_en(i),
                o_rvalid => fifos_read_valid(i)
            );
    end generate;

end implementation;