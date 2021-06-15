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
        BUFFER_DEPTH         : Integer := 32;

        RST_LVL : Std_logic := RST_LVL -- NOC_3D_PKG
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
    type t_STATE is (
        s_IDLE,
        s_INIT,
        s_IDONE,
        s_WORK,
        s_WDONE
    );
    signal state : t_STATE;

    signal tlast_counter : Integer;

    signal fifo_read_en    : Std_logic_vector(VC_NUM - 1 downto 0);
    signal fifo_read_valid : Std_logic_vector(VC_NUM - 1 downto 0);
    signal fifo_data_out   : flit_vector(VC_NUM - 1 downto 0);

    signal incr_vc        : Std_logic_vector(VC_NUM - 1 downto 0);
    signal incr_vc_addr   : Integer range 0 to VC_NUM - 1;
    signal incr_vc_cyclic : Std_logic_vector(VC_NUM - 1 downto 0);
    signal incr_vc_flag   : Std_logic;

    signal clz_data  : Std_logic_vector(VC_NUM - 1 downto 0); -- this need to be reversed assigned
    signal clz_valid : Std_logic;
    signal clz_count : Std_logic_vector(bit_width(VC_NUM) - 1 downto 0);

begin
    -- I/O connection
    o_local_incr_tx_vec <= fifo_read_en;

    M_AXIS_TVALID <= '1' when state = s_WORK and fifo_read_valid(incr_vc_addr) = '1' and tlast_counter > 0 else
        '0';
    M_AXIS_TDATA <= fifo_data_out(incr_vc_addr);
    M_AXIS_TSTRB <= (others => '1');
    M_AXIS_TLAST <= '1' when tlast_counter = 1 else
        '0';

    -- Internal signal
    fifo_read_en <= incr_vc when state = s_WORK and fifo_read_valid(incr_vc_addr) = '1' and tlast_counter > 0 and M_AXIS_TREADY = '1' else
        (others => '0');

    incr_vc        <= Std_logic_vector(shift_left(to_unsigned(1, incr_vc'length), incr_vc_addr));
    incr_vc_cyclic <= Std_logic_vector(rotate_right(unsigned(fifo_read_valid), incr_vc_addr));

    -- determine the vc addr
    process (M_AXIS_ACLK, M_AXIS_ARESETN)
    begin
        if M_AXIS_ARESETN = RST_LVL then
            incr_vc_addr <= 0;
            incr_vc_flag <= '0';
        elsif rising_edge(M_AXIS_ACLK) then
            if state = s_WDONE then
                incr_vc_addr <= (incr_vc_addr + 1) mod VC_NUM;
            elsif state = s_INIT and incr_vc_flag = '0' then
                incr_vc_addr <= (incr_vc_addr + to_integer(unsigned(clz_count))) mod VC_NUM;
                incr_vc_flag <= '1';
            elsif state = s_WDONE then
                incr_vc_flag <= '0';
            end if;
        end if;
    end process;

    -- data input for clz
    process (M_AXIS_ACLK, M_AXIS_ARESETN)
    begin
        if M_AXIS_ARESETN = RST_LVL then
            clz_data <= (others => '0');
        elsif rising_edge(M_AXIS_ACLK) then
            if state = s_IDLE and or_reduce(fifo_read_valid) = '1' then
                for i in 0 to VC_NUM - 1 loop
                    clz_data(i) <= incr_vc_cyclic(VC_NUM - 1 - i);
                end loop;
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
                    if or_reduce(fifo_read_valid) = '1' then
                        state <= s_INIT;
                    end if;

                when s_INIT =>
                    if incr_vc_flag = '1' then
                        state <= s_IDONE;
                    end if;

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

    -- tlast counter
    process (M_AXIS_ACLK, M_AXIS_ARESETN)
    begin
        if M_AXIS_ARESETN = RST_LVL then
            tlast_counter <= 0;
        elsif rising_edge(M_AXIS_ACLK) then
            if state = s_INIT and incr_vc_flag = '1' then
                tlast_counter <= to_integer(unsigned(get_header_inf(fifo_data_out(incr_vc_addr)).packet_length));
            elsif state = s_WORK and or_reduce(fifo_read_en) = '1' then
                tlast_counter <= tlast_counter - 1;
            end if;
        end if;
    end process;

    -- instances
    inst_clz : entity work.count_lead_zero
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
                RST_LVL      => RST_LVL
            )
            port map(
                clk => M_AXIS_ACLK,
                rst => M_AXIS_ARESETN,

                data_in  => i_local_rx,
                write_en => i_local_vc_write_rx(i),

                data_out   => fifo_data_out(i),
                read_en    => fifo_read_en(i),
                read_valid => fifo_read_valid(i)
            );
    end generate;

end implementation;