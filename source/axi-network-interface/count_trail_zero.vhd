-------------------------------------------------------------------------------
-- Title      : Count trailing zero of arbitrary bith width of given positive integer.
-- Project    :
-------------------------------------------------------------------------------
-- File       : count_lead_zero.vhd
-- Author     : Yee Yang Tan  <yee.yang.tan@ice.rwth-aachen.de>
-- Company    : RWTH Aachen University
-- Created    : 2021-10-10
-- Last update: 2021-10-10
-- Platform   :
-- Standard   : VHDL 2008
-------------------------------------------------------------------------------
-- Description: The published paper until now only reveals the method of
--              building count trailing zeros for the number of bit width of
--              power of 2.
--              Moreover, the CNT_WIDTH is the value of clog2(DATA_WIDTH).
--              When DATA_WIDTH = 1, CNT_WIDTH = 1 too.
-------------------------------------------------------------------------------
-- Copyright (c) 2021 Tan Yee Yang
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2021-10-10  1.0      Yang    Created
-------------------------------------------------------------------------------

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