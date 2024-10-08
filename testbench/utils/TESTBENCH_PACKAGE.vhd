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

use work.NOC_3D_PACKAGE.all;

package TESTBENCH_PACKAGE is

    constant clk_period : Time := 1 ns;

    constant num_router : Positive := max_x_dim * max_y_dim * max_z_dim;
    constant num_io     : Positive := num_router * max_vc_num;

    type int_arr is array (Natural range <>) of Integer;

    constant src_pos : int_arr := (0, 0, 0); -- z,y,x
    constant dst_pos : int_arr := (0, 0, 1); -- z,y,x

    constant src_router : Integer := src_pos(0) * max_x_dim * max_y_dim + src_pos(1) * max_x_dim + src_pos(2);
    constant dst_router : Integer := dst_pos(0) * max_x_dim * max_y_dim + dst_pos(1) * max_x_dim + dst_pos(2);

    constant src_vc : Integer := src_router * max_vc_num;
    constant dst_vc : Integer := dst_router * max_vc_num; -- always from vc port 0, its the local vc port
end package TESTBENCH_PACKAGE;
package body TESTBENCH_PACKAGE is
end package body TESTBENCH_PACKAGE;