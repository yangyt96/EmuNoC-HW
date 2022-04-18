library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.NOC_3D_PACKAGE.all;
use work.TESTBENCH_PACKAGE.all;

entity generator_router_local is
    generic (
        Xis                : Integer           := 1;
        Yis                : Integer           := 1;
        Zis                : Integer           := 0;
        port_num           : Integer           := 5;
        port_exist         : integer_vec       := (0, 1, 2, 3, 4);
        vc_num_vec         : integer_vec       := (2, 2, 2, 2, 2);
        vc_num_out_vec     : integer_vec       := (2, 2, 2, 2, 2);
        vc_depth_array     : vc_prop_int_array := ((2, 2), (2, 2), (2, 2), (2, 2), (2, 2));
        vc_depth_out_array : vc_prop_int_array := ((32, 32), (2, 2), (2, 2), (2, 2), (2, 2));
        rout_algo          : String            := "XYZ"
    );
    port (
        clk : in Std_logic;
        rst : in Std_logic;

        o_local_tx          : out flit;
        o_local_vc_write_tx : out Std_logic_vector(vc_num_out_vec(0) - 1 downto 0);
        i_local_incr_rx     : in Std_logic_vector(vc_num_vec(0) - 1 downto 0)
    );
end entity;

architecture behave of generator_router_local is
    -- Router port signals
    signal router_data_rx         : flit_vector(port_num - 1 downto 0)                         := (others => (others => '0'));
    signal router_vc_write_rx_vec : Std_logic_vector(int_vec_sum(vc_num_vec) - 1 downto 0)     := (others => '0');
    signal router_incr_rx_vec     : Std_logic_vector(int_vec_sum(vc_num_out_vec) - 1 downto 0) := (others => '0');
    signal router_data_tx         : flit_vector(port_num - 1 downto 0)                         := (others => (others => '0'));
    signal router_vc_write_tx_vec : Std_logic_vector(int_vec_sum(vc_num_out_vec) - 1 downto 0) := (others => '0');
    signal router_incr_tx_vec     : Std_logic_vector(int_vec_sum(vc_num_vec) - 1 downto 0);--     := (others => '0');

begin
    -- I/O connections
    o_local_tx                                     <= router_data_tx(0);
    o_local_vc_write_tx                            <= router_vc_write_tx_vec(vc_num_out_vec(0) - 1 downto 0);
    router_incr_rx_vec(vc_num_vec(0) - 1 downto 0) <= i_local_incr_rx;

    -- instance
    inst_router : entity work.router_pl
        generic map(
            port_num                     => port_num,
            Xis                          => Xis,
            Yis                          => Yis,
            Zis                          => Zis,
            header_incl_in_packet_length => true,
            -- integer vector of range "0 to port_num-1"
            port_exist     => port_exist,
            vc_num_vec     => vc_num_vec,
            vc_num_out_vec => vc_num_out_vec,
            -- integer vector of range "0 to port_num-1, 0 to max_vc_num-1"
            vc_depth_array     => vc_depth_array,
            vc_depth_out_array => vc_depth_out_array,
            rout_algo          => rout_algo
        )
        port map(
            -- System
            clk => clk,
            rst => rst,
            -- Inputs
            data_rx         => router_data_rx,
            vc_write_rx_vec => router_vc_write_rx_vec,
            incr_rx_vec     => router_incr_rx_vec,
            -- Outputs
            data_tx_pl         => router_data_tx,
            vc_write_tx_pl_vec => router_vc_write_tx_vec,
            incr_tx_pl_vec     => router_incr_tx_vec
        );

    -- input
    gen_inst_traffic : for i in 1 to port_num - 1 generate
    begin
        inst_traffic : entity work.traffic_gen
            generic map(
                flit_width          => flit_size,
                router_credit       => vc_depth_array(i)(0),
                srl_fifo_depth      => 200,
                inj_time_text       => "testdata/m_axis_ni_tb/in/" & Integer'image(i) & "/inj_time.txt",  -- r
                packet_length_text  => "testdata/m_axis_ni_tb/in/" & Integer'image(i) & "/pkt_len.txt",   -- r
                image_2_flits_text  => "testdata/m_axis_ni_tb/in/" & Integer'image(i) & "/flit_data.txt", -- r
                inj_time_2_noc_text => "testdata/m_axis_ni_tb/out/" & Integer'image(i) & "/inj_time.txt"  -- w
            )
            port map(
                clk      => clk,
                rst      => rst,
                valid    => router_vc_write_rx_vec(i * vc_num_vec(0)),
                incr     => router_incr_tx_vec(i * vc_num_vec(0)),
                data_out => router_data_rx(i)
            );
    end generate;

end architecture;