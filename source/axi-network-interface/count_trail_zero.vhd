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
use ieee.math_real.all;

entity count_trail_zero is
    generic (
        DATA_WIDTH : Natural := 4; -- Must larger equal to 4
        CNT_WIDTH  : Natural := 2  -- bit width of DATA_WIDTH
    );
    port (
        i_data  : in Std_logic_vector(DATA_WIDTH - 1 downto 0);
        o_count : out Std_logic_vector(CNT_WIDTH - 1 downto 0);
        o_valid : out Std_logic
    );
end count_trail_zero;

architecture implementation of count_trail_zero is
    signal inv_endian : Std_logic_vector(DATA_WIDTH - 1 downto 0);
begin

    gen_swap_endian : for i in 0 to DATA_WIDTH - 1 generate
        inv_endian(i) <= i_data(DATA_WIDTH - 1 - i);
    end generate;

    inst_clz : entity work.count_lead_zero
        generic map(
            DATA_WIDTH => DATA_WIDTH,
            CNT_WIDTH  => CNT_WIDTH
        )
        port map(
            i_data  => inv_endian,
            o_valid => o_valid,
            o_count => o_count
        );

end architecture;