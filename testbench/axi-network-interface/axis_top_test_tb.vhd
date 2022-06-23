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
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

use std.textio.all;
use work.NOC_3D_PACKAGE.all;
use work.TESTBENCH_PACKAGE.all;

entity axis_top_test_tb is

end entity;

architecture behave of axis_top_test_tb is

	constant cnt_flit_width          : Positive := flit_size;
	constant cnt_router_credit       : Integer  := 2;
	constant cnt_srl_fifo_depth      : Integer  := 16;
	constant cnt_rec_time_text       : String   := "testdata/pic/out/receive_time_noc.txt";    -- w
	constant cnt_rec_data_text       : String   := "testdata/pic/out/receive_data_noc.txt";    -- w
	constant cnt_inj_time_text       : String   := "testdata/pic/in/injection_time.txt";       -- r
	constant cnt_packet_length_text  : String   := "testdata/pic/in/packet_header_length.txt"; -- r
	constant cnt_image_2_flits_text  : String   := "testdata/pic/in/data_header.txt";          -- r
	constant cnt_inj_time_2_noc_text : String   := "testdata/pic/out/inj_time_2_noc.txt";      -- w

	-------------------------------------------------------------------

	signal clk               : Std_logic                             := '0';
	signal rst               : Std_logic                             := RST_LVL;
	signal local_rx          : flit_vector(num_router - 1 downto 0)  := (others => (others => '0'));
	signal local_vc_write_rx : Std_logic_vector(num_io - 1 downto 0) := (others => '0');
	signal local_incr_rx_vec : Std_logic_vector(num_io - 1 downto 0) := (others => '0');
	signal local_tx          : flit_vector(num_router - 1 downto 0);
	signal local_vc_write_tx : Std_logic_vector(num_io - 1 downto 0);
	signal local_incr_tx_vec : Std_logic_vector(num_io - 1 downto 0);

	signal rec_axis_tvalid : Std_logic;
	signal rec_axis_tdata  : Std_logic_vector(cnt_flit_width - 1 downto 0);
	signal rec_axis_tstrb  : Std_logic_vector((cnt_flit_width/8) - 1 downto 0);
	signal rec_axis_tlast  : Std_logic;
	signal rec_axis_tready : Std_logic;

	signal gen_axis_tvalid : Std_logic;
	signal gen_axis_tdata  : Std_logic_vector(cnt_flit_width - 1 downto 0);
	signal gen_axis_tstrb  : Std_logic_vector((cnt_flit_width/8) - 1 downto 0);
	signal gen_axis_tlast  : Std_logic;
	signal gen_axis_tready : Std_logic := '0';
	signal gen_axis_taddr  : Std_logic_vector(4 - 1 downto 0);

begin

	-------------------------------------------------------------------
	------------------- Component instantiations ----------------------

	-- gen Master
	inst_m_axis_traffic_gen : entity work.M_AXIS_TRAFFIC_GEN
		generic map(
			flit_width          => cnt_flit_width,
			srl_fifo_depth      => cnt_srl_fifo_depth,
			inj_time_text       => cnt_inj_time_text,
			packet_length_text  => cnt_packet_length_text,
			image_2_flits_text  => cnt_image_2_flits_text,
			inj_time_2_noc_text => cnt_inj_time_2_noc_text
		)
		port map(
			M_AXIS_TADDR => gen_axis_taddr,

			M_AXIS_ACLK    => clk,
			M_AXIS_ARESETN => rst,
			M_AXIS_TVALID  => gen_axis_tvalid,
			M_AXIS_TDATA   => gen_axis_tdata,
			M_AXIS_TSTRB   => gen_axis_tstrb,
			M_AXIS_TLAST   => gen_axis_tlast,
			M_AXIS_TREADY  => gen_axis_tready
		);

	-- DUT
	inst_DUT : entity work.axis_top_test
		port map(
			clk => clk,
			rst => rst,

			s_axis_tready => gen_axis_tready,
			s_axis_tdata  => gen_axis_tdata,
			s_axis_tstrb  => gen_axis_tstrb,
			s_axis_tlast  => gen_axis_tlast,
			s_axis_tvalid => gen_axis_tvalid,

			m_axis_tvalid => rec_axis_tvalid,
			m_axis_tdata  => rec_axis_tdata,
			m_axis_tstrb  => rec_axis_tstrb,
			m_axis_tlast  => rec_axis_tlast,
			m_axis_tready => rec_axis_tready
		);

	-- rec Slave
	inst_s_axi_traffic_rec : entity work.S_AXIS_TRAFFIC_REC
		generic map(
			C_S_AXIS_TDATA_WIDTH => cnt_flit_width,
			rec_time_text        => cnt_rec_time_text,
			rec_data_text        => cnt_rec_data_text
		)
		port map(
			S_AXIS_ACLK    => clk,
			S_AXIS_ARESETN => rst,

			S_AXIS_TVALID => rec_axis_tvalid,
			S_AXIS_TDATA  => rec_axis_tdata,
			S_AXIS_TSTRB  => rec_axis_tstrb,
			S_AXIS_TLAST  => rec_axis_tlast,
			S_AXIS_TREADY => rec_axis_tready
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

	clk <= not(clk) after clk_period/2;
	--------------------------------------------------------------------
	-------------------------------------------------------------------

end architecture;