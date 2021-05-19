-------------------------------------------------------------------------------
-- Title      : Header arbiter and decoder
-- Project    : Modular, heterogenous 3D NoC
-------------------------------------------------------------------------------
-- File       : header_arbiter_and_decoder.vhd
-- Author     : Lennart Bamberg  <lennart@x230>
-- Company    : 
-- Created    : 2018-11-05
-- Last update: 2018-11-28
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Arbitrate next VC in the input to be assigned to an output VC.
--              For the granted input the routing is calculated, and the request
--              to the output is made. Also a counter with the packet length is
--              set. Via enable-read (enr_vc) the end of the packet is trackes,
--              which indicated that the next valid flit in the input vc will be
--              teh head-flit of a new package (new arbitration).
--              COMMENTS:
--              We have a 'strong' fifo fairness. Thus, if one packet
--              is blocked and it waits in the only virtual channel that wasn't
--              recently served, we wait for the blocking to be solved!
--              For a week fairness (with potentially a higher throughput) set
--              "ack" of the RR-arbiter to constant '1'.
-------------------------------------------------------------------------------
-- Copyright (c) 2018 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-11-05  1.0      lennart Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use work.NOC_3D_PACKAGE.all;
use work.TURNS_3D_NOC.all;

entity header_arbiter_and_decoder is
  generic (Xis                          : natural     := 1;
           Yis                          : natural     := 1;
           Zis                          : natural     := 1;
           port_num                     : integer     := 5;
           port_exist                   : integer_vec := (0, 1, 2, 3, 4, 5, 6);
           port_is                      : integer     := 1;  -- current port
           vc_num                       : positive    := 2;
           header_incl_in_packet_length : boolean     := true;
           rout_algo                    : string      := "XYZ");

  port (
    clk, rst        : in  std_logic;
    header          : in  header_inf_vector(vc_num-1 downto 0);
    valid_data_vc   : in  std_logic_vector(vc_num-1 downto 0);
    enr_vc          : in  std_logic_vector(vc_num-1 downto 0);  -- ONE-HOT
    ack_vc          : in  std_logic;    -- acknowledge of vc allocation
    granted_rq      : out std_logic_vector(port_num-1 downto 0);
    input_vc_in_use : out std_logic_vector(vc_num-1 downto 0);
    -- indicate if a vc is free again in the next cc
    packet_end      : out std_logic_vector(vc_num-1 downto 0);
    granted_vc      : out std_logic_vector(vc_num-1 downto 0)
    );

end header_arbiter_and_decoder;

architecture rtl of header_arbiter_and_decoder is

  constant poss_routes              : turn_table_3D := routes_3D(rout_algo);
  signal new_package_vc, grant      : std_logic_vector(vc_num-1 downto 0);
  signal flit_count_0, flit_count_1 : std_logic_vector(vc_num-1 downto 0);
  type flit_counter_vector is array(vc_num-1 downto 0) of
    unsigned(packet_len_width-1 downto 0);
  signal flit_count_values : flit_counter_vector;
  signal header_nxt        : header_inf;   -- current analyzed header
  signal address_nxt       : address_inf;  -- current analyzed header
  signal routing_en        : std_logic;
  signal granted_rq_cmplt  : std_logic_vector(6 downto 0);
  signal allocated         : std_logic_vector(vc_num-1 downto 0);
  signal packet_length_nxt : std_logic_vector(packet_len_width-1 downto 0);

begin
  -----------------------------------------------------------------------------
  -- Check if in any VC a new package has to be en encoded and also if in the
  -- next clock cycle any VV becomes free again--------------------------------
  -----------------------------------------------------------------------------
  GEN_COUNT_EQ_ZERO : for i in 0 to vc_num-1 generate
    flit_count_0(i) <= '1' when (flit_count_values(i) = to_unsigned(0, packet_len_width))
                       else '0';
    flit_count_1(i) <= '1' when (flit_count_values(i) = to_unsigned(1, packet_len_width))
                       else '0';  -- Only req 1 extra gate to flit_count_0
  end generate;
  input_vc_in_use <= not(flit_count_0);
  packet_end      <= flit_count_1 and enr_vc;
  new_package_vc  <= flit_count_0 and valid_data_vc;

  -----------------------------------------------------------------------------
  -- Round robin arbitration between all new packages -------------------------
  -----------------------------------------------------------------------------
  GEN_RR : if vc_num > 1 generate
    -- to add an extra pipeline stage for the rout_algo just intanciate
    -- "rr_arbiter" instead of "rr_arbiter_no_delay" ??
    rr_arbiter_no_delay_1 : entity work.rr_arbiter_no_delay
      generic map (
        CNT => vc_num)
      port map (
        clk   => clk,
        rst   => rst,
        req   => new_package_vc,
        ack   => ack_vc,
        grant => grant);
    header_nxt <= header(one_hot2int(grant));  -- next header to be decoded
  end generate;
  GEN_PASS_NO_VC : if vc_num = 1 generate
    grant      <= new_package_vc;
    header_nxt <= header(0);
  end generate;
  address_nxt       <= extract_address_inf(header_nxt);
  packet_length_nxt <= header_nxt.packet_length;
  routing_en        <= or_reduce(grant);
  granted_vc        <= grant;
  
  -----------------------------------------------------------------------------
  ---------------------------- Routing computation ----------------------------
  -----------------------------------------------------------------------------
  routing_calc_1 : entity work.routing_calc
    generic map (
      Xis       => Xis,
      Yis       => Yis,
      Zis       => Zis,
      rout_algo => rout_algo)
    port map (
      address => address_nxt,
      enable  => routing_en,
      routing => granted_rq_cmplt);
  --check which routes are actually possible. Set non-possible 0 
  process(granted_rq_cmplt)
  begin
    granted_rq <= (others => '0');
    for i in 0 to port_num-1 loop
      if poss_routes(port_is)(port_exist(i)) then
        granted_rq(i) <= granted_rq_cmplt(port_exist(i));
      end if;
    end loop;
  end process;
  allocated <= (others => '0') when ack_vc = '0' else grant;

  -----------------------------------------------------------------------------
  -- Generate the storage Elements, including the flit counter ----------------
  -----------------------------------------------------------------------------
  STOR_GEN : for i in 0 to vc_num-1 generate
    seq_packet_counter_i : entity work.seq_packet_counter
      generic map (
        header_incl_in_packet_length => header_incl_in_packet_length)
      port map (
        clk        => clk,
        rst        => rst,
        allocated  => allocated(i),
        packet_len => header_nxt.packet_length,
        enr_vc     => enr_vc(i),
        flit_count => flit_count_values(i));
  end generate;

end rtl;


