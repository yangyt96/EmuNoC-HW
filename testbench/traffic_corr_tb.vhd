-------------------------------------------------------------------------------
-- Title      : Test pattern receiver
-- Project    : NoC testbench generator
-------------------------------------------------------------------------------
-- File       : traffic_corr_tb.vhd
-- Author     : Seyed Nima Omidsajedi  <nima@omidsajedi.com>
-- Company    : University of Bremen
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Vesion     : 1.7.0
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;
use work.NOC_3D_PACKAGE.all;
use work.TESTBENCH_PACKAGE.all;

entity traffic_corr_tb is

end entity;

architecture behave of traffic_corr_tb is

	constant cnt_flit_width          : Positive := flit_size;
	constant cnt_router_credit       : Integer  := 4;
	constant cnt_srl_fifo_depth      : Integer  := 200;
	constant cnt_rec_time_text       : String   := "data/pic/out/receive_time_noc.txt";    -- w
	constant cnt_rec_data_text       : String   := "data/pic/out/receive_data_noc.txt";    -- w
	constant cnt_inj_time_text       : String   := "data/pic/in/injection_time.txt";       -- r
	constant cnt_packet_length_text  : String   := "data/pic/in/packet_header_length.txt"; -- r
	constant cnt_image_2_flits_text  : String   := "data/pic/in/data_header.txt";          -- r
	constant cnt_inj_time_2_noc_text : String   := "data/pic/out/inj_time_2_noc.txt";      -- w

	-------------------------------------------------------------------

	signal clk               : Std_logic                             := '0';
	signal rst               : Std_logic                             := RST_LVL;
	signal local_rx          : flit_vector(num_router - 1 downto 0)  := (others => (others => '0'));
	signal local_vc_write_rx : Std_logic_vector(num_io - 1 downto 0) := (others => '0');
	signal local_incr_rx_vec : Std_logic_vector(num_io - 1 downto 0) := (others => '0');
	signal local_tx          : flit_vector(num_router - 1 downto 0);
	signal local_vc_write_tx : Std_logic_vector(num_io - 1 downto 0);
	signal local_incr_tx_vec : Std_logic_vector(num_io - 1 downto 0);

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
			clk, rst : in Std_logic;
			valid    : in Std_logic;
			incr     : out Std_logic;
			data_in  : in flit := (others => '0')
		);
	end component traffic_rec;

	-- NoC
	component full_noc is
		port (
			clk, rst          : in Std_logic;
			local_rx          : in flit_vector(num_router - 1 downto 0);
			local_vc_write_rx : in Std_logic_vector(num_io - 1 downto 0);
			local_incr_rx_vec : in Std_logic_vector(num_io - 1 downto 0);
			local_tx          : out flit_vector(num_router - 1 downto 0);
			local_vc_write_tx : out Std_logic_vector(num_io - 1 downto 0);
			local_incr_tx_vec : out Std_logic_vector(num_io - 1 downto 0)
		);
	end component full_noc;

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

	traffic_gen_comp_1 : entity work.traffic_gen
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
			valid    => local_vc_write_rx(src_vc),
			incr     => local_incr_tx_vec(src_vc),
			data_out => local_rx(src_router)
		);

	full_noc_comp : entity work.full_noc
		port map(
			clk               => clk,
			rst               => rst,
			local_rx          => local_rx,
			local_vc_write_rx => local_vc_write_rx,
			local_incr_rx_vec => local_incr_rx_vec,
			local_tx          => local_tx,
			local_vc_write_tx => local_vc_write_tx,
			local_incr_tx_vec => local_incr_tx_vec
		);

	traffic_rec_comp_1 : entity work.traffic_rec
		generic map(
			flit_width    => cnt_flit_width,
			rec_time_text => cnt_rec_time_text,
			rec_data_text => cnt_rec_data_text
		)
		port map(
			clk     => clk,
			rst     => rst,
			valid   => local_vc_write_tx(dst_vc),
			incr    => local_incr_rx_vec(dst_vc),
			data_in => local_tx(dst_router)
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