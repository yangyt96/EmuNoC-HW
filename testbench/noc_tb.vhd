library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

use work.NOC_3D_PACKAGE.all;

entity noc_tb is
    generic (
        RST_LVL    : Std_logic := '0';
        CLK_PERIOD : Time      := 1 ns
    );
end entity;

architecture behave of noc_tb is
    -- System
    signal clk     : Std_logic := '1';
    signal rst     : Std_logic := RST_LVL;
    signal clk_cnt : Integer   := 0;

    -- Constants
    constant PE_NUM             : Integer := max_x_dim * max_y_dim * max_z_dim;
    constant NUM_IO             : Integer := max_x_dim * max_y_dim * max_z_dim * max_vc_num;
    constant NUM_ROUTER         : Integer := max_x_dim * max_y_dim * max_z_dim;
    constant C_AXIS_TDATA_WIDTH : Integer := flit_size;
    constant PE_ADDR_WIDTH      : Integer := bit_width(max_x_dim * max_y_dim * max_z_dim);

    -- Functions
    function iconv_hdr(var : flit) return flit is
        variable ret           : flit := (others => '0');
        variable offset_var    : Integer;
        variable offset_ret    : Integer;
        variable dst           : Integer;
        variable xd, yd, zd    : Integer;
        variable xs, ys, zs    : Integer;
    begin
        offset_var := PACKET_LEN_WIDTH;
        xd         := to_integer(unsigned(var(offset_var + X_ADDR_WIDTH - 1 downto offset_var)));
        offset_var := offset_var + X_ADDR_WIDTH;
        yd         := to_integer(unsigned(var(offset_var + Y_ADDR_WIDTH - 1 downto offset_var)));
        offset_var := offset_var + Y_ADDR_WIDTH;
        zd         := to_integer(unsigned(var(offset_var + Z_ADDR_WIDTH - 1 downto offset_var)));
        offset_var := offset_var + Z_ADDR_WIDTH;
        xs         := to_integer(unsigned(var(offset_var + X_ADDR_WIDTH - 1 downto offset_var)));
        offset_var := offset_var + X_ADDR_WIDTH;
        ys         := to_integer(unsigned(var(offset_var + Y_ADDR_WIDTH - 1 downto offset_var)));
        offset_var := offset_var + Y_ADDR_WIDTH;
        zs         := to_integer(unsigned(var(offset_var + Z_ADDR_WIDTH - 1 downto offset_var)));
        offset_var := offset_var + Z_ADDR_WIDTH;

        offset_ret                   := PACKET_LEN_WIDTH;
        ret(offset_ret - 1 downto 0) := var(offset_ret - 1 downto 0);

        -- dst pos conversion
        ret(PE_ADDR_WIDTH + offset_ret - 1 downto offset_ret) := Std_logic_vector(to_unsigned(xd + yd * MAX_X_DIM + zd * MAX_X_DIM * MAX_Y_DIM, PE_ADDR_WIDTH));
        offset_ret                                            := offset_ret + PE_ADDR_WIDTH;
        -- src pos conversion
        ret(PE_ADDR_WIDTH + offset_ret - 1 downto offset_ret) := Std_logic_vector(to_unsigned(xs + ys * MAX_X_DIM + zs * MAX_X_DIM * MAX_Y_DIM, PE_ADDR_WIDTH));
        offset_ret                                            := offset_ret + PE_ADDR_WIDTH;

        if offset_var = offset_ret then
            ret(C_AXIS_TDATA_WIDTH - 1 downto offset_ret) := var(C_AXIS_TDATA_WIDTH - 1 downto offset_var);
        elsif offset_var > offset_ret then
            ret(C_AXIS_TDATA_WIDTH - (offset_var - offset_ret) - 1 downto offset_ret) := var(C_AXIS_TDATA_WIDTH - 1 downto offset_var);
        elsif offset_var < offset_ret then
            ret(C_AXIS_TDATA_WIDTH - 1 downto offset_ret) := var(C_AXIS_TDATA_WIDTH - (offset_ret - offset_var) - 1 downto offset_var);
        end if;

        return ret;
    end function;

    -- Signals
    -- noc
    signal local_rx          : flit_vector(NUM_ROUTER - 1 downto 0);
    signal local_tx          : flit_vector(NUM_ROUTER - 1 downto 0);
    signal local_vc_write_rx : Std_logic_vector(NUM_IO - 1 downto 0);
    signal local_vc_write_tx : Std_logic_vector(NUM_IO - 1 downto 0);
    signal local_incr_rx_vec : Std_logic_vector(NUM_IO - 1 downto 0);
    signal local_incr_tx_vec : Std_logic_vector(NUM_IO - 1 downto 0);

    -- inject axis
    signal inject_axis_tready_vec : Std_logic_vector(NUM_ROUTER - 1 downto 0);
    signal inject_axis_tdata_vec  : flit_vector(NUM_ROUTER - 1 downto 0);
    signal inject_axis_tstrb_vec  : Std_logic_vector((C_AXIS_TDATA_WIDTH/8) * NUM_ROUTER - 1 downto 0);
    signal inject_axis_tlast_vec  : Std_logic_vector(NUM_ROUTER - 1 downto 0);
    signal inject_axis_tvalid_vec : Std_logic_vector(NUM_ROUTER - 1 downto 0);

    -- sp inject axis
    signal gen_axis_tready : Std_logic;
    signal gen_axis_tdata  : Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal gen_axis_tstrb  : Std_logic_vector((C_AXIS_TDATA_WIDTH/8) - 1 downto 0);
    signal gen_axis_tlast  : Std_logic;
    signal gen_axis_tvalid : Std_logic;

    -- clk halt
    signal clkh         : Std_logic;
    signal halt         : Std_logic := '0';
    signal halt_pe      : Std_logic;
    signal ub_count_wen : Std_logic;
    signal ub_count     : Std_logic_vector(31 downto 0);
    signal noc_count    : Std_logic_vector(31 downto 0);

    -- inj pe fifo
    signal fifo_wdata   : Std_logic_vector(C_AXIS_TDATA_WIDTH - 1 downto 0);
    signal fifos_wen    : Std_logic_vector(PE_NUM - 1 downto 0);
    signal fifos_wvalid : Std_logic_vector(PE_NUM - 1 downto 0);

begin
    process
    begin
        report "max_x_dim: " & Integer'image(max_x_dim);
        report "max_y_dim: " & Integer'image(max_y_dim);
        report "max_z_dim: " & Integer'image(max_z_dim);
        report "PE_NUM: " & Integer'image(PE_NUM);
        report "pkt_len_width: " & Integer'image(packet_len_width);
        report "PE_ADDR_WIDTH:" & Integer'image(PE_ADDR_WIDTH);
        report "PACKET_LEN_WIDTH + PE_ADDR_WIDTH * 2 - 1 = " & Integer'image(PACKET_LEN_WIDTH + PE_ADDR_WIDTH * 2 - 1);
        wait;
    end process;

    initiator : entity work.m_axis_sp_valid
        generic map(
            inj_time_text      => "testdata/axis_validation/in/inj_time.txt",
            packet_length_text => "testdata/axis_validation/in/pkt_len.txt",
            image_2_flits_text => "testdata/axis_validation/in/flit_data.txt"
        )
        port map(
            clk => clk,
            rst => rst,

            M_AXIS_TVALID => gen_axis_tvalid,
            M_AXIS_TDATA  => gen_axis_tdata,
            M_AXIS_TSTRB  => gen_axis_tstrb,
            M_AXIS_TLAST  => gen_axis_tlast,
            M_AXIS_TREADY => gen_axis_tready
        );

    -- CLK CTRL
    inst_clock_halter : entity work.clock_halter
        generic map(
            CNT_WIDTH => 32,
            RST_LVL   => RST_LVL
        )
        port map(
            clk  => clk,
            rst  => rst,
            clkh => clkh,

            i_halt => halt,
            o_halt => halt_pe,

            i_ub_count_wen => ub_count_wen,
            i_ub_count     => ub_count,
            o_run_count    => noc_count
        );

    -- SP
    inst_axis_sp_inject : entity work.axis_sp_inject
        port map(
            clk => clk,
            rst => rst,

            s_axis_tvalid => gen_axis_tvalid,
            s_axis_tdata  => gen_axis_tdata,
            s_axis_tstrb  => gen_axis_tstrb,
            s_axis_tlast  => gen_axis_tlast,
            s_axis_tready => gen_axis_tready,

            o_fifo_wdata   => fifo_wdata,
            o_fifos_wen    => fifos_wen,
            i_fifos_wvalid => fifos_wvalid,

            o_ub_count_wen => ub_count_wen,
            o_ub_count     => ub_count,
            i_noc_count    => noc_count
        );

    -- HALT PE
    gen_pe_inject : for i in 0 to PE_NUM - 1 generate
        inst_pe_inject : entity work.pe_inject
            generic map(
                BUFFER_DEPTH       => PE_NUM * 2,
                C_AXIS_TDATA_WIDTH => flit_size,
                RST_LVL            => RST_LVL
            )
            port map(
                clk => clk,
                rst => rst,

                i_halt => halt_pe,

                i_fifo_wdata  => fifo_wdata,
                i_fifo_wen    => fifos_wen(i),
                o_fifo_wvalid => fifos_wvalid(i),

                m_axis_tvalid => inject_axis_tvalid_vec(i),
                m_axis_tdata  => inject_axis_tdata_vec(i),
                m_axis_tstrb  => inject_axis_tstrb_vec((C_AXIS_TDATA_WIDTH/8) * (i + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * i),
                m_axis_tlast  => inject_axis_tlast_vec(i),
                m_axis_tready => inject_axis_tready_vec(i)
            );
    end generate;

    -- NI Slave
    gen_ni_slave : for i in 0 to NUM_ROUTER - 1 generate
        inst_slave : entity work.s_axis_ni
            generic map(
                FLIT_SIZE     => flit_size,
                VC_NUM        => max_vc_num,
                ROUTER_CREDIT => 2,

                C_S_AXIS_TDATA_WIDTH => flit_size
            )
            port map(
                -- port to router local input flit
                o_local_tx          => local_rx(i),
                o_local_vc_write_tx => local_vc_write_rx(max_vc_num * (i + 1) - 1 downto max_vc_num * i),
                i_local_incr_rx_vec => local_incr_tx_vec(max_vc_num * (i + 1) - 1 downto max_vc_num * i),

                -- AXI Stream Slave interface
                S_AXIS_ACLK    => clk,
                S_AXIS_ARESETN => rst,

                S_AXIS_TREADY => inject_axis_tready_vec(i),
                S_AXIS_TDATA  => inject_axis_tdata_vec(i),
                S_AXIS_TSTRB  => inject_axis_tstrb_vec((C_AXIS_TDATA_WIDTH/8) * (i + 1) - 1 downto (C_AXIS_TDATA_WIDTH/8) * i),
                S_AXIS_TLAST  => inject_axis_tlast_vec(i),
                S_AXIS_TVALID => inject_axis_tvalid_vec(i)
            );
    end generate;

    -- DUT
    DUT_full_noc_comp : entity work.full_noc
        port map(
            clk => clkh,
            rst => rst,

            local_rx          => local_rx,
            local_vc_write_rx => local_vc_write_rx,
            local_incr_rx_vec => local_incr_rx_vec,
            local_tx          => local_tx,
            local_vc_write_tx => local_vc_write_tx,
            local_incr_tx_vec => local_incr_tx_vec
        );

    gen_traffic_rec : for i in 0 to NUM_IO - 1 generate
        inst_traffic_rec : entity work.traffic_rec
            generic map(
                flit_width    => flit_size,
                rec_time_text => "testdata/noc_tb/out/" & Integer'image(i/max_vc_num) & "/recv_time_noc" & Integer'image(i mod max_vc_num) & ".txt",
                rec_data_text => "testdata/noc_tb/out/" & Integer'image(i/max_vc_num) & "/recv_data_noc" & Integer'image(i mod max_vc_num) & ".txt"
            )
            port map(
                clk     => clkh,
                rst     => rst,
                valid   => local_vc_write_tx(i),
                incr    => local_incr_rx_vec(i),
                data_in => iconv_hdr(local_tx(i/2))
            );
    end generate;

    -- System
    clk <= not(clk) after CLK_PERIOD/2;

    proc_clk_cnt : process (clk, rst)
    begin
        if rst = RST_LVL then
            clk_cnt <= 0;
        elsif rising_edge(clk) then
            clk_cnt <= clk_cnt + 1;
        end if;
    end process;

    proc_rst : process
    begin
        rst <= RST_LVL;
        wait for (CLK_PERIOD * 2);
        rst <= not(RST_LVL);
        wait;
    end process proc_rst;

end architecture;