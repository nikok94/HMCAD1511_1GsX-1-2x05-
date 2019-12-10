----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.11.2019 10:38:05
-- Design Name: 
-- Module Name: HMCAD1511_x2_v1_00 - Behavioral
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
use work.data_deserializer;
use work.high_speed_clock_to_serdes;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity HMCAD1511_x2_v1_00 is
    generic (
      DIFF_TERM         : boolean := true
    );
    Port (
      LCLKp_1               : in std_logic;
      LCLKn_1               : in std_logic;

      FCLKp_1               : in std_logic;
      FCLKn_1               : in std_logic;

      DxXAp_1               : in std_logic_vector(3 downto 0);
      DxXAn_1               : in std_logic_vector(3 downto 0);
      DxXBp_1               : in std_logic_vector(3 downto 0);
      DxXBn_1               : in std_logic_vector(3 downto 0);

      LCLKp_2               : in std_logic;
      LCLKn_2               : in std_logic;

      FCLKp_2               : in std_logic;
      FCLKn_2               : in std_logic;

      DxXAp_2               : in std_logic_vector(3 downto 0);
      DxXAn_2               : in std_logic_vector(3 downto 0);
      DxXBp_2               : in std_logic_vector(3 downto 0);
      DxXBn_2               : in std_logic_vector(3 downto 0);

      reset                 : in std_logic;
      m1_clk_o              : out std_logic;
      m1_strm_valid         : out std_logic;
      m1_strm_data          : out std_logic_vector(63 downto 0);
      
      m2_clk_o              : out std_logic;
      m2_strm_valid         : out std_logic;
      m2_strm_data          : out std_logic_vector(63 downto 0);
      
      frame_patter1         : out std_logic_vector(7 downto 0);
      frame_patter2         : out std_logic_vector(7 downto 0)
      
    );
end HMCAD1511_x2_v1_00;

architecture Behavioral of HMCAD1511_x2_v1_00 is
    constant frame_pattern  : std_logic_vector(7 downto 0):= x"0f";

    signal gclk_1             : std_logic;
    signal serdesclk0_1       : std_logic;
    signal serdesclk1_1       : std_logic;
    signal serdesstrobe_1     : std_logic;

    signal gclk_2             : std_logic;
    signal serdesclk0_2       : std_logic;
    signal serdesclk1_2       : std_logic;
    signal serdesstrobe_2     : std_logic;
    signal data1_x2           : std_logic_vector(64 * 2 - 1 downto 0);
    signal data2_x2           : std_logic_vector(64 * 2 - 1 downto 0);

    signal valid_fr           : std_logic;
    signal valida1            : std_logic_vector(3 downto 0);
    signal validb1            : std_logic_vector(3 downto 0);
    signal valida2            : std_logic_vector(3 downto 0);
    signal validb2            : std_logic_vector(3 downto 0);
    type data_outs            is array (3 downto 0) of std_logic_vector(7 downto 0);
    signal da1, db1           : data_outs;
    signal da2, db2           : data_outs;
    type data_x2_outs         is array (3 downto 0) of std_logic_vector(15 downto 0);
    signal da2_d, db2_d       : data_x2_outs;
    signal counter            : std_logic_vector(4 downto 0);
    signal frame_data_1       : std_logic_vector(7 downto 0);
    signal frame_data_1_d     : std_logic_vector(7 downto 0);
    signal frame_data_2       : std_logic_vector(7 downto 0);
    signal frame_data_2_d     : std_logic_vector(7 downto 0);
    signal frame1_fall        : std_logic;
    signal frame2_fall        : std_logic;
    signal bitslip            : std_logic;
    type state_machine        is (idle, frame_st, bitslip_st, counter_st, ready_st, rst_st, rst_cont_st);
    signal state, next_state  : state_machine;
    signal valid              : std_logic;
    signal rst                : std_logic;
    signal rst_counter        : std_logic_vector(3 downto 0);
    signal bitsleep_counter   : std_logic_vector(3 downto 0);
    signal lclk_1             : std_logic;
    signal lclk_2             : std_logic;

begin

IBUFGDS1_inst : IBUFGDS
   generic map (
      IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
      IOSTANDARD => "DEFAULT")
   port map (
      O => lclk_1,     -- Clock buffer output
      I => LCLKp_1,         -- Diff_p clock buffer input
      IB => LCLKn_1         -- Diff_n clock buffer input
   );

IBUFGDS2_inst : IBUFGDS
   generic map (
      IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
      IOSTANDARD => "DEFAULT")
   port map (
      O => lclk_2,     -- Clock buffer output
      I => LCLKp_2,         -- Diff_p clock buffer input
      IB => LCLKn_2         -- Diff_n clock buffer input
   );

counter_proc :
process(gclk_1)
begin
  if rising_edge(gclk_1) then
    if (state = counter_st) then
      counter <= counter + 1;
    else
      counter <= (others => '0');
    end if;
  end if;
end process;

bitsleep_counter_proc :
process(state, gclk_1)
begin
  if (state = idle) then
    bitsleep_counter <= (others => '0');
  elsif rising_edge(gclk_1) then
    if (bitslip = '1') then
      bitsleep_counter <= bitsleep_counter + 1;
    end if;
  end if;
end process;

sync_proc :
process(reset, gclk_1)
begin
  if (reset = '1') then
    state <= idle;
  elsif rising_edge(gclk_1) then
    state <= next_state;
  end if;
end process;

next_state_proc :
process(state, valid_fr, counter(counter'length - 1), frame_data_1, validb1, valida1, validb2, valida2, rst_counter(rst_counter'length - 1), frame2_fall)
begin
  next_state <= state;
    case state is
      when idle =>
        next_state <= rst_st;
      when frame_st =>
        if (valid_fr = '1') then
          if (frame_data_1 = frame_pattern) then
            next_state <= ready_st;
          else
            next_state <= bitslip_st;
          end if;
        end if;
      when bitslip_st =>
          next_state <= counter_st;
      when counter_st => 
        if (counter(counter'length - 1) = '1') then
          next_state <= frame_st;
        end if;
      when ready_st =>
        if (frame_data_1 /= frame_pattern or (frame2_fall = '1')) then
          next_state <= rst_st;
        end if;
      when rst_st =>
        if rst_counter(rst_counter'length - 1) = '1' then
          next_state <= rst_cont_st;
        end if;
      when rst_cont_st =>
        if (valid_fr = '1') and (validb1 = "1111") and (valida1 = "1111") and (validb2 = "1111") and (valida2 = "1111") then
          next_state <= frame_st;
        end if;
      when others =>
        next_state <= idle;
    end case;
end process;

out_proc :
process(state)
begin
  bitslip <= '0';
  valid <= '0';
  rst <= '0';
    case state is
      when idle => 
        rst <= '1';
      when bitslip_st =>
        bitslip <= '1';
      when ready_st =>
        valid <= '1';
      when rst_st =>
        rst <= '1';
      when others =>
    end case;
end process;

rst_counter_proc :
process(gclk_1, state)
begin
  if (state /= rst_st) then
    rst_counter     <= (others => '0');
  else
    if rising_edge(gclk_1) then
      rst_counter <= rst_counter + 1;
    end if;
  end if;
end process;


trigger_proc1 :
process(gclk_1, reset)
begin
  if (reset = '1') then
    m1_strm_valid    <= '0';
    m1_strm_data     <= (others => '0');
  else
    if rising_edge(gclk_1) then
      m1_strm_valid <= valid;
      data1_x2(64*2-1 downto 64) <= da1(0) & db1(0) & da1(1) & db1(1) & da1(2) & db1(2) & da1(3) & db1(3);
      data1_x2(63 downto 0) <= data1_x2(64*2-1 downto 64);
      m1_strm_data   <= data1_x2(63 downto 0);
    end if;
  end if;
end process;

gen_proc_adc2 : for k in 0 to 3 generate

trigger_proc2 :
process(gclk_2, reset)
begin
  if (reset = '1') then
    m2_strm_valid    <= '0';
  else
    if rising_edge(gclk_2) then
      m2_strm_valid  <= valid;
      da2_d(k)(15 downto 8) <= da2(k);
      da2_d(k)(7 downto 0) <= da2_d(k)(15 downto 8);
      db2_d(k)(15 downto 8) <= db2(k);
      db2_d(k)(7 downto 0) <= db2_d(k)(15 downto 8);
    end if;
  end if;
end process;
end generate;

process(gclk_2, reset)
begin
  if (reset = '1') then
    m2_strm_data     <= (others => '0');
  else
    if rising_edge(gclk_2) then
       case frame_data_2 is
        when "00011110" =>
          m2_strm_data(63 downto 32) <= da2_d(0)(7 + 1 downto 1) & da2_d(1)(7 + 1 downto 1) & da2_d(2)(7 + 1 downto 1) & da2_d(3)(7 + 1 downto 1);
          m2_strm_data(31 downto 0) <=  db2_d(0)(7 + 1 downto 1) & db2_d(1)(7 + 1 downto 1) & db2_d(2)(7 + 1 downto 1) & db2_d(3)(7 + 1 downto 1);
        when "00111100" =>
          m2_strm_data(63 downto 32) <= da2_d(0)(7 + 2 downto 2) & da2_d(1)(7 + 2 downto 2) & da2_d(2)(7 + 2 downto 2) & da2_d(3)(7 + 2 downto 2);
          m2_strm_data(31 downto 0)  <= db2_d(0)(7 + 2 downto 2) & db2_d(1)(7 + 2 downto 2) & db2_d(2)(7 + 2 downto 2) & db2_d(3)(7 + 2 downto 2);
        when "01111000" =>
          m2_strm_data(63 downto 32) <= da2_d(0)(7 + 3 downto 3) & da2_d(1)(7 + 3 downto 3) & da2_d(2)(7 + 3 downto 3) & da2_d(3)(7 + 3 downto 3);
          m2_strm_data(31 downto 0)  <= db2_d(0)(7 + 3 downto 3) & db2_d(1)(7 + 3 downto 3) & db2_d(2)(7 + 3 downto 3) & db2_d(3)(7 + 3 downto 3);
        when "11110000"=>
          m2_strm_data(63 downto 32) <= da2_d(0)(7 + 4 downto 4) & da2_d(1)(7 + 4 downto 4) & da2_d(2)(7 + 4 downto 4) & da2_d(3)(7 + 4 downto 4);
          m2_strm_data(31 downto 0)  <= db2_d(0)(7 + 4 downto 4) & db2_d(1)(7 + 4 downto 4) & db2_d(2)(7 + 4 downto 4) & db2_d(3)(7 + 4 downto 4);
        when "11100001" =>
          m2_strm_data(63 downto 32) <= da2_d(0)(7 + 5 downto 5) & da2_d(1)(7 + 5 downto 5) & da2_d(2)(7 + 5 downto 5) & da2_d(3)(7 + 5 downto 5);
          m2_strm_data(31 downto 0)  <= db2_d(0)(7 + 5 downto 5) & db2_d(1)(7 + 5 downto 5) & db2_d(2)(7 + 5 downto 5) & db2_d(3)(7 + 5 downto 5);
        when "11000011" =>
          m2_strm_data(63 downto 32) <= da2_d(0)(7 + 6 downto 6) & da2_d(1)(7 + 6 downto 6) & da2_d(2)(7 + 6 downto 6) & da2_d(3)(7 + 6 downto 6);
          m2_strm_data(31 downto 0)  <= db2_d(0)(7 + 6 downto 6) & db2_d(1)(7 + 6 downto 6) & db2_d(2)(7 + 6 downto 6) & db2_d(3)(7 + 6 downto 6);
        when "10000111" =>
          m2_strm_data(63 downto 32) <= da2_d(0)(7 + 7 downto 7) & da2_d(1)(7 + 7 downto 7) & da2_d(2)(7 + 7 downto 7) & da2_d(3)(7 + 7 downto 7);
          m2_strm_data(31 downto 0)  <= db2_d(0)(7 + 7 downto 7) & db2_d(1)(7 + 7 downto 7) & db2_d(2)(7 + 7 downto 7) & db2_d(3)(7 + 7 downto 7);
        when others => 
          m2_strm_data(63 downto 32) <= da2_d(0)(7 downto 0) & da2_d(1)(7 downto 0) & da2_d(2)(7 downto 0) & da2_d(3)(7 downto 0);
          m2_strm_data(31 downto 0)  <= db2_d(0)(7 downto 0) & db2_d(1)(7 downto 0) & db2_d(2)(7 downto 0) & db2_d(3)(7 downto 0);
      end case;
    end if;
  end if;
end process;


hscs1 : entity high_speed_clock_to_serdes
    Generic map (
      S                   => 8
      )
    Port map(
      clkin_ibufg         => lclk_1,
      gclk                => gclk_1,
      serdesclk0          => serdesclk0_1,
      serdesclk1          => serdesclk1_1,
      serdesstrobe        => serdesstrobe_1
    );

hscs2 : entity high_speed_clock_to_serdes
    Generic map (
      S                   => 8
      )
    Port map(
      clkin_ibufg         => lclk_2,
      gclk                => gclk_2,
      serdesclk0          => serdesclk0_2,
      serdesclk1          => serdesclk1_2,
      serdesstrobe        => serdesstrobe_2
    );

m1_clk_o <= gclk_1;
m2_clk_o <= gclk_2;

process(gclk_1)
begin 
  if rising_edge(gclk_1) then
    frame_data_1_d <= frame_data_1;
  end if;
end process;

frame1_fall <='1' when frame_data_1_d /= frame_data_1 else '0';

process(gclk_2)
begin 
  if rising_edge(gclk_2) then
    frame_data_2_d <= frame_data_2;
  end if;
end process;

frame2_fall <= '1' when frame_data_2_d /= frame_data_2 else '0';


frame_deser1 : entity data_deserializer 
    generic map (
      DIFF_TERM         => DIFF_TERM
    )
    Port map(
      serdes_clk0       => serdesclk0_1,
      serdes_clk1       => serdesclk1_1,
      serdes_divclk     => gclk_1,
      serdes_strobe     => serdesstrobe_1,
      data_p            => FCLKp_1,
      data_n            => FCLKn_1,
      calib_valid       => valid_fr,
      reset             => rst,
      result            => frame_data_1,
      bitslip           => bitslip,
      data_obuf         => open
    );

frame_deser2 : entity data_deserializer 
    generic map (
      DIFF_TERM         => DIFF_TERM
    )
    Port map(
      serdes_clk0       => serdesclk0_2,
      serdes_clk1       => serdesclk1_2,
      serdes_divclk     => gclk_2,
      serdes_strobe     => serdesstrobe_2,
      data_p            => FCLKp_2,
      data_n            => FCLKn_2,
      calib_valid       => open,
      reset             => rst,
      result            => frame_data_2,
      bitslip           => bitslip,
      data_obuf         => open
    );

frame_patter1 <= frame_data_1;
frame_patter2 <= frame_data_2;


generate_proc : for i in 0 to 3 generate
da_deser1 : entity data_deserializer 
    generic map (
      DIFF_TERM         => DIFF_TERM
    )
    Port map(
      serdes_clk0       => serdesclk0_1,
      serdes_clk1       => serdesclk1_1,
      serdes_divclk     => gclk_1,
      serdes_strobe     => serdesstrobe_1,
      data_p            => DxXAp_1(i),
      data_n            => DxXAn_1(i),
      calib_valid       => valida1(i),
      reset             => rst,
      result            => da1(i),
      bitslip           => bitslip,
      data_obuf         => open
    );

db_deser1 : entity data_deserializer 
    generic map (
      DIFF_TERM         => DIFF_TERM
    )
    Port map(
      serdes_clk0       => serdesclk0_1,
      serdes_clk1       => serdesclk1_1,
      serdes_divclk     => gclk_1,
      serdes_strobe     => serdesstrobe_1,
      data_p            => DxXBp_1(i),
      data_n            => DxXBn_1(i),
      calib_valid       => validb1(i),
      reset             => rst,
      result            => db1(i),
      bitslip           => bitslip,
      data_obuf         => open
    );

da_deser2 : entity data_deserializer 
    generic map (
      DIFF_TERM         => DIFF_TERM
    )
    Port map(
      serdes_clk0       => serdesclk0_2,
      serdes_clk1       => serdesclk1_2,
      serdes_divclk     => gclk_2,
      serdes_strobe     => serdesstrobe_2,
      data_p            => DxXAp_2(i),
      data_n            => DxXAn_2(i),
      calib_valid       => valida2(i),
      reset             => rst,
      result            => da2(i),
      bitslip           => bitslip,
      data_obuf         => open
    );

db_deser2 : entity data_deserializer 
    generic map (
      DIFF_TERM         => DIFF_TERM
    )
    Port map(
      serdes_clk0       => serdesclk0_2,
      serdes_clk1       => serdesclk1_2,
      serdes_divclk     => gclk_2,
      serdes_strobe     => serdesstrobe_2,
      data_p            => DxXBp_2(i),
      data_n            => DxXBn_2(i),
      calib_valid       => validb2(i),
      reset             => rst,
      result            => db2(i),
      bitslip           => bitslip,
      data_obuf         => open
    );

end generate;


end Behavioral;
