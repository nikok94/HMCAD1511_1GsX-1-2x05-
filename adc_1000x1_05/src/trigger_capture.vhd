----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09.04.2019 16:15:17
-- Design Name: 
-- Module Name: trigger_capture - Behavioral
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

entity trigger_capture is
    generic (
        c_data_width    : integer := 64
    );
    Port ( 
      clk               : in std_logic;
      rst               : in std_logic;
      capture_mode      : in std_logic_vector(1 downto 0);  -- определяет режим работы захвата 00 - захват по записи в контрольный регистр, 01 - захват по переднему фронту при значении входных данных больше capture_level
                                                            -- 10 - захват по заднему фронту при значении входных данных меньше capture_level, 11 - захват по внешнему триггеру ext_trig
      capture_level     : in std_logic_vector(7 downto 0);  -- определяет уровень срабатывания триггера при capture_mode = 01 и capture_mode = 10
      trigger_set_up    : in std_logic;

      data              : in std_logic_vector(c_data_width-1 downto 0); -- входные значения данных от АЦП
      ext_trig          : in std_logic; -- внешний триггер
      
      trigger_start     : out std_logic -- выходной сигнал управляет модулем захвата данных
    );
end trigger_capture;

architecture Behavioral of trigger_capture is
    --signal capture_mode     : std_logic_vector(1 downto 0); 
    --signal capture_level    : std_logic_vector(7 downto 0); -- определяет уровень срабатывания триггера при capture_mode = 01 и capture_mode = 10
    signal control_reg_setup: std_logic_vector(3 downto 0);
    
    signal control_start    : std_logic;
    signal ext_start        : std_logic;
    signal ext_start_sync_vec : std_logic_vector(3 downto 0);
    signal level_up_start   : std_logic;
    signal level_up         : std_logic:= '0';
    signal level_up_d       : std_logic:= '0';
    signal level_down_start : std_logic;
    signal level_down       : std_logic:= '0';
    signal level_down_d     : std_logic:= '0';
    signal level_up_vect    : std_logic_vector(c_data_width/8 - 1 downto 0);
    signal level_down_vect  : std_logic_vector(c_data_width/8 - 1 downto 0);
    signal data_to_compare  : std_logic_vector(c_data_width + 7 downto 0);
    signal old_data_byte    : std_logic_vector(7 downto 0);
    signal capture_enable   : std_logic;
    signal capture_start    : std_logic;

begin

trigger_start <= capture_start;

capture_enable_proc :
  process(clk, trigger_set_up, rst)
  begin
    if trigger_set_up = '1' then
      capture_enable <= '1';
    elsif rst = '1' then
      capture_enable <= '0';
    elsif rising_edge(clk) then
      if (capture_start = '1') then 
        capture_enable <= '0';
      end if;
    end if;
  end process;

control_start_process :
    process(clk, trigger_set_up)
    begin
      if (trigger_set_up = '1') then
        if (capture_mode = "00") then
          control_start <= '1';
        end if;
      elsif rising_edge(clk) then
        if (capture_start = '1') then
          control_start <= '0';
        end if;
      end if;
    end process;

ext_start_proc :
  process(clk, rst, capture_start)
  begin
    if (rst = '1') or (capture_start = '1') then 
      ext_start_sync_vec <= (others => '0');
    elsif rising_edge(clk) then
      ext_start_sync_vec(0) <= ext_trig;
      ext_start_sync_vec(2 downto 1) <= ext_start_sync_vec(1 downto 0);
    end if;
  end process;

trigger_start_out_proc :
  process(clk, rst)
  begin
      if rst = '1' then
        capture_start <= '0';
      elsif rising_edge(clk) then
        if (capture_enable = '1') then
          case capture_mode is
            when "00" => capture_start <= control_start;
            when "01" => capture_start <= level_up;
            when "10" => capture_start <= level_down;
            when "11" => capture_start <= ext_start_sync_vec(2);
            when others => capture_start <= '0';
          end case;
        else
          capture_start <= '0';
        end if;
      end if;
  end process;
  
old_data_byte_process :
  process(clk)
  begin
    if rising_edge(clk) then
        old_data_byte <= data(c_data_width-1 downto c_data_width - 8);
    end if;
  end process;

data_to_compare <= data & old_data_byte;

generate_process : for i in 1 to c_data_width/8 generate
level_up_compare_proc:
  process(clk)
  begin
    if rising_edge(clk) then
      if (data_to_compare(8*i + 7 downto 8*i) >= capture_level and data_to_compare(8*(i-1) + 7 downto 8*(i-1)) < capture_level) then
        level_up_vect(i-1) <= '1';
      else
        level_up_vect(i-1) <= '0';
      end if;
    end if;
  end process;

level_down_compare_proc:
  process(clk)
  begin
    if rising_edge(clk) then
      if (data_to_compare(8*i + 7 downto 8*i) <= capture_level and data_to_compare(8*(i-1) + 7 downto 8*(i-1)) > capture_level) then
        level_down_vect(i-1) <= '1';
      else
        level_down_vect(i-1) <= '0';
      end if;
    end if;
  end process;
  
end generate generate_process;

level_up    <= '1' when level_up_vect /= 0 else '0';
level_down  <= '1' when level_down_vect /= 0 else '0';


end Behavioral;