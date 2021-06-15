-------------------------------------------------------------------------------
-- Title      : Count leading zero of arbitrary bith width of given positive integer.
-- Project    :
-------------------------------------------------------------------------------
-- File       : count_lead_zero.vhd
-- Author     : Yee Yang Tan  <yee.yang.tan@ice.rwth-aachen.de>
-- Company    : RWTH Aachen University
-- Created    : 2021-06-01
-- Last update: 2021-06-01
-- Platform   :
-- Standard   : VHDL 2008
-------------------------------------------------------------------------------
-- Description: The published paper until now only reveals the method of
--              building count leading zeros for the number of bit width of
--              power of 2. Here, it is provided the method to generate the
--              circuit recursively.
--              Moreover, the CNT_WIDTH is the value of clog2(DATA_WIDTH).
--              When DATA_WIDTH = 1, CNT_WIDTH = 1 too.
-------------------------------------------------------------------------------
-- Copyright (c) 2021 Tan Yee Yang
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2021-06-01  1.0      Yang    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

entity count_lead_zero is
    generic (
        DATA_WIDTH : Natural := 4; -- Must larger equal to 4
        CNT_WIDTH  : Natural := 2  -- bit width of DATA_WIDTH
    );
    port (
        i_data  : in Std_logic_vector(DATA_WIDTH - 1 downto 0);
        o_count : out Std_logic_vector(CNT_WIDTH - 1 downto 0);
        o_valid : out Std_logic
    );
end count_lead_zero;

architecture implementation of count_lead_zero is
    function highest_pow2(x : Natural) return Natural is
        variable tmp            : Natural := 2;
    begin
        while x >= tmp loop
            tmp := tmp * 2;
        end loop;
        tmp := tmp / 2;
        return tmp;
    end function;

    function bit_width(x : Natural) return Natural is
    begin
        if x > 1 then
            return Natural(ceil(log2(real(x))));
        elsif x = 1 then
            return 1;
        else
            return 0;
        end if;
    end function;

    constant MSB_WIDTH : Natural := highest_pow2(DATA_WIDTH);
    constant LSB_WIDTH : Natural := DATA_WIDTH - highest_pow2(DATA_WIDTH);

begin

    gen_data_width_1 : if DATA_WIDTH = 1 generate
        o_valid    <= '1';
        o_count(0) <= not(i_data(0));
    end generate gen_data_width_1;

    gen_data_width_2 : if DATA_WIDTH = 2 generate
        o_valid    <= i_data(1) or i_data(0);
        o_count(0) <= not(i_data(1));
    end generate gen_data_width_2;

    gen_data_width_lt_2 : if DATA_WIDTH > 2 generate
        signal valid_msb : Std_logic;
        signal valid_lsb : Std_logic;
        signal count_msb : Std_logic_vector(CNT_WIDTH - 2 downto 0);
        signal count_lsb : Std_logic_vector(CNT_WIDTH - 2 downto 0);
    begin

        gen_recursive_pow2 : if LSB_WIDTH = 0 generate
            inst_msb : entity work.count_lead_zero
                generic map(
                    DATA_WIDTH => DATA_WIDTH / 2,
                    CNT_WIDTH  => bit_width(DATA_WIDTH/2)
                )
                port map(
                    i_data  => i_data(DATA_WIDTH - 1 downto DATA_WIDTH / 2),
                    o_valid => valid_msb,
                    o_count => count_msb
                );

            inst_lsb : entity work.count_lead_zero
                generic map(
                    DATA_WIDTH => DATA_WIDTH / 2,
                    CNT_WIDTH  => bit_width(DATA_WIDTH/2)
                )
                port map(
                    i_data  => i_data(DATA_WIDTH/2 - 1 downto 0),
                    o_valid => valid_lsb,
                    o_count => count_lsb
                );
        end generate gen_recursive_pow2;

        gen_contain_pow2 : if LSB_WIDTH > 0 generate
            inst_msb : entity work.count_lead_zero
                generic map(
                    DATA_WIDTH => MSB_WIDTH,
                    CNT_WIDTH  => bit_width(MSB_WIDTH)
                )
                port map(
                    i_data  => i_data(DATA_WIDTH - 1 downto LSB_WIDTH),
                    o_valid => valid_msb,
                    o_count => count_msb
                );

            inst_lsb : entity work.count_lead_zero
                generic map(
                    DATA_WIDTH => LSB_WIDTH,
                    CNT_WIDTH  => bit_width(LSB_WIDTH)
                )
                port map(
                    i_data  => i_data(LSB_WIDTH - 1 downto 0),
                    o_valid => valid_lsb,
                    o_count => count_lsb(bit_width(LSB_WIDTH) - 1 downto 0)
                );

            gen_remain_count_lsb_zeros : if (CNT_WIDTH - 2) >= bit_width(LSB_WIDTH) generate
                count_lsb(CNT_WIDTH - 2 downto bit_width(LSB_WIDTH)) <= (others => '0');
            end generate gen_remain_count_lsb_zeros;

        end generate gen_contain_pow2;

        o_valid                         <= valid_msb or valid_lsb;
        o_count(CNT_WIDTH - 2 downto 0) <= count_msb when valid_msb = '1' else
        count_lsb;
        o_count(CNT_WIDTH - 1) <= not(valid_msb);

    end generate gen_data_width_lt_2;

end architecture;