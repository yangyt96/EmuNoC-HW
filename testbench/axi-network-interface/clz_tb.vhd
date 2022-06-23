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
use ieee.numeric_std.all;

entity clz_tb is
end entity;

architecture behave of clz_tb is
    constant clk_period : Time := 1 ns;

    constant DATA_WIDTH : Natural := 6;
    constant CNT_WIDTH  : Natural := Natural(ceil(log2(real(DATA_WIDTH))));

    signal clk       : Std_logic := '1';
    signal clk_count : Integer   := 0;

    signal valid    : Std_logic;
    signal count    : Std_logic_vector(CNT_WIDTH - 1 downto 0);
    signal data     : Std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
    signal rev_data : Std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
begin
    process (clk)
    begin
        if rising_edge(clk) then
            data <= Std_logic_vector(to_unsigned(clk_count, data'length));
        end if;
    end process;

    gen_reverse : for i in 0 to DATA_WIDTH - 1 generate
        rev_data(DATA_WIDTH - 1 - i) <= data(i);
    end generate gen_reverse;

    DUT : entity work.count_lead_zero
        generic map(
            DATA_WIDTH => DATA_WIDTH,
            CNT_WIDTH  => CNT_WIDTH
        )
        port map(
            i_data => rev_data,
            -- i_data  => data,
            o_valid => valid,
            o_count => count
        );

    -- system
    clk       <= not(clk) after clk_period/2;
    clk_count <= clk_count + 1 after clk_period;
end architecture;