
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;
use work.NOC_3D_PACKAGE.all;
use work.TESTBENCH_PACKAGE.all;

entity axis_traffic_gen_tb is

end entity;

architecture behave of axis_traffic_gen_tb is

	constant cnt_flit_width          : Positive := flit_size;
	constant cnt_router_credit       : Integer  := 1;
	constant cnt_srl_fifo_depth      : Integer  := 5;
	constant cnt_inj_time_text       : String   := "testdata/gen_rec/in/injection_time.txt";
	constant cnt_packet_length_text  : String   := "testdata/gen_rec/in/packet_length.txt";
	constant cnt_image_2_flits_text  : String   := "testdata/gen_rec/in/data_header.txt";
	constant cnt_inj_time_2_noc_text : String   := "testdata/gen_rec/out/inj_time_2_noc.txt";

	constant C_M_AXIS_TDATA_WIDTH : Integer := 32;

	signal counter : Natural := 0;

	file inj_time       : text open read_mode is cnt_inj_time_text;
	file packet_length  : text open read_mode is cnt_packet_length_text;
	file image_2_flits  : text open read_mode is cnt_image_2_flits_text;
	file inj_time_2_noc : text open write_mode is cnt_inj_time_2_noc_text;

	signal clk  : Std_logic := '0';
	signal rst  : Std_logic := '1';
	signal incr : Std_logic := '0';

	signal gen_axis_aclk    : Std_logic;
	signal gen_axis_aresetn : Std_logic;
	signal gen_axis_tvalid  : Std_logic;
	signal gen_axis_tdata   : Std_logic_vector(C_M_AXIS_TDATA_WIDTH - 1 downto 0);
	signal gen_axis_tstrb   : Std_logic_vector((C_M_AXIS_TDATA_WIDTH/8) - 1 downto 0);
	signal gen_axis_tlast   : Std_logic;
	signal gen_axis_tready  : Std_logic;

begin
	gen_axis_aclk    <= clk;
	gen_axis_aresetn <= rst;
	gen_axis_tready  <= incr;
	-------------------------------------------------------------------
	------------------- Component instantiations ----------------------

	DUT : entity work.m_axis_traffic_gen
		generic map(
			flit_width          => cnt_flit_width,
			srl_fifo_depth      => cnt_srl_fifo_depth,
			inj_time_text       => cnt_inj_time_text,
			packet_length_text  => cnt_packet_length_text,
			image_2_flits_text  => cnt_image_2_flits_text,
			inj_time_2_noc_text => cnt_inj_time_2_noc_text
		)
		port map(
			M_AXIS_ACLK    => gen_axis_aclk,
			M_AXIS_ARESETN => gen_axis_aresetn,
			M_AXIS_TVALID  => gen_axis_tvalid,
			M_AXIS_TDATA   => gen_axis_tdata,
			M_AXIS_TSTRB   => gen_axis_tstrb,
			M_AXIS_TLAST   => gen_axis_tlast,
			M_AXIS_TREADY  => gen_axis_tready
		);

	-------------------------------------------------------------------
	------------------ RST & CLK & INCR generation --------------------

	clk <= not(clk) after clk_period/2;

	rst_gen : process
	begin
		rst <= RST_LVL;
		wait for (clk_period * 2);
		rst <= not(RST_LVL);
		wait;
	end process;

	incr <= gen_axis_tvalid;
	-- T1 : process
	-- begin
	-- 	incr <= '0';
	-- 	wait for (clk_period * 30);
	-- 	incr <= '1';
	-- 	wait for (clk_period * 1);
	-- end process;

end architecture;