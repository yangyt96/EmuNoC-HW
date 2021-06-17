-------------------------------------------------------------------------------
-- Title      : Test pattern generator
-- Project    : NoC testbench generator
-------------------------------------------------------------------------------
-- File       : traffic_gen_tb.vhd
-- Author     : Seyed Nima Omidsajedi  <nima@omidsajedi.com>
-- Company    : University of Bremen
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Vesion     : 1.9.0
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;
use work.NOC_3D_PACKAGE.all;
use work.TESTBENCH_PACKAGE.all;

entity traffic_gen_tb is

end entity;

architecture behave of traffic_gen_tb is

	constant cnt_flit_width          : Positive                                      := flit_size;
	constant cnt_router_credit       : Integer                                       := 2;
	constant cnt_srl_fifo_depth      : Integer                                       := 32;
	constant cnt_inj_time_text       : String                                        := "testdata/gen_rec/in/injection_time.txt";
	constant cnt_packet_length_text  : String                                        := "testdata/gen_rec/in/packet_length.txt";
	constant cnt_image_2_flits_text  : String                                        := "testdata/gen_rec/in/data_header.txt";
	constant cnt_inj_time_2_noc_text : String                                        := "testdata/gen_rec/out/inj_time_2_noc.txt";
	signal clk, rst, valid, incr     : Std_logic                                     := '0';
	signal data_out                  : Std_logic_vector(cnt_flit_width - 1 downto 0) := (others => '0');
	signal counter                   : Natural                                       := 0;

	file inj_time       : text open read_mode is cnt_inj_time_text;
	file packet_length  : text open read_mode is cnt_packet_length_text;
	file image_2_flits  : text open read_mode is cnt_image_2_flits_text;
	file inj_time_2_noc : text open write_mode is cnt_inj_time_2_noc_text;

	component traffic_gen is
		generic (
			flit_width          : Positive := cnt_flit_width;
			router_credit       : Integer  := cnt_router_credit;
			srl_fifo_depth      : Integer  := cnt_srl_fifo_depth;
			inj_time_text       : String   := cnt_inj_time_text;
			packet_length_text  : String   := cnt_packet_length_text;
			image_2_flits_text  : String   := cnt_image_2_flits_text;
			inj_time_2_noc_text : String   := cnt_inj_time_2_noc_text
		);
		port (
			clk, rst : in Std_logic;
			valid    : out Std_logic;
			incr     : in Std_logic;
			data_out : out flit
		);
	end component traffic_gen;

begin

	-------------------------------------------------------------------
	------------------- Component instantiations ----------------------

	DUT : entity work.traffic_gen
		generic map(
			flit_width          => cnt_flit_width,
			router_credit       => cnt_router_credit,
			srl_fifo_depth      => cnt_srl_fifo_depth,
			inj_time_text       => cnt_inj_time_text,
			packet_length_text  => cnt_packet_length_text,
			image_2_flits_text  => cnt_image_2_flits_text,
			inj_time_2_noc_text => cnt_inj_time_2_noc_text
		)
		port map(
			clk      => clk,
			rst      => rst,
			valid    => valid,
			incr     => incr,
			data_out => data_out
		);

	-------------------------------------------------------------------
	------------------ RST & CLK & INCR generation --------------------

	clk_gen : process
	begin
		clk <= '1';
		wait for (clk_period / 2);
		clk <= '0';
		wait for (clk_period / 2);

	end process;

	rst_gen : process
	begin
		rst <= RST_LVL;
		wait for (clk_period * 2);
		rst <= not(RST_LVL);
		wait;
	end process;

	T1 : process
	begin
		incr <= '0';
		wait for (clk_period * 50);
		incr <= '1';
		wait for (clk_period * 1);
	end process;

end architecture;