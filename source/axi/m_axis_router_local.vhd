-------------------------------------------------------------------------------
-- Title      :
-- Project    :
-------------------------------------------------------------------------------
-- File       : m_axis_router_local.vhd
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

entity M_AXIS_ROUTER_LOCAL is
    generic (
        FLIT_SIZE    : Integer := 32;
        VC_NUM       : Integer := 2;
        BUFFER_DEPTH : Integer := 32;

        C_M_AXIS_TDATA_WIDTH : Integer := 32;

        RST_LVL : Std_logic := RST_LVL -- NOC_3D_PKG
    );
    port (
        -- NoC router local port
        i_local_tx          : in Std_logic_vector(FLIT_SIZE - 1 downto 0);
        i_local_vc_write_tx : in Std_logic_vector(VC_NUM - 1 downto 0);
        o_local_incr_rx_vec : out Std_logic_vector(VC_NUM - 1 downto 0);

        -- AXI Stream Master interface
        M_AXIS_ACLK    : in Std_logic;
        M_AXIS_ARESETN : in Std_logic;
        M_AXIS_TVALID  : out Std_logic;
        M_AXIS_TDATA   : out Std_logic_vector(C_M_AXIS_TDATA_WIDTH - 1 downto 0);
        M_AXIS_TSTRB   : out Std_logic_vector((C_M_AXIS_TDATA_WIDTH/8) - 1 downto 0);
        M_AXIS_TLAST   : out Std_logic;
        M_AXIS_TREADY  : in Std_logic
    );
end M_AXIS_ROUTER_LOCAL;

architecture implementation of M_AXIS_ROUTER_LOCAL is
    type t_STATE is (
        s_IDLE,
        s_INIT_COUNT,
        s_SEND_STREAM
    );
    signal mst_exec_state : t_STATE;

    signal write_tx_valid : Std_logic;
    signal tlast_counter  : Integer;

    signal fifo_read_valid : Std_logic;
    signal fifo_read_en    : Std_logic;
    signal fifo_data_flit  : Std_logic_vector(FLIT_SIZE - 1 downto 0);
    signal fifo_data_incr  : Std_logic_vector(VC_NUM - 1 downto 0);
begin
    -- I/O connection
    M_AXIS_TVALID <= '1' when mst_exec_state = s_SEND_STREAM and fifo_read_valid = '1' and tlast_counter > 0 else
        '0';
    M_AXIS_TDATA <= fifo_data_flit;
    M_AXIS_TSTRB <= (others => '1');
    M_AXIS_TLAST <= '1' when tlast_counter = 1 else
        '0';
    o_local_incr_rx_vec <= fifo_data_incr when fifo_read_en = '1' else
        (others => '0');

    -- Internal signal
    write_tx_valid <= or_reduce(i_local_vc_write_tx);
    fifo_read_en   <= '1' when mst_exec_state = s_SEND_STREAM and fifo_read_valid = '1' and tlast_counter > 0 and M_AXIS_TREADY = '1' else
        '0';

    -- state machine
    process (M_AXIS_ACLK, M_AXIS_ARESETN)
    begin
        if M_AXIS_ARESETN = RST_LVL then
            mst_exec_state <= s_IDLE;
        elsif rising_edge(M_AXIS_ACLK) then
            case (mst_exec_state) is

                when s_IDLE =>
                    if fifo_read_valid = '1' then
                        mst_exec_state <= s_INIT_COUNT;
                    end if;

                when s_INIT_COUNT =>
                    mst_exec_state <= s_SEND_STREAM;

                when s_SEND_STREAM =>
                    if tlast_counter = 0 then
                        mst_exec_state <= s_IDLE;
                    end if;

            end case;
        end if;
    end process;

    -- tlast counter
    process (M_AXIS_ACLK, M_AXIS_ARESETN)
    begin
        if M_AXIS_ARESETN = RST_LVL then
            tlast_counter <= 0;
        elsif rising_edge(M_AXIS_ACLK) then
            if mst_exec_state = s_IDLE and fifo_read_valid = '1' then
                tlast_counter <= to_integer(unsigned(get_header_inf(fifo_data_flit).packet_length));
            elsif mst_exec_state = s_SEND_STREAM and fifo_read_en = '1' then
                tlast_counter <= tlast_counter - 1;
            end if;
        end if;
    end process;

    -- buffer to store flit from router
    inst_buffer_flit : entity work.ring_fifo
        generic map(
            BUFFER_DEPTH => BUFFER_DEPTH,
            DATA_WIDTH   => FLIT_SIZE,
            RST_LVL      => RST_LVL
        )
        port map(
            clk => M_AXIS_ACLK,
            rst => M_AXIS_ARESETN,

            data_in  => i_local_tx,
            write_en => write_tx_valid,

            data_out   => fifo_data_flit,
            read_en    => fifo_read_en,
            read_valid => fifo_read_valid
        );

    -- buffer to store incr address of router
    inst_buffer_incr : entity work.ring_fifo
        generic map(
            BUFFER_DEPTH => BUFFER_DEPTH,
            DATA_WIDTH   => VC_NUM,
            RST_LVL      => RST_LVL
        )
        port map(
            clk => M_AXIS_ACLK,
            rst => M_AXIS_ARESETN,

            data_in  => i_local_vc_write_tx,
            write_en => write_tx_valid,

            data_out => fifo_data_incr,
            read_en  => fifo_read_en
        );

end implementation;