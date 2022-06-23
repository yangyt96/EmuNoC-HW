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

entity M_AXIS_TRAFFIC_GEN is
    generic (
        flit_width          : Positive := flit_size;
        router_credit       : Integer  := 4; -- not necessary
        srl_fifo_depth      : Integer  := 8;
        inj_time_text       : String   := "injection_time.txt"; -- read
        packet_length_text  : String   := "packet_length.txt";  -- read_mode
        image_2_flits_text  : String   := "data_header.txt";    -- read
        inj_time_2_noc_text : String   := "inj_time_2_noc.txt"; -- write

        C_M_AXIS_TADDR_WIDTH : Integer := 4;
        C_M_AXIS_TDATA_WIDTH : Integer := 32
    );
    port (
        -- External
        M_AXIS_TADDR : out Std_logic_vector(C_M_AXIS_TADDR_WIDTH - 1 downto 0); -- additional

        -- AXI Stream Master interface
        M_AXIS_ACLK    : in Std_logic;
        M_AXIS_ARESETN : in Std_logic;

        M_AXIS_TVALID : out Std_logic;
        M_AXIS_TDATA  : out Std_logic_vector(C_M_AXIS_TDATA_WIDTH - 1 downto 0);
        M_AXIS_TSTRB  : out Std_logic_vector((C_M_AXIS_TDATA_WIDTH/8) - 1 downto 0);
        M_AXIS_TLAST  : out Std_logic;
        M_AXIS_TREADY : in Std_logic
    );
end entity;

architecture behave of M_AXIS_TRAFFIC_GEN is
    file inj_time       : text open read_mode is inj_time_text;
    file packet_length  : text open read_mode is packet_length_text;
    file image_2_flits  : text open read_mode is image_2_flits_text;
    file inj_time_2_noc : text open write_mode is inj_time_2_noc_text;

    signal data_in     : Std_logic_vector(flit_size - 1 downto 0);
    signal data_out    : Std_logic_vector(flit_size - 1 downto 0);
    signal write_en    : Std_logic := '0';
    signal read_en     : Std_logic := '0';
    signal read_valid  : Std_logic;
    signal write_valid : Std_logic;

    signal counter : Integer := 0;

    signal tlast_counter : Integer   := 0;
    signal axis_tlast    : Std_logic := '0';
    signal axis_taddr    : Std_logic_vector(C_M_AXIS_TADDR_WIDTH - 1 downto 0);

begin
    M_AXIS_TSTRB <= (others => '1');
    -- M_AXIS_TADDR <= axis_taddr;
    M_AXIS_TADDR <= (others => '0');
    M_AXIS_TLAST <= '1' when tlast_counter = 1 else
        '0';
    M_AXIS_TVALID <= read_valid;
    M_AXIS_TDATA  <= data_out;
    read_en       <= M_AXIS_TREADY;

    -- put flits into fifo whenever the fifo is empty
    read_packet_length : process
        variable input_line              : line;
        variable next_data_packet_length : Natural;
        variable next_inj_time           : Natural;
        variable next_data_flit          : flit;
    begin
        wait until M_AXIS_ARESETN = not(RST_LVL) and rising_edge(M_AXIS_ACLK);
        while not(endfile(packet_length)) loop
            write_en <= '0';

            readline(packet_length, input_line);
            read(input_line, next_data_packet_length);
            -- report "next_data_packet_length: " & Integer'image(next_data_packet_length);

            readline(inj_time, input_line);
            read(input_line, next_inj_time);
            -- report "next_inj_time: " & Integer'image(next_inj_time);

            wait until (counter >= next_inj_time - 1) and rising_edge(M_AXIS_ACLK);

            for i in 0 to (next_data_packet_length - 1) loop
                readline(image_2_flits, input_line);
                read(input_line, next_data_flit);
                data_in  <= next_data_flit;
                write_en <= '1';
                wait until rising_edge(M_AXIS_ACLK) and write_valid = '1';
            end loop;
            write_en <= '0';
        end loop;
    end process;

    inst_fifo : entity work.ring_fifo
        generic map(
            BUFFER_DEPTH => srl_fifo_depth,
            DATA_WIDTH   => flit_size,
            RST_LVL      => RST_LVL
        )
        port map(
            clk => M_AXIS_ACLK,
            rst => M_AXIS_ARESETN,

            i_wdata  => data_in,
            i_wen    => write_en,
            o_wvalid => write_valid,

            o_rdata  => data_out,
            i_ren    => read_en,
            o_rvalid => read_valid

        );

    process (M_AXIS_ACLK, M_AXIS_ARESETN, read_valid)
    begin
        if M_AXIS_ARESETN = RST_LVL then
            tlast_counter <= 0;
        elsif rising_edge(M_AXIS_ACLK) then
            if tlast_counter = 0 and read_valid = '1' and M_AXIS_TREADY = '0' then
                tlast_counter <= to_integer(unsigned(get_header_inf(data_out).packet_length));
            elsif tlast_counter = 0 and read_valid = '1' and M_AXIS_TREADY = '1' then
                tlast_counter <= to_integer(unsigned(get_header_inf(data_out).packet_length)) - 1;
            elsif tlast_counter > 0 and M_AXIS_TREADY = '1' then
                tlast_counter <= tlast_counter - 1;
            end if;
        end if;
    end process;

    axis_tlast <= '1' when tlast_counter = 1 else
        '0';
    process (M_AXIS_ACLK, M_AXIS_ARESETN, axis_tlast)
    begin
        if M_AXIS_ARESETN = RST_LVL then
            axis_taddr <= (others => '0');
        elsif falling_edge(axis_tlast) then
            axis_taddr(0) <= not(axis_taddr(0));
        end if;
    end process;

    -----------------------------------------------------------------
    clk_counter : process (M_AXIS_ACLK, M_AXIS_ARESETN)
    begin
        if M_AXIS_ARESETN = RST_LVL then
            counter <= 0;
        elsif rising_edge(M_AXIS_ACLK) then
            counter <= counter + 1;
        end if;
    end process;

    write_inj_time : process (M_AXIS_ACLK, M_AXIS_ARESETN)
        variable rowOut    : line;
        variable data_time : Time := 0 ns;
    begin
        if M_AXIS_ARESETN = not(RST_LVL) and rising_edge(M_AXIS_ACLK) then
            if (read_valid = '1') then
                data_time := now - clk_period;
                write(rowOut, data_time);
                writeline(inj_time_2_noc, rowOut);
            end if;
        end if;
    end process;

end architecture;