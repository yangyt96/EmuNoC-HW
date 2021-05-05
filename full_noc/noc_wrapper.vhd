library ieee;
use ieee.std_logic_1164.all;

use work.NOC_3D_PACKAGE.vhd

entity noc_wrapper is

    
    port (
        clk, rst          : in Std_logic;
        local_rx          : in flit_vector(4 - 1 downto 0);
        local_vc_write_rx : in Std_logic_vector(8 - 1 downto 0);
        local_incr_rx_vec : in Std_logic_vector(8 - 1 downto 0);
        local_tx          : out flit_vector(4 - 1 downto 0);
        local_vc_write_tx : out Std_logic_vector(8 - 1 downto 0);
        local_incr_tx_vec : out Std_logic_vector(8 - 1 downto 0)
    );
end entity noc_wrapper;