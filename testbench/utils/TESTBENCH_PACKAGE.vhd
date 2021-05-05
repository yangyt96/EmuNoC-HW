
library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;
use ieee.numeric_std.all;

use work.NOC_3D_PACKAGE.all;

package TESTBENCH_PACKAGE is

    constant clk_period : Time := 1 ns;

    constant num_router : Positive := max_x_dim * max_y_dim * max_z_dim;
    constant num_io     : Positive := num_router * max_vc_num;

    type int_arr is array (natural range <>) of Integer;

    constant src_pos : int_arr := (0,0,0); -- z,x,y
    constant dst_pos : int_arr := (0,3,3); -- z,x,y

    constant src_router : Integer := src_pos(0)*max_x_dim*max_y_dim + src_pos(1)*max_x_dim + src_pos(2);
    constant dst_router : Integer := dst_pos(0)*max_x_dim*max_y_dim + dst_pos(1)*max_x_dim + dst_pos(2);

    constant src_vc : Integer := src_router * max_vc_num;
    constant dst_vc : Integer := dst_router * max_vc_num; -- always from vc port 0, its the local vc port


    end package TESTBENCH_PACKAGE;
package body TESTBENCH_PACKAGE is
end package body TESTBENCH_PACKAGE;