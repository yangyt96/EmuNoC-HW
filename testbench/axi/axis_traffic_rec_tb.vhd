library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;
use work.NOC_3D_PACKAGE.all;
use work.TESTBENCH_PACKAGE.all;

entity axis_traffic_rec_tb is
end entity;
architecture behave of axis_traffic_rec_tb is

	constant cnt_flit_width          : Positive := flit_size;
	constant cnt_router_credit       : Integer  := 1;
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

	signal router_local_vc_write_tx : Std_logic_vector(max_vc_num - 1 downto 0) := (others => '0');
	signal router_local_incr_rx_vec : Std_logic_vector(max_vc_num - 1 downto 0) := (others => '0');

	signal rec_axis_tvalid : Std_logic                                         := '0';
	signal rec_axis_tdata  : Std_logic_vector(cnt_flit_width - 1 downto 0)     := (others => '0');
	signal rec_axis_tstrb  : Std_logic_vector((cnt_flit_width/8) - 1 downto 0) := (others => '0');
	signal rec_axis_tlast  : Std_logic                                         := '0';
	signal rec_axis_tready : Std_logic                                         := '0';

begin
	-------------------------------------------------------------------
	------------------- Component instantiations ----------------------

	-- traffic gen
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
			valid    => router_local_vc_write_tx(0),
			incr     => router_local_incr_rx_vec(0),
			data_out => data_int
		);

	inst_m_axis_router_local : entity work.M_AXIS_ROUTER_LOCAL
		generic map(
			FLIT_SIZE            => cnt_flit_width,
			VC_NUM               => max_vc_num,
			C_M_AXIS_TDATA_WIDTH => cnt_flit_width,

			BUFFER_DEPTH => cnt_router_credit
		)
		port map(
			-- NoC router local port
			i_local_tx          => data_int,
			i_local_vc_write_tx => router_local_vc_write_tx, -- valid
			o_local_incr_rx_vec => router_local_incr_rx_vec, -- incr

			-- AXI Stream Master interface
			M_AXIS_ACLK    => clk,
			M_AXIS_ARESETN => rst,

			M_AXIS_TVALID => rec_axis_tvalid,
			M_AXIS_TDATA  => rec_axis_tdata,
			M_AXIS_TSTRB  => rec_axis_tstrb,
			M_AXIS_TLAST  => rec_axis_tlast,
			M_AXIS_TREADY => rec_axis_tready
		);

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