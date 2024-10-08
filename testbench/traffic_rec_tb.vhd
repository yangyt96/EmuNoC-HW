-------------------------------------------------------------------------------
-- Title      : Test pattern receiver
-- Project    : NoC testbench generator
-------------------------------------------------------------------------------
-- File       : traffic_rec_tb.vhd
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

entity traffic_rec_tb is

end entity;

architecture behave of traffic_rec_tb is

	constant cnt_flit_width          : Positive := flit_size;
	constant cnt_router_credit       : Integer  := 4;
	constant cnt_srl_fifo_depth      : Integer  := 256;
	constant cnt_rec_time_text       : String   := "testdata/gen_rec/out/receive_time_noc.txt";
	constant cnt_rec_data_text       : String   := "testdata/gen_rec/out/receive_data_noc.txt";
	constant cnt_inj_time_text       : String   := "testdata/gen_rec/in/injection_time.txt";
	constant cnt_packet_length_text  : String   := "testdata/gen_rec/in/packet_length.txt";
	constant cnt_image_2_flits_text  : String   := "testdata/gen_rec/in/data_header.txt";
	constant cnt_inj_time_2_noc_text : String   := "testdata/gen_rec/out/inj_time_2_noc.txt";

	signal counter             : Natural   := 0;
	signal clk, rst            : Std_logic := '0';
	signal valid_int, incr_int : Std_logic := '0';
	signal data_int            : flit      := (others => '0');

	-------------------------------------------------------------------
	--------------------- Component declaration -----------------------

	-- Traffic Receiver
	component traffic_rec is
		generic (
			flit_width    : Positive := cnt_flit_width;
			rec_time_text : String   := cnt_rec_time_text;
			rec_data_text : String   := cnt_rec_data_text
		);
		port (
			clk, rst : in Std_logic  := '0';
			valid    : in Std_logic  := '0';
			incr     : out Std_logic := '0';
			data_in  : in flit       := (others => '0')
		);
	end component traffic_rec;

	-- Traffic Generator
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

	traffic_gen_comp : entity work.traffic_gen
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
			valid    => valid_int,
			incr     => incr_int,
			data_out => data_int
		);

	DUT : entity work.traffic_rec
		generic map(
			flit_width    => cnt_flit_width,
			rec_time_text => cnt_rec_time_text,
			rec_data_text => cnt_rec_data_text
		)
		port map(
			clk     => clk,
			rst     => rst,
			valid   => valid_int,
			incr    => incr_int,
			data_in => data_int
		);
	-------------------------------------------------------------------
	----------------------RST & CLK generation-------------------------

	rst_gen : process
	begin
		rst <= RST_LVL;
		wait for (clk_period * 2);
		rst <= not(RST_LVL);
		wait;
	end process;

	clk_gen : process
	begin
		clk <= '1';
		wait for (clk_period / 2);
		clk <= '0';
		wait for (clk_period / 2);
	end process;

	--------------------------------------------------------------------
	-------------------------------------------------------------------

end architecture;