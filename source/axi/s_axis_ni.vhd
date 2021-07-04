-------------------------------------------------------------------------------
-- Title      :
-- Project    :
-------------------------------------------------------------------------------
-- File       : s_axis_ni.vhd
-- Author     : Yee Yang Tan  <yee.yang.tan@ice.rwth-aachen.de>
-- Company    : RWTH Aachen University
-- Created    : 2021-05-21
-- Last update: 2021-05-21
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: AXI Stream port for NoC router to transfer the data to NoC.
--              The 1st data to send must contain the flit header information,
--              such as destination address and packet length.
-------------------------------------------------------------------------------
-- Copyright (c) 2021
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2021-05-21  1.0      Yang    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.NOC_3D_PACKAGE.all;

entity S_AXIS_NI is
    generic (
        C_S_AXIS_TDATA_WIDTH : Integer := 32; -- must same size as FLIT_SIZE
        FLIT_SIZE            : Integer := 32;
        VC_NUM               : Integer := 2;
        ROUTER_CREDIT        : Integer := 2;
        WAIT_CLK             : Integer := 2;

        RST_LVL : Std_logic := '0'
    );
    port (
        -- port to router local input flit
        o_local_tx          : out Std_logic_vector(FLIT_SIZE - 1 downto 0);
        o_local_vc_write_tx : out Std_logic_vector(VC_NUM - 1 downto 0);
        i_local_incr_rx_vec : in Std_logic_vector(VC_NUM - 1 downto 0);

        -- AXI Stream Slave interface
        S_AXIS_ACLK    : in Std_logic;
        S_AXIS_ARESETN : in Std_logic;
        S_AXIS_TREADY  : out Std_logic;                                              -- Ready to accept data in
        S_AXIS_TDATA   : in Std_logic_vector(C_S_AXIS_TDATA_WIDTH - 1 downto 0);     -- Data in
        S_AXIS_TSTRB   : in Std_logic_vector((C_S_AXIS_TDATA_WIDTH/8) - 1 downto 0); -- Byte qualifier
        S_AXIS_TLAST   : in Std_logic;                                               -- Indicates boundary of last packet
        S_AXIS_TVALID  : in Std_logic                                                -- Data is in valid

    );
end S_AXIS_NI;

architecture arch_imp of S_AXIS_NI is
    -- Data type
    type INT_ARR is array (Integer range <>) of Integer;
    type t_STATE is (
        s_IDLE,
        s_WORK,
        s_WDONE
    );
    signal state : t_STATE;

    -- Internal
    signal credit  : Integer                      := 0;
    signal credits : INT_ARR(VC_NUM - 1 downto 0) := (others => ROUTER_CREDIT);

    signal taddr                      : Integer range 0 to VC_NUM - 1;
    signal taddr_to_local_vc_write_rx : Std_logic_vector(VC_NUM - 1 downto 0);

    signal axis_tready : Std_logic;

begin
    -- I/O Connections assignments
    S_AXIS_TREADY       <= axis_tready;
    o_local_tx          <= S_AXIS_TDATA;
    o_local_vc_write_tx <= taddr_to_local_vc_write_rx when axis_tready = '1' else
        (others => '0');

    -- Internal
    taddr_to_local_vc_write_rx <= Std_logic_vector(shift_left(to_unsigned(1, VC_NUM), taddr));

    axis_tready <= '1' when state = s_WORK and credit > 0 and S_AXIS_TVALID = '1' else
        '0';

    credit <= credits(taddr);

    -- fsm
    process (S_AXIS_ACLK, S_AXIS_ARESETN)
    begin
        if S_AXIS_ARESETN = RST_LVL then
            state <= s_IDLE;
        elsif rising_edge(S_AXIS_ACLK) then
            case state is
                when s_IDLE =>
                    if S_AXIS_TVALID = '1' then
                        state <= s_WORK;
                    end if;

                when s_WORK =>
                    if axis_tready = '1' and S_AXIS_TVALID = '1' and S_AXIS_TLAST = '1' then
                        state <= s_WDONE;
                    end if;

                when s_WDONE =>
                    state <= s_IDLE;

            end case;
        end if;
    end process;

    -- det vc addr, flag and wait timer
    process (S_AXIS_ACLK, S_AXIS_ARESETN)
    begin
        if S_AXIS_ARESETN = RST_LVL then
            taddr <= 0;
        elsif rising_edge(S_AXIS_ACLK) then
            if state = s_WDONE then
                taddr <= (taddr + 1) mod VC_NUM;
            end if;
        end if;
    end process;

    gen_credits : for i in 0 to vc_num - 1 generate
        process (S_AXIS_ACLK, S_AXIS_ARESETN, axis_tready, i_local_incr_rx_vec, taddr_to_local_vc_write_rx)
        begin
            if S_AXIS_ARESETN = RST_LVL then
                credits(i) <= ROUTER_CREDIT;
            elsif rising_edge(S_AXIS_ACLK) then

                if (credits(i) > 0 and axis_tready = '1' and i_local_incr_rx_vec(i) = '0' and taddr_to_local_vc_write_rx(i) = '1') then
                    credits(i) <= credits(i) - 1;
                elsif (axis_tready = '1' and i_local_incr_rx_vec(i) = '1' and taddr_to_local_vc_write_rx(i) = '1') then
                    credits(i) <= credits(i);
                elsif (credits(i) < ROUTER_CREDIT and i_local_incr_rx_vec(i) = '1') then
                    credits(i) <= credits(i) + 1;
                end if;

            end if;
        end process;
    end generate gen_credits;

end arch_imp;