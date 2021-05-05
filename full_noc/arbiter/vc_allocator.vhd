-------------------------------------------------------------------------------
-- Title      : Virtual channel allocator
-- Project    : Modular, heterogenous 3D NoC
-------------------------------------------------------------------------------
-- File       : vc_allocator.vhd
-- Author     : Lennart Bamberg  <lennart@t440s>
-- Company    : 
-- Created    : 2018-11-11
-- Last update: 2018-11-28
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: New package are detected in an input port, then the required
--              informations (routing & packet length) are decoded from the  
--              header. Finally, a suitable output virtual channel is assigned.
--              COMMENT:
--              Currently, this version is not used (but the high perf. one)!
-------------------------------------------------------------------------------
-- Copyright (c) 2018 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-11-11  1.0      lennart Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use work.NOC_3D_PACKAGE.all;
use work.TURNS_3D_NOC.all;

entity vc_allocator is
  generic (
    port_num                     : positive    := 5;
    -- Integer range has to be / is (0 to port_num-1)
    port_exist                   : integer_vec := (0, 1, 2, 3, 4, 5, 6);
    Xis                          : natural     := 1;
    Yis                          : natural     := 1;
    Zis                          : natural     := 1;
    header_incl_in_packet_length : boolean     := true;
    rout_algo                    : string      := "XYZ";
    vc_num_vec                   : integer_vec := (2 ,2 ,2 ,2 ,2 );
    vc_num_out_vec               : integer_vec := (2 ,2 ,2 ,2 ,2 ));
  port (
    clk, rst          : in  std_logic;
    header            : in  header_inf_vector(int_vec_sum(vc_num_vec)-1 downto 0);
    enr_vc            : in  std_logic_vector(int_vec_sum(vc_num_vec)-1 downto 0);
    valid_data_vc_vec : in  std_logic_vector(int_vec_sum(vc_num_vec)-1 downto 0);
    input_vc_in_use   : out std_logic_vector(int_vec_sum(vc_num_vec)-1 downto 0);
    crossbar_ctrl_vec : out std_logic_vector(int_vec_sum(vc_num_out_vec)*
                                             bit_width(port_num-1)-1 downto 0);
    vc_sel_enc_vec    : out vc_status_array_enc(int_vec_sum(vc_num_out_vec)-1 downto 0);
    output_vc_in_use  : out std_logic_vector(int_vec_sum(vc_num_out_vec)-1 downto 0)
    );
end entity vc_allocator;

architecture rtl of vc_allocator is
  constant poss_routes    : turn_table_3D := routes_3D(rout_algo);
  constant sel_width      : positive      := bit_width(port_num-1);
  signal ack_input        : std_logic_vector(port_num-1 downto 0);
  signal packet_end       : std_logic_vector(int_vec_sum(vc_num_vec)-1 downto 0);
  type rq_array is array (port_num-1 downto 0) of std_logic_vector(port_num-1 downto 0);
  type rq_array_filt is array (port_num-1 downto 0) of std_logic_vector(port_num-2 downto 0);
  signal granted_rq_array : rq_array;
  signal rq_vc_out_array  : rq_array_filt;
  type vc_status_array_filt is array (port_num-1 downto 0) of vc_status_array(port_num-2 downto 0);
  signal packet_end_sort  : vc_status_array_filt;
  signal granted_vc_sort  : vc_status_array_filt;
  signal granted_vc       : std_logic_vector(int_vec_sum(vc_num_vec)-1 downto 0);
  type ack_array_vc_out is array(port_num-1 downto 0) of std_logic_vector(port_num-2 downto 0);
  signal ack_rq_vc_out    : ack_array_vc_out;

begin  -- architecture rtl
  GEN_PER_PORT : for i in 0 to port_num-1 generate
    constant ur_vc_in  : natural := upper_range(vc_num_vec, i);
    constant lr_vc_in  : natural := lower_range(vc_num_vec, i);
    constant ur_vc_out : natural := upper_range(vc_num_out_vec, i);
    constant lr_vc_out : natural := lower_range(vc_num_out_vec, i);
  begin
    ---------------------------------------------------------------------------
    -- Header decoder and input arbiter per port-------------------------------
    ---------------------------------------------------------------------------
    input_first_arbiter_i : entity work.header_arbiter_and_decoder
      generic map (
        Xis                          => Xis,
        Yis                          => Yis,
        Zis                          => Zis,
        port_num                     => port_num,
        port_exist                   => port_exist,
        port_is                      => port_exist(i),
        vc_num                       => vc_num_vec(i),
        header_incl_in_packet_length => header_incl_in_packet_length,
        rout_algo                    => rout_algo)
      port map (
        clk             => clk,
        rst             => rst,
        valid_data_vc   => valid_data_vc_vec(ur_vc_in downto lr_vc_in),
        header          => header(ur_vc_in downto lr_vc_in),
        enr_vc          => enr_vc(ur_vc_in downto lr_vc_in),
        ack_vc          => ack_input(i),
        granted_rq      => granted_rq_array(i),
        input_vc_in_use => input_vc_in_use(ur_vc_in downto lr_vc_in),
        packet_end      => packet_end(ur_vc_in downto lr_vc_in),
        granted_vc      => granted_vc(ur_vc_in downto lr_vc_in));

    ---------------------------------------------------------------------------
    -- Output VC arbiter/allocator per port -----------------------------------
    ---------------------------------------------------------------------------
    output_last_arbiter_i : entity work.vc_output_allocator
      generic map (
        port_num   => port_num,
        vc_num_out => vc_num_out_vec(i))
      port map (
        clk               => clk,
        rst               => rst,
        rq_vc_out         => rq_vc_out_array(i),
        granted_vc        => granted_vc_sort(i),
        packet_end        => packet_end_sort(i),
        crossbar_ctrl_vec => crossbar_ctrl_vec((ur_vc_out+1)*sel_width-1 downto lr_vc_out*sel_width),
        vc_sel_enc        => vc_sel_enc_vec(ur_vc_out downto lr_vc_out),
        output_vc_in_use  => output_vc_in_use(ur_vc_out downto lr_vc_out),
        ack_rq_vc_out     => ack_rq_vc_out(i)
        );

  end generate;

  -----------------------------------------------------------------------------
  -- Clock Wise Wiring --------------------------------------------------------
  -----------------------------------------------------------------------------
  WIRING_INAR_TO_OUTAR : process(ack_rq_vc_out, granted_rq_array, granted_vc,
                                 packet_end)
    variable var_in            : natural;
    variable ack_rq_vc_out_var : std_logic_vector(port_num-1 downto 0);
  begin
    rq_vc_out_array   <= (others => (others => '0'));
    granted_vc_sort   <= (others => (others => (others => '0')));
    packet_end_sort   <= (others => (others => (others => '0')));
    ack_rq_vc_out_var := (others => '0');
    for y in 0 to port_num-1 loop       -- For the VC-out allocator y,
      for x in 0 to port_num-2 loop     -- the X^th input is
        if y+x < port_num-1 then
          var_in := y+x+1;
        else                            -- Modulo (start from beginning)
          var_in := y+x-port_num+1;
        end if;
        if poss_routes(port_exist(var_in))(port_exist(y)) then
          rq_vc_out_array(y)(x) <= granted_rq_array(var_in)(y);
          granted_vc_sort(y)(x)(vc_num_vec(var_in)-1 downto 0)
            <= slice(granted_vc, vc_num_vec, var_in);
          packet_end_sort(y)(x)(vc_num_vec(var_in)-1 downto 0)
            <= slice(packet_end, vc_num_vec, var_in);
          ack_rq_vc_out_var(var_in) := ack_rq_vc_out_var(var_in) or
                                       ack_rq_vc_out(y)(x);  --feedback ack

        end if;
      end loop;
    end loop;
    ack_input <= ack_rq_vc_out_var;
  end process;

end architecture rtl;
