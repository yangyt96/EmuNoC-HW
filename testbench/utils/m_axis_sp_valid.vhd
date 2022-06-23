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

entity m_axis_sp_valid is
    generic (
        DATA_WIDTH : Integer   := 32;
        RST_LVL    : Std_logic := '0';

        FIFO_DEPTH         : Integer := 200;
        inj_time_text      : String  := "testdata/axis_validation/in/inj_time.txt";
        packet_length_text : String  := "testdata/axis_validation/in/pkt_len.txt";
        image_2_flits_text : String  := "testdata/axis_validation/in/flit_data.txt"
    );
    port (
        clk : in Std_logic;
        rst : in Std_logic;

        m_axis_tvalid : out Std_logic;
        m_axis_tdata  : out Std_logic_vector(DATA_WIDTH - 1 downto 0);
        m_axis_tstrb  : out Std_logic_vector((DATA_WIDTH/8) - 1 downto 0);
        m_axis_tlast  : out Std_logic;
        m_axis_tready : in Std_logic
    );
end entity;

architecture behave of m_axis_sp_valid is
    -- FSM
    type t_STATE is (
        s_IDLE,
        s_INIT,
        s_IDONE,
        s_WORK,
        s_WDONE
    );
    signal state         : t_STATE;
    signal tlast_counter : Integer := 0;

    -- Files
    file inj_time      : text open read_mode is inj_time_text;
    file packet_length : text open read_mode is packet_length_text;
    file image_2_flits : text open read_mode is image_2_flits_text;

    signal counter : Integer := 0;

    -- FIFO
    signal fifo_wen : Std_logic := '0';
    signal fifo_ren : Std_logic := '0';

    signal fifo_wvalid_flit : Std_logic;
    signal fifo_rvalid_flit : Std_logic;
    signal fifo_wdata_flit  : Std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal fifo_rdata_flit  : Std_logic_vector(DATA_WIDTH - 1 downto 0);

    signal fifo_wvalid_len : Std_logic;
    signal fifo_rvalid_len : Std_logic;
    signal fifo_wdata_len  : Std_logic_vector(DATA_WIDTH - 1 downto 0);
    signal fifo_rdata_len  : Std_logic_vector(DATA_WIDTH - 1 downto 0);

begin
    -- IO
    m_axis_tdata <= fifo_rdata_flit;
    m_axis_tstrb <= (others => '1');
    m_axis_tlast <= '1' when tlast_counter = 1 else
        '0';
    m_axis_tvalid <= '1' when state = s_WORK and fifo_rvalid_flit = '1' and tlast_counter > 0 else
        '0';

    -- wire
    fifo_ren <= '1' when state = s_WORK and tlast_counter > 0 and m_axis_tready = '1' and fifo_rvalid_flit = '1' else
        '0';

    -- tlast_counter
    process (clk, rst)
    begin
        if rst = RST_LVL then
            tlast_counter <= 0;
        elsif rising_edge(clk) then
            if state = s_INIT and fifo_rvalid_len = '1' then
                tlast_counter <= to_integer(unsigned(fifo_rdata_len));
            elsif state = s_WORK and tlast_counter > 0 and m_axis_tready = '1' and fifo_rvalid_flit = '1' then
                tlast_counter <= tlast_counter - 1;
            end if;
        end if;
    end process;

    -- fsm
    process (clk, rst)
    begin
        if rst = RST_LVL then
            state <= s_IDLE;
        elsif rising_edge(clk) then
            case state is

                when s_IDLE =>
                    if fifo_rvalid_len = '1' then
                        state <= s_INIT;
                    end if;

                when s_INIT =>
                    if tlast_counter > 0 then
                        state <= s_IDONE;
                    end if;

                when s_IDONE =>
                    state <= s_WORK;

                when s_WORK =>
                    if tlast_counter = 0 then
                        state <= s_WDONE;
                    end if;

                when s_WDONE =>
                    state <= s_IDLE;

            end case;
        end if;
    end process;

    -- instances
    inst_fifo_flit : entity work.ring_fifo
        generic map(
            BUFFER_DEPTH => FIFO_DEPTH,
            DATA_WIDTH   => DATA_WIDTH,
            RST_LVL      => RST_LVL
        )
        port map(
            clk => clk,
            rst => rst,

            i_wdata  => fifo_wdata_flit,
            i_wen    => fifo_wen,
            o_wvalid => fifo_wvalid_flit,

            o_rdata  => fifo_rdata_flit,
            i_ren    => fifo_ren,
            o_rvalid => fifo_rvalid_flit
        );

    inst_fifo_len : entity work.ring_fifo
        generic map(
            BUFFER_DEPTH => FIFO_DEPTH,
            DATA_WIDTH   => DATA_WIDTH,
            RST_LVL      => RST_LVL
        )
        port map(
            clk => clk,
            rst => rst,

            i_wdata  => fifo_wdata_len,
            i_wen    => fifo_wen,
            o_wvalid => fifo_wvalid_len,

            o_rdata  => fifo_rdata_len,
            i_ren    => fifo_ren,
            o_rvalid => fifo_rvalid_len

        );

    -- put flits into fifo whenever the fifo is empty
    read_packet_length : process
        variable input_line              : line;
        variable next_data_packet_length : Integer;
        variable next_inj_time           : Integer;
        variable next_data_flit          : Std_logic_vector(DATA_WIDTH - 1 downto 0);
    begin
        wait until rst = not(RST_LVL) and rising_edge(clk);
        while not(endfile(packet_length)) loop
            fifo_wen <= '0';

            readline(packet_length, input_line);
            read(input_line, next_data_packet_length);
            -- report "next_data_packet_length: " & Integer'image(next_data_packet_length);

            readline(inj_time, input_line);
            read(input_line, next_inj_time);
            -- report "next_inj_time: " & Integer'image(next_inj_time);

            -- wait until (counter >= next_inj_time - 1) and rising_edge(clk);

            for i in 0 to (next_data_packet_length - 1) loop
                readline(image_2_flits, input_line);
                read(input_line, next_data_flit);

                fifo_wdata_len  <= Std_logic_vector(to_unsigned(next_data_packet_length, DATA_WIDTH));
                fifo_wdata_flit <= next_data_flit;
                fifo_wen        <= '1';

                wait until rising_edge(clk) and fifo_wvalid_flit = '1';
            end loop;
            fifo_wen <= '0';
        end loop;
    end process;

    -----------------------------------------------------------------
    clk_counter : process (clk, rst)
    begin
        if rst = RST_LVL then
            counter <= 0;
        elsif rising_edge(clk) then
            counter <= counter + 1;
        end if;
    end process;

end architecture;