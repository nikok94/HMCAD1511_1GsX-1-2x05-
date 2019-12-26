----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 21.11.2019 10:38:05
-- Design Name: 
-- Module Name: HMCAD1511_v3_00 - Behavioral
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
use work.frame_deserializer;
use work.high_speed_clock_to_serdes;


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity HMCAD1511_v3_00 is
    generic (
      DIFF_TERM         : boolean := true
    );
    Port (
      --LCLKp                 : in std_logic;
      --LCLKn                 : in std_logic;
      
      gclk                  : in std_logic;
      serdesclk0            : in std_logic;
      serdesclk1            : in std_logic;
      serdesstrobe          : in std_logic;

      FCLKp                 : in std_logic;
      FCLKn                 : in std_logic;

      DxXAp                 : in std_logic_vector(3 downto 0);
      DxXAn                 : in std_logic_vector(3 downto 0);
      DxXBp                 : in std_logic_vector(3 downto 0);
      DxXBn                 : in std_logic_vector(3 downto 0);
      
      reset                 : in std_logic;
      m_strm_valid          : out std_logic;
      m_strm_data           : out std_logic_vector(63 downto 0);

      bsleep_counter        : out std_logic_vector(3 downto 0);
      
      frame                 : out std_logic_vector(7 downto 0);
--      fclk_div              : out std_logic;
--      lclk_obuf             : out std_logic;
      fclk_obuf             : out std_logic
    );
end HMCAD1511_v3_00;

architecture Behavioral of HMCAD1511_v3_00 is
    constant frame_pattern  : std_logic_vector(7 downto 0):= x"0f";
    --signal gclk             : std_logic;
    --signal serdesclk0       : std_logic;
    --signal serdesclk1       : std_logic;
    --signal serdesstrobe     : std_logic;
    signal valid_fr         : std_logic;
    signal valida           : std_logic_vector(3 downto 0);
    signal validb           : std_logic_vector(3 downto 0);
    type data_outs          is array (3 downto 0) of std_logic_vector(7 downto 0);
    signal da, db           : data_outs;
    signal counter          : std_logic_vector(4 downto 0);
    signal frame_data       : std_logic_vector(7 downto 0);
    signal bitslip          : std_logic;
    type state_machine is (idle, frame_st, bitslip_st, counter_st, ready_st, rst_st, rst_cont_st, save_frame);
    signal state, next_state : state_machine;
    signal valid            : std_logic;
    signal rst              : std_logic;
    signal rst_counter      : std_logic_vector(3 downto 0);
    signal bitsleep_counter : std_logic_vector(3 downto 0);
    signal lclk             : std_logic;
    signal frame_obuf       : std_logic;
    signal fclk_div_bufio   : std_logic;
    signal bufh_o           : std_logic;


begin

bsleep_counter <= bitsleep_counter;

--IBUFGDS1_inst : IBUFGDS
--   generic map (
--      IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
--      IOSTANDARD => "DEFAULT")
--   port map (
--      O => lclk,     -- Clock buffer output
--      I => LCLKp,         -- Diff_p clock buffer input
--      IB => LCLKn         -- Diff_n clock buffer input
--   );


save_frame_process :
process(state, gclk)
begin
  if (state = idle) then
    frame <= (others => '0');
  elsif rising_edge(gclk) then
    if (state = save_frame) then
      frame <= frame_data;
    end if;
  end if;
end process;

counter_proc :
process(gclk)
begin
  if rising_edge(gclk) then
    if (state = counter_st) then
      counter <= counter + 1;
    else
      counter <= (others => '0');
    end if;
  end if;
end process;

bitsleep_counter_proc :
process(state, gclk)
begin
  if (state = idle) then
    bitsleep_counter <= (others => '0');
  elsif rising_edge(gclk) then
    if (bitslip = '1') then
      bitsleep_counter <= bitsleep_counter + 1;
    end if;
  end if;
end process;

sync_proc :
process(reset, gclk)
begin
  if (reset = '1') then
    state <= idle;
  elsif rising_edge(gclk) then
    state <= next_state;
  end if;
end process;

next_state_proc :
process(state, valid_fr, counter(counter'length - 1), frame_data, validb, valida, rst_counter(rst_counter'length - 1))
begin
  next_state <= state;
    case state is
      when idle =>
        next_state <= rst_st;
      when save_frame =>
          next_state <= frame_st;
      when frame_st =>
        if (valid_fr = '1') then
          if (frame_data = frame_pattern) then
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
        if (frame_data /= frame_pattern) then
          next_state <= idle;
        end if;
      when rst_st =>
        if rst_counter(rst_counter'length - 1) = '1' then
          next_state <= rst_cont_st;
        end if;
      when rst_cont_st =>
        if (valid_fr = '1') and (validb = "1111") and (valida = "1111") then
          next_state <= save_frame;
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
process(gclk, state)
begin
  if (state /= rst_st) then
    rst_counter     <= (others => '0');
  else
    if rising_edge(gclk) then
      rst_counter <= rst_counter + 1;
    end if;
  end if;
end process;


trigger_proc :
process(gclk, reset)
begin
  if (reset = '1') then
    m_strm_valid    <= '0';
    m_strm_data     <= (others => '0');
  else
    if rising_edge(gclk) then
      m_strm_valid  <= valid;
      m_strm_data   <= da(0) & db(0) & da(1) & db(1) & da(2) & db(2) & da(3) & db(3);
    end if;
  end if;
end process;

--hscs : entity high_speed_clock_to_serdes
--    Generic map (
--      S                   => 8
--      )
--    Port map(
----      clkin_p             => LCLKp,
----      clkin_n             => LCLKn,
--      clkin_ibufg         => LCLK,
--      gclk                => gclk,
--      serdesclk0          => serdesclk0,
--      serdesclk1          => serdesclk1,
--      serdesstrobe        => serdesstrobe
--    );

frame_deser : entity data_deserializer 
    generic map (
      DIFF_TERM         => DIFF_TERM
    )
    Port map(
      serdes_clk0       => serdesclk0,
      serdes_clk1       => serdesclk1,
      serdes_divclk     => gclk,
      serdes_strobe     => serdesstrobe,
      data_p            => FCLKp,
      data_n            => FCLKn,
      calib_valid       => valid_fr,
      reset             => rst,
      result            => frame_data,
      bitslip           => bitslip,
      data_obuf         => frame_obuf
    );

--BUFIO2_clk0_inst : BUFIO2
--   generic map (
--      DIVIDE => 8,           -- DIVCLK divider (1,3-8)
--      DIVIDE_BYPASS => FALSE, -- Bypass the divider circuitry (TRUE/FALSE)
--      I_INVERT => FALSE,     -- Invert clock (TRUE/FALSE)
--      USE_DOUBLER => false   -- Use doubler circuitry (TRUE/FALSE)
--   )
--   port map (
--      DIVCLK => fclk_div_bufio,             -- 1-bit output: Divided clock output
--      IOCLK => open,               -- 1-bit output: I/O output clock
--      SERDESSTROBE => open, -- 1-bit output: Output SERDES strobe (connect to ISERDES2/OSERDES2)
--      I => frame_obuf                        -- 1-bit input: Clock input (connect to IBUFG)
--   );
--
----fclk_div <= fclk_div_bufio;
--
--FCLK_BUFG_INST : BUFG port map (i => frame_obuf, o => fclk_obuf);

fclk_obuf <= frame_obuf;

generate_proc : for i in 0 to 3 generate
da_deser : entity data_deserializer 
    generic map (
      DIFF_TERM         => DIFF_TERM
    )
    Port map(
      serdes_clk0       => serdesclk0,
      serdes_clk1       => serdesclk1,
      serdes_divclk     => gclk,
      serdes_strobe     => serdesstrobe,
      data_p            => DxXAp(i),
      data_n            => DxXAn(i),
      calib_valid       => valida(i),
      reset             => rst,
      result            => da(i),
      bitslip           => bitslip,
      data_obuf         => open
    );

db_deser : entity data_deserializer 
    generic map (
      DIFF_TERM         => DIFF_TERM
    )
    Port map(
      serdes_clk0       => serdesclk0,
      serdes_clk1       => serdesclk1,
      serdes_divclk     => gclk,
      serdes_strobe     => serdesstrobe,
      data_p            => DxXBp(i),
      data_n            => DxXBn(i),
      calib_valid       => validb(i),
      reset             => rst,
      result            => db(i),
      bitslip           => bitslip,
      data_obuf         => open
    );

end generate;


end Behavioral;
