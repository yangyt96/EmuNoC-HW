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
use ieee.numeric_std.all;

use work.NOC_3D_PACKAGE.all;

entity S_AXIS_TRAFFIC_REC is
    generic (
        rec_time_text : String := "receive_time_noc.txt"; -- w
        rec_data_text : String := "receive_data_noc.txt"; -- w

        C_S_AXIS_TDATA_WIDTH : Integer := flit_size -- must same size as FLIT_SIZE
    );
    port (
        -- AXI Stream Slave interface
        S_AXIS_ACLK    : in Std_logic;
        S_AXIS_ARESETN : in Std_logic;
        S_AXIS_TREADY  : out Std_logic;                                              -- Ready to accept data in
        S_AXIS_TDATA   : in Std_logic_vector(C_S_AXIS_TDATA_WIDTH - 1 downto 0);     -- Data in
        S_AXIS_TSTRB   : in Std_logic_vector((C_S_AXIS_TDATA_WIDTH/8) - 1 downto 0); -- Byte qualifier
        S_AXIS_TLAST   : in Std_logic;                                               -- Indicates boundary of last packet
        S_AXIS_TVALID  : in Std_logic                                                -- Data is in valid

    );
end S_AXIS_TRAFFIC_REC;

architecture arch_imp of S_AXIS_TRAFFIC_REC is
    signal rand     : Integer;
    signal rec_incr : Std_logic;
begin

    S_AXIS_TREADY <= '1' when rec_incr = '1' and S_AXIS_TVALID = '1' else
        '0';

    -----------------------------
    ---- Signal pressure test----
    -----------------------------
    -- S_AXIS_TREADY <= '1' when rec_incr = '1' and S_AXIS_TVALID = '1' and rand = 0 else
    --     '0';
    -- process (S_AXIS_ACLK, S_AXIS_ARESETN)
    -- begin
    --     if S_AXIS_ARESETN = RST_LVL then
    --         rand <= 0;
    --     elsif rising_edge(S_AXIS_ACLK) then
    --         rand <= (rand + 1) mod 2;
    --     end if;
    -- end process;

    inst : entity work.traffic_rec
        generic map(
            flit_width    => C_S_AXIS_TDATA_WIDTH,
            rec_time_text => rec_time_text,
            rec_data_text => rec_data_text

        )
        port map(
            clk     => S_AXIS_ACLK,
            rst     => S_AXIS_ARESETN,
            valid   => S_AXIS_TVALID,
            incr    => rec_incr,
            data_in => S_AXIS_TDATA
        );
end arch_imp;