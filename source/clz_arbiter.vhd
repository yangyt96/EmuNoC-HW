library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.NOC_3D_PACKAGE.all;

entity clz_arbiter is
    generic (
        CNT : Integer := 5
    );
    port (
        clk : in Std_logic;
        rst : in Std_logic;

        req : in Std_logic_vector(CNT - 1 downto 0);
        ack : in Std_logic;

        grant : out Std_logic_vector(CNT - 1 downto 0)
    );
end;

architecture clz_arbiter of clz_arbiter is

    signal addr  : Integer range 0 to CNT - 1;
    signal shift : Std_logic_vector(CNT - 1 downto 0);

    signal clz_data  : Std_logic_vector(CNT - 1 downto 0); -- this need to be reversed assigned
    signal clz_valid : Std_logic;
    signal clz_count : Std_logic_vector(bit_width(CNT) - 1 downto 0);

    signal win : Std_logic_vector(CNT - 1 downto 0);

begin
    -- I/O
    grant <= shift when or_reduce(req) = '1' else
        (others => '0');

    -- Internal signals
    gen_swap_endian : for i in 0 to CNT - 1 generate
        clz_data(i) <= req(CNT - 1 - i);
    end generate;
    addr  <= to_integer(unsigned(clz_count)) mod CNT;
    shift <= Std_logic_vector(shift_left(to_unsigned(1, CNT), addr));

    -- Instance
    inst_clz : entity work.count_lead_zero
        generic map(
            DATA_WIDTH => CNT,
            CNT_WIDTH  => bit_width(CNT)
        )
        port map(
            i_data  => clz_data,
            o_valid => clz_valid,
            o_count => clz_count
        );

end clz_arbiter;