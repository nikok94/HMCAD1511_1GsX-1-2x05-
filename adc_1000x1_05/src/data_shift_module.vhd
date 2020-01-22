----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 30.12.2019 10:55:39
-- Design Name: 
-- Module Name: data_shift_module - Behavioral
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

entity data_shift_module is
    Port (
      rst               : in std_logic;
      clk               : in std_logic;

      adc1_data         : in std_logic_vector(63 downto 0);
      adc2_data0        : in std_logic_vector(31 downto 0);
      adc2_data1        : in std_logic_vector(31 downto 0);
      data_valid        : in std_logic;
      
      adc1_trig_vec     : in std_logic_vector(7 downto 0);
      adc2_0_trig_vec   : in std_logic_vector(3 downto 0);
      adc2_1_trig_vec   : in std_logic_vector(3 downto 0);
      
      tr_start1         : in std_logic;
      tr_start2_0       : in std_logic;
      tr_start2_1       : in std_logic;
      level             : in std_logic_vector(7 downto 0);
      
      capture_mode      : out std_logic_vector(1 downto 0);
      capture_level     : out std_logic_vector(7 downto 0);
      trigger_set_up    : out std_logic;
      
      pulse_out         : out std_logic;
      
      done              : out std_logic;
      
      adc1_data_o       : out std_logic_vector(63 downto 0);
      adc2_data0_o      : out std_logic_vector(31 downto 0);
      adc2_data1_o      : out std_logic_vector(31 downto 0);
      valid_o           : out std_logic
    );
end data_shift_module;

architecture Behavioral of data_shift_module is
    type state_machine              is (idle, valid_state, dly_st, pulse_st, pulse_st1, trig_st, trig_set_up_st, pulse_counter_st, ready_st, wait1_state, analyze_st);
    signal state, next_state        : state_machine;
    signal pulse_counter            : std_logic_vector(1 downto 0);
    signal trig_start               : std_logic;
    signal tick_counter             : std_logic_vector(2 downto 0);
--    signal level                    : std_logic_vector(7 downto 0);
    signal adc1_data_x2             : std_logic_vector(127 downto 0);
    signal adc2_data0_x2            : std_logic_vector(63 downto 0);
    signal adc2_data1_x2            : std_logic_vector(63 downto 0);
    signal data_x2_val              : std_logic;
    signal adc1_trig_vec_s          : std_logic_vector(7 downto 0);
    signal adc2_0_trig_vec_s        : std_logic_vector(3 downto 0);
    signal adc2_1_trig_vec_s        : std_logic_vector(3 downto 0);
    signal trig_up                  : std_logic;
    signal mode                     : std_logic_vector(1 downto 0);
    signal pulse                    : std_logic;
    signal adc1_trig_vec_not_val    : std_logic;
    signal adc2_0_trig_vec_not_val  : std_logic;
    signal adc2_1_trig_vec_not_val  : std_logic;
    

begin

trig_start <= tr_start1 and tr_start2_0 and tr_start2_1;

data_x2_proc :
  process(rst, clk)
  begin
    if (rst = '1') then
      adc1_data_x2  <= (others => '0');
      adc2_data0_x2 <= (others => '0');
      adc2_data1_x2 <= (others => '0');
      data_x2_val <= '0';
    elsif rising_edge(clk) then
      if (data_valid = '1') then
        adc1_data_x2(127 downto 64) <= adc1_data_x2(63 downto 0);
        adc1_data_x2(63 downto 0) <= adc1_data; 
        adc2_data0_x2(63 downto 32)<= adc2_data0_x2(31 downto 0);
        adc2_data0_x2(31 downto 0) <= adc2_data0;
        adc2_data1_x2(63 downto 32) <= adc2_data1_x2(31 downto 0);
        adc2_data1_x2(31 downto 0) <= adc2_data1;
        data_x2_val <= '1';
      else
        data_x2_val <= '0';
      end if;
    end if;
  end process;


pulse_counter_proc :
  process(state, clk)
  begin
    if (state = idle) then
      pulse_counter <= (others => '0');
    elsif rising_edge(clk) then
      if (state = pulse_st) then
        pulse_counter <= pulse_counter + 1;
      end if;
    end if;
  end process;

tick_counter_proc :
  process(state, clk)
  begin
    if (state /= trig_st) then
      tick_counter <= (others => '0');
    elsif rising_edge(clk) then
        tick_counter <= tick_counter + 1;
    end if;
  end process;

--capture_level_proc:
--  process(state, clk)
--  begin
--    if (state = idle) then
--      level <= x"FF";
--    else
--      if rising_edge(clk) then
--        if (tick_counter = "111") then
--          if level = 0 then
--            level <= x"FF";
--          else
--            level <= level - 1;
--          end if;
--        end if;
--      end if;
--    end if;
--  end process;

--
--level <= x"96";
mode <= "10";

trig_out_proc : 
process(clk)
begin
  if rising_edge(clk) then
    capture_mode <= mode;
    capture_level <= level;
    trigger_set_up <= trig_up;
    pulse_out <= pulse;
  end if;
end process;

sync_proc :
process(rst, clk)
begin 
  if (rst = '1') then
    state <= idle;
  elsif rising_edge(clk) then
    state <= next_state;
  end if;
end process;

next_state_process:
process(state, data_x2_val, trig_start, tick_counter, adc1_trig_vec_s, adc2_0_trig_vec_s, adc2_1_trig_vec_s)
begin
  next_state <= state;
    case (state) is
      when idle =>
        next_state <= valid_state;
      when valid_state => 
        if (data_x2_val = '1') then
          next_state <= trig_set_up_st;
        end if;
      when trig_set_up_st =>
         next_state <= dly_st;
      when dly_st =>
         next_state <= pulse_st;
      when pulse_st => 
        next_state <= pulse_st1;
      when pulse_st1 =>
        next_state <= trig_st;
      when trig_st =>
        if (trig_start = '1') then
          next_state <= ready_st;
        elsif (tick_counter = "111") then
          next_state <= trig_set_up_st;
        end if;
      when analyze_st =>
        if ((adc1_trig_vec_s /= "00001000") or (adc2_0_trig_vec_s /= "0001") or (adc2_1_trig_vec_s /= "0001")) then
          next_state <= idle;
        else
          next_state <= ready_st;
        end if;
      when ready_st =>
        
      when others => 
        next_state <= idle;
    end case;
end process;

out_process :
process(state)
begin
  pulse <= '0';
  done <= '0';
  trig_up <= '0';
  case state is
    when trig_set_up_st =>
      trig_up <= '1';
    when pulse_st =>
      pulse <= '0';
    when pulse_st1 =>
      pulse <= '1';
    when ready_st =>
      done <= '1';
    when others =>
  end case;
end process;

process(rst, clk)
begin
  if (rst = '1') then
    adc1_trig_vec_s   <= (others => '0');
    adc2_0_trig_vec_s <= (others => '0');
    adc2_1_trig_vec_s <= (others => '0');
  elsif rising_edge(clk) then
    if (state = trig_st) then
      if (trig_start = '1') then
        adc1_trig_vec_s <= adc1_trig_vec;
        adc2_0_trig_vec_s <= adc2_0_trig_vec;
        adc2_1_trig_vec_s <= adc2_1_trig_vec;
      end if;
    end if;
  end if;
end process;

data_out_process :
  process(state, clk)
  begin
    if (state /= ready_st) then
      valid_o <= '0';
      adc1_data_o <= adc1_data;
      adc2_data0_o <= adc2_data0;
      adc2_data1_o <= adc2_data1;
    --  adc1_trig_vec_not_val   <= '0';
    --  adc2_0_trig_vec_not_val <= '0';
    --  adc2_1_trig_vec_not_val <= '0';
    else
      if rising_edge(clk) then
        if (data_x2_val = '1') then
          valid_o <= '1';
          case adc1_trig_vec_s is
            when "00000001" =>
              adc1_data_o <= adc1_data; 
            when "00000010" =>
              adc1_data_o <= adc1_data; 
            when "00000100" =>
              adc1_data_o <= adc1_data; 
            when "00001000" =>
              adc1_data_o <= adc1_data; 
            when "00010000" =>
              adc1_data_o <= adc1_data; 
            when "00100000" =>
              adc1_data_o <= adc1_data; 
            when "01000000" =>
              adc1_data_o <= adc1_data; 
            when "10000000" =>
              adc1_data_o <= adc1_data; 
            when others =>
              adc1_data_o <= (others => '1');
          end case;
          
          case adc2_0_trig_vec_s is
            when "0001" =>
              adc2_data0_o <= adc2_data0; 
            when "0010" =>
              adc2_data0_o <= adc2_data0; 
            when "0100" =>
              adc2_data0_o <= adc2_data0; 
            when "1000" =>
              adc2_data0_o <= adc2_data0; 
            when others =>
              adc2_data0_o <= (others => '1');
          end case;
          
          case adc2_1_trig_vec_s is
            when "0001" =>
              adc2_data1_o <= adc2_data1; 
            when "0010" =>
              adc2_data1_o <= adc2_data1; 
            when "0100" =>
              adc2_data1_o <= adc2_data1; 
            when "1000" =>
              adc2_data1_o <= adc2_data1; 
            when others =>
              adc2_data1_o <= (others => '1');
          end case;
          
          --case adc1_trig_vec_s is
          -- -- when "00000001" =>
          -- --   adc1_data_o <= adc1_data_x2(63 downto 0); 
          -- -- when "00000010" =>
          -- --   adc1_data_o <= adc1_data_x2(71 downto 8); 
          -- -- when "00000100" =>
          -- --   adc1_data_o <= adc1_data_x2(79 downto 16); 
          --  when "00001000" =>
          --    adc1_data_o <= adc1_data_x2(87 downto 24); 
          -- -- when "00010000" =>
          -- --   adc1_data_o <= adc1_data_x2(95 downto 32); 
          -- -- when "00100000" =>
          -- --   adc1_data_o <= adc1_data_x2(103 downto 40); 
          -- -- when "01000000" =>
          -- --   adc1_data_o <= adc1_data_x2(111 downto 48); 
          -- -- when "10000000" =>
          -- --   adc1_data_o <= adc1_data_x2(119 downto 56); 
          --  when others =>
          --    adc1_data_o <= (others => '1');
      --  --      adc1_trig_vec_not_val <= '1';
          --end case;
          --
          --case adc2_0_trig_vec_s is
          --  when "0001" =>
          --    adc2_data0_o <= adc2_data0_x2(31 downto 0); 
          -- -- when "0010" =>
          -- --   adc2_data0_o <= adc2_data0_x2(39 downto 8); 
          -- -- when "0100" =>
          -- --   adc2_data0_o <= adc2_data0_x2(47 downto 16); 
          -- -- when "1000" =>
          -- --   adc2_data0_o <= adc2_data0_x2(55 downto 24); 
          --  when others =>
          --    adc2_data0_o <= (others => '1');
        ----      adc2_0_trig_vec_not_val <= '1';
          --end case;
          --
          --case adc2_1_trig_vec_s is
          --  when "0001" =>
          --    adc2_data1_o <= adc2_data1_x2(31 downto 0); 
          --  --when "0010" =>
          --  --  adc2_data1_o <= adc2_data1_x2(39 downto 8); 
          --  --when "0100" =>
          --  --  adc2_data1_o <= adc2_data1_x2(47 downto 16); 
          --  --when "1000" =>
          --  --  adc2_data1_o <= adc2_data1_x2(55 downto 24); 
          --  when others =>
          --    adc2_data1_o <= (others => '1');
        ----     adc2_1_trig_vec_not_val <= '1';
          --end case;
        else
          valid_o <= '0';
        end if;
      end if;
    end if;
  end process;


end Behavioral;
