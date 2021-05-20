-------------------------------------------------------------------------------
-- Title      : Test pattern generator
-- Project    : NoC testbench generator
-------------------------------------------------------------------------------
-- File       : traffic_gen.vhd
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

entity traffic_gen is
	generic (
		flit_width          : Positive := flit_size;
		router_credit       : Integer  := 4;
		srl_fifo_depth      : Integer  := 200;
		inj_time_text       : String   := "injection_time.txt"; -- read
		packet_length_text  : String   := "packet_length.txt";  -- read_mode
		image_2_flits_text  : String   := "data_header.txt";    -- read
		inj_time_2_noc_text : String   := "inj_time_2_noc.txt"  -- write
	);
	port (
		clk, rst : in Std_logic  := '0';
		valid    : out Std_logic := '0';
		incr     : in Std_logic  := '0'; -- =1 -> credit_ctr+1, =0 credit_ctr-1
		data_out : out flit      := (others => '0')
	);
end entity;

architecture behave of traffic_gen is

	component srl_fifo is
		generic (buffer_depth : Integer := srl_fifo_depth);
		port (
			data_in      : in flit;
			data_out     : out flit;
			rst          : in Std_logic;
			write_en     : in Std_logic;
			read_en      : in Std_logic;
			buffer_full  : out Std_logic;
			buffer_empty : out Std_logic;
			clk          : in Std_logic
		);
	end component;

	signal data_in            : flit := (others => '0');
	signal data_out_rsl_fifo  : flit;
	signal credit             : Integer   := router_credit;
	signal valid_signal       : Std_logic := '0';
	signal temp_inj_time      : Natural;
	signal temp_packet_length : Natural   := 0;
	signal counter            : Natural   := 0;
	signal write_en           : Std_logic := '0';
	signal buffer_full        : Std_logic := '0';
	signal buffer_empty       : Std_logic := '1';
	-- Used text files
	file inj_time       : text open read_mode is inj_time_text;
	file packet_length  : text open read_mode is packet_length_text;
	file image_2_flits  : text open read_mode is image_2_flits_text;
	file inj_time_2_noc : text open write_mode is inj_time_2_noc_text;

begin

	-------------------------------------------------------------------
	------------------ internal buffer component ----------------------

	int_buffer : entity work.srl_fifo
		generic map(buffer_depth => srl_fifo_depth)
		port map(
			data_in      => data_in,
			data_out     => data_out_rsl_fifo,
			rst          => rst,
			write_en     => write_en,
			read_en      => valid_signal,
			buffer_full  => buffer_full,
			buffer_empty => buffer_empty,
			clk          => clk);

	-------------------------------------------------------------------
	----------- Read text files into the internal buffer --------------

	read_packet_length : process
		variable input_line              : line;
		variable next_data_packet_length : Natural;
		variable next_inj_time           : Natural;
		variable next_data_flit          : flit;
	begin

		wait until ((rst = not(RST_LVL)) and rising_edge(clk)); -- set reset for design
		while not (endfile(packet_length)) loop
			write_en <= '0';
			readline(packet_length, input_line);
			read(input_line, next_data_packet_length);
			temp_packet_length <= next_data_packet_length;
			readline(inj_time, input_line);
			read(input_line, next_inj_time);
			temp_inj_time <= next_inj_time;

			wait until (counter >= temp_inj_time - 1) and rising_edge(clk);

			-- Send Data into internal Buffer
			for i in 0 to (temp_packet_length - 1) loop
				readline(image_2_flits, input_line);
				read(input_line, next_data_flit);
				data_in  <= next_data_flit;
				write_en <= '1';
				wait until rising_edge(clk);
			end loop;
		end loop;

		-- Put zeros after the whole message tranmission
		if endfile(packet_length) then
			write_en <= '0';
			data_in  <= (others => '0');
		end if;

	end process;

	-------------------------------------------------------------------
	------------------------- Clk counter -----------------------------

	clk_counter : process (clk)
	begin
		if (rising_edge(clk)) then
			if (rst = RST_LVL) then
				counter <= 0;
			else
				counter <= counter + 1;
			end if;
		end if;
	end process;

	-------------------------------------------------------------------
	------------------------ Credit counter ---------------------------

	credit_counter : process (clk, rst)
	begin

		if (rising_edge(clk)) then
			if (rst = RST_LVL) then
				credit <= router_credit;
			else
				if ((credit > 0) and valid_signal = '1' and incr = '0') then
					credit <= credit - 1;
				elsif ((credit < router_credit) and valid_signal = '0' and incr = '1') then
					credit <= credit + 1;
				end if;
			end if;

		end if;

	end process;

	-------------------------------------------------------------------
	---------------------- Determine valid flag -----------------------

	data_out <= data_out_rsl_fifo;

	valid_flag : process (buffer_empty, credit, incr)
	begin
		if (buffer_empty = '0' and ((credit > 0) or (incr = '1'))) then
			valid        <= '1';
			valid_signal <= '1';
		else
			valid        <= '0';
			valid_signal <= '0';
		end if;
	end process;

	-------------------------------------------------------------------
	------------------- Save injection time to NoC --------------------

	write_inj_time : process (clk, rst)
		variable rowOut    : line;
		variable data_time : Time := 0 ns;
	begin
		if clk = '1' and clk'event and rst = not(RST_LVL) then
			if (valid_signal = '1') then
				data_time := now - clk_period;
				write(rowOut, data_time);
				writeline(inj_time_2_noc, rowOut);
			end if;
		end if;
	end process;
	--------------------------------------------------------------------
	-------------------------------------------------------------------

end architecture;