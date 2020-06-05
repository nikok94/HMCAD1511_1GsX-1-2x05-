----------------------------------------------------------------------------------
-- Company: ИСЭ
-- Engineer: МНС КОКИН Д.С.
-- 
-- Create Date: 12.04.2019 09:47:15
-- Design Name: Проект для платы гигагерцового АЦП на базе HMCAD1511
-- Module Name: data_capture - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;

library work;
use work.mem_64_4096;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity data_capture is
    generic (
      c_max_window_size_width   : integer := 16;
      c_strm_data_width         : integer := 64;
      c_trig_delay              : integer := 4
    );
    Port ( 
      areset            : in std_logic;
      trigger_start     : in std_logic;
      window_size       : in std_logic_vector(c_max_window_size_width - 1 downto 0);
      trig_position     : in std_logic_vector(c_max_window_size_width - 1 downto 0);

      aclk              : in std_logic;
      s_strm_data       : in std_logic_vector(c_strm_data_width - 1 downto 0);
      s_strm_valid      : in std_logic;
      --dec               : in std_logic;

      m_strm_data       : out std_logic_vector(c_strm_data_width - 1 downto 0);
      m_strm_valid      : out std_logic;
      m_strm_ready      : in std_logic;
      m_strm_rst        : in std_logic
    );
end data_capture;

architecture Behavioral of data_capture is
    type state_machine                  is (edle, wait_trigger_start, capture, send_buff_data, addr_edge);
    signal state, next_state            : state_machine;
    constant c_memory_max_width         : std_logic_vector(c_max_window_size_width - 1 downto 0):= x"01FF";
    constant clog2_c_memory_max_width   : integer := 9;
    signal wr_addr                      : std_logic_vector(clog2_c_memory_max_width - 1 downto 0);
    signal rd_addr                      : std_logic_vector(clog2_c_memory_max_width - 1 downto 0);
    signal s1_ready                     : std_logic;
    signal m_valid                      : std_logic;
    signal wr_en                        : std_logic;
    signal dina                         : std_logic_vector(c_strm_data_width - 1 downto 0);
    signal addr_start_position          : std_logic_vector(clog2_c_memory_max_width - 1 downto 0);
    signal addr_end_position            : std_logic_vector(clog2_c_memory_max_width - 1 downto 0);
    signal rd_data                      : std_logic;
    signal start_addr_iscorrect         : std_logic;
    signal counter                      : std_logic_vector(clog2_c_memory_max_width - 1 downto 0);

begin

valid_proc: 
    process(aclk)
    begin
      if rising_edge(aclk) then
        m_strm_valid <= rd_data;
      end if;
    end process;

rd_data <= m_valid and m_strm_ready;

wr_addr_process  : 
  process(aclk, state)
  begin
    if (state = edle) then
      wr_addr <= (others => '0');
    elsif rising_edge(aclk) then
       if (state = capture) or (state = wait_trigger_start) then
        if (s_strm_valid = '1') then
          wr_en <= '1';
          dina <= s_strm_data;
          wr_addr <= wr_addr + 1;
        else
          wr_en <= '0';
        end if;
      end if;
    end if;
  end process;

start_addr_proc :
process(aclk, state)
begin
  if (state = edle) then
    addr_start_position <= (others => '0');
  elsif rising_edge(aclk) then
    if (state = wait_trigger_start) then
        addr_start_position <= (((wr_addr - trig_position(clog2_c_memory_max_width - 1 downto 0)) - c_trig_delay));
        addr_end_position   <= (((wr_addr - trig_position(clog2_c_memory_max_width - 1 downto 0)) - c_trig_delay) - 1);
    end if;
  end if;
end process;

rd_addr_process  :
  process(aclk, state)
  begin
    if (state = edle) then
      rd_addr <= (others => '0');
    elsif rising_edge(aclk) then
      if (state = capture) then
        rd_addr <= addr_start_position;
      else
        if (rd_data = '1') then
          rd_addr <= rd_addr + 1;
        end if;
      end if;
    end if;
  end process;

sync_state_machine_proc :
  process(aclk, areset, m_strm_rst)
  begin
    if (areset = '1') or (m_strm_rst = '1') then
      state <= edle;
    elsif rising_edge(aclk) then
      state <= next_state;
    end if;
  end process;

output_state_machine_proc :
  process(state)
  begin
    m_valid <= '0';
    case state is
      when send_buff_data =>
        m_valid <= '1';
      when others =>
        m_valid <= '0';
    end case;
  end process;

next_state_machine_proc :
  process(state, trigger_start, wr_addr, addr_end_position, window_size, rd_data)
  begin
    next_state <= state;
    case state is
      when edle => 
        next_state <= wait_trigger_start;
      when wait_trigger_start =>
        if (window_size <= c_memory_max_width) then
          if (trigger_start = '1') then
            next_state <= capture;
          end if;
        end if;
      when capture =>
        if (wr_addr = addr_end_position) then
          next_state <= send_buff_data;
        end if;
      when send_buff_data =>
        if (rd_data = '1') then
          next_state <= addr_edge;
        end if;
      when addr_edge => 
         next_state <= send_buff_data;
      when others =>
        next_state <= edle;
    end case;
  end process;

memory_inst : entity mem_64_4096
  PORT MAP(
    clka    => aclk,
    wea(0)  => wr_en,
    addra   => wr_addr,
    dina    => dina,
    clkb    => aclk,
    addrb   => rd_addr,
    doutb   => m_strm_data
  );

end Behavioral;
