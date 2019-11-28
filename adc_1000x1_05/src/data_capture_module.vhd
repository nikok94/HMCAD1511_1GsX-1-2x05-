----------------------------------------------------------------------------------
-- Company: ИСЭ
-- Engineer: МНС КОКИН Д.С.
-- 
-- Create Date: 12.04.2019 09:47:15
-- Design Name: Проект для платы гигагерцового АЦП на базе HMCAD1511
-- Module Name: data_capture_module - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity data_capture_module is
    generic (
      c_max_window_size_width   : integer := 16;
      c_strm_data_width         : integer := 64;
      c_trig_delay              : integer := 4
    );
    Port ( 
      clk               : in std_logic;
      rst               : in std_logic;
      trigger_start     : in std_logic;
      window_size       : in std_logic_vector(c_max_window_size_width - 1 downto 0);
      trig_position     : in std_logic_vector(c_max_window_size_width - 1 downto 0);

      s0_strm_data       : in std_logic_vector(c_strm_data_width - 1 downto 0);
      s0_strm_valid      : in std_logic;
      s0_strm_ready      : out std_logic;

      s1_strm_data       : in std_logic_vector(c_strm_data_width - 1 downto 0);
      s1_strm_valid      : in std_logic;
      s1_strm_ready      : out std_logic;

      m0_strm_data       : out std_logic_vector(c_strm_data_width - 1 downto 0);
      m0_strm_valid      : out std_logic;
      m0_strm_ready      : in std_logic;
      m0_strm_rst        : in std_logic;
      
      m1_strm_data       : out std_logic_vector(c_strm_data_width - 1 downto 0);
      m1_strm_valid      : out std_logic;
      m1_strm_ready      : in std_logic;
      m1_strm_rst        : in std_logic
    );
end data_capture_module;

architecture Behavioral of data_capture_module is
    component  mem_64_4096 IS
    PORT (
        clka : IN STD_LOGIC;
        wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        addra : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
        dina : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        clkb : IN STD_LOGIC;
        addrb : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
        doutb : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
    );
    END component mem_64_4096;
    
    type state_machine is (edle, wait_trigger_start, capture, send_buff_data0, send_buff_data1, addr0_edge, addr1_edge);
    signal state, next_state    : state_machine;
    constant c_memory_max_width : std_logic_vector(c_max_window_size_width - 1 downto 0):= x"01FF";
    signal wr_addr              : std_logic_vector(c_max_window_size_width - 1 downto 0);
    signal rd_addr0             : std_logic_vector(c_max_window_size_width - 1 downto 0);
    signal rd_addr1             : std_logic_vector(c_max_window_size_width - 1 downto 0);
    signal s0_ready              : std_logic;
    signal s1_ready              : std_logic;
    signal m0_valid             : std_logic;
    signal m1_valid             : std_logic;
    signal wr_en                : std_logic;
    signal addr_start_position  : std_logic_vector(c_max_window_size_width - 1 downto 0);
    signal addr_end_position    : std_logic_vector(c_max_window_size_width - 1 downto 0);
    signal rd_data0             : std_logic;
    signal rd_data1             : std_logic;
begin

valid_proc: 
    process(clk)
    begin
      if rising_edge(clk) then
        m0_strm_valid <= rd_data0;
        m1_strm_valid <= rd_data1;
      end if;
    end process;
    

rd_data0 <= m0_valid and m0_strm_ready;
rd_data1 <= m1_valid and m1_strm_ready;

trigger_setting_proc :
  process(clk, state)
  begin
     if (state = edle) then
       addr_start_position    <= (others => '0');
       addr_end_position      <= (others => '0');
     elsif rising_edge(clk) then
       if (trigger_start = '1') then

         if (wr_addr >= trig_position + c_trig_delay ) then
           addr_start_position <= wr_addr - (trig_position + c_trig_delay);
         else
           addr_start_position <= c_memory_max_width - (trig_position + c_trig_delay) + wr_addr;
         end if;
         
         if wr_addr <= (c_memory_max_width - window_size + trig_position + c_trig_delay) then
           addr_end_position <= (wr_addr + window_size - trig_position - c_trig_delay - 1);
         else
           addr_end_position <= (wr_addr + window_size - trig_position - c_trig_delay - 1) - c_memory_max_width;
         end if;
         
       end if;
     end if;
  end process;

s0_strm_ready <= s0_ready;
s1_strm_ready <= s1_ready;

wr_en <= s0_strm_valid and s1_strm_valid and s0_ready and s1_ready;

wr_addr_process  : 
  process(clk, state)
  begin
    if (state = edle) then
      wr_addr <= (others => '0');
    elsif rising_edge(clk) then
       if (state = capture) or (state = wait_trigger_start) then
        if (wr_en = '1') then
          if (wr_addr >= c_memory_max_width) then 
            wr_addr <= (others => '0');
          else
            wr_addr <= wr_addr + 1;
          end if;
        end if;
      end if;
    end if;
  end process;


rd_addr0_process  :
  process(clk, state)
  begin
    if (state = edle) then
      rd_addr0 <= (others => '0');
    elsif rising_edge(clk) then
      if (state = capture) then
        rd_addr0 <= addr_start_position;
      else
        if (rd_data0 = '1') then
          if (rd_addr0 >= c_memory_max_width) then 
            rd_addr0 <= (others => '0');
          else
            rd_addr0 <= rd_addr0 + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

rd_addr1_process  :
  process(clk, state)
  begin
    if (state = edle) then
      rd_addr1 <= (others => '0');
    elsif rising_edge(clk) then
      if (state = capture) then
        rd_addr1 <= addr_start_position;
      else
        if (rd_data1 = '1') then
          if (rd_addr1 >= c_memory_max_width) then 
            rd_addr1 <= (others => '0');
          else
            rd_addr1 <= rd_addr1 + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

sync_state_machine_proc :
  process(clk, rst)
  begin
    if (rst = '1') then
      state <= edle;
    elsif rising_edge(clk) then
      state <= next_state;
    end if;
  end process;

output_state_machine_proc :
  process(state, wr_addr)
  begin
    s0_ready <= '0';
    s1_ready <= '0';
    m0_valid <= '0';
    m1_valid <= '0';
    case state is
      when edle => 
      when wait_trigger_start =>
        s0_ready <= '1';
        s1_ready <= '1';
      when capture =>
        s0_ready <= '1';
        s1_ready <= '1';
      when send_buff_data0 =>
        m0_valid <= '1';
      when send_buff_data1 =>
        m1_valid <= '1';
      when others =>
    end case;
  end process;

next_state_machine_proc :
  process(state, trigger_start, wr_addr, addr_end_position, window_size, m0_strm_rst, m1_strm_rst, rd_data0, rd_data1)
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
          next_state <= send_buff_data0;
        end if;
      when send_buff_data0 =>
        if (rd_data0 = '1') then
          next_state <= addr0_edge;
        elsif (m0_strm_rst = '1') then
          next_state <= send_buff_data1;
        end if;
      when addr0_edge => 
         next_state <= send_buff_data0;
      when send_buff_data1 =>
        if (rd_data1 = '1') then
          next_state <= addr1_edge;
        elsif (m1_strm_rst = '1') then
          next_state <= edle;
        end if;
      when addr1_edge => 
         next_state <= send_buff_data1;
      when others =>
        next_state <= edle;
    end case;
  end process;

memory0_inst : mem_64_4096
  PORT MAP(
    clka    => clk,
    wea(0)  => wr_en,
    addra   => wr_addr(8 downto 0),
    dina    => s0_strm_data,
    clkb    => clk,
    addrb   => rd_addr0(8 downto 0),
    doutb   => m0_strm_data
  );

memory1_inst : mem_64_4096
  PORT MAP(
    clka    => clk,
    wea(0)  => wr_en,
    addra   => wr_addr(8 downto 0),
    dina    => s1_strm_data,
    clkb    => clk,
    addrb   => rd_addr1(8 downto 0),
    doutb   => m1_strm_data
  );

end Behavioral;
