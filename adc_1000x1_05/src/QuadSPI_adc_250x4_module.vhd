----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 22.04.2019 10:22:02
-- Design Name: 
-- Module Name: QuadSPI_adc_250x4_module - Behavioral
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
use work.fifo_64_8;
--use work.fifo_16_8;
--use work.icon;
--use work.ila;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity QuadSPI_adc_250x4_module is
    generic (
      C_CPHA            : integer := 0;
      C_CPOL            : integer := 0;
      C_LSB_FIRST       : integer := 0
      );
    Port (
      spifi_cs          : in std_logic;
      spifi_sck         : in std_logic;
      spifi_miso        : inout std_logic;
      spifi_mosi        : inout std_logic;
      spifi_sio2        : inout std_logic;
      spifi_sio3        : inout std_logic;
      
      clk               : in std_logic;
      rst               : in std_logic;

      adc1_s_strm_data  : in std_logic_vector(63 downto 0);
      adc1_s_strm_valid : in std_logic;
      adc1_s_strm_ready : out std_logic;
      adc1_valid        : out std_logic;
      
      adc1_proc_rst_out : out std_logic;
      
      adc2_s_strm_data  : in std_logic_vector(63 downto 0);
      adc2_s_strm_valid : in std_logic;
      adc2_s_strm_ready : out std_logic;
      adc2_valid        : out std_logic;
      
      adc2_proc_rst_out : out std_logic
      
    );
end QuadSPI_adc_250x4_module;

architecture Behavioral of QuadSPI_adc_250x4_module is
    type state_machine is (idle, rd_start_byte, nibble_1, nibble_2);
    signal state, next_state    : state_machine;
    signal command_bit_counter  : std_logic_vector(2 downto 0);
    signal command_byte         : std_logic_vector(7 downto 0):= (others => '0');
    signal spifi_tri_state      : std_logic:= '1';
    signal mosi_i               : std_logic;
    signal mosi_o               : std_logic;
    signal miso_i               : std_logic;
    signal miso_o               : std_logic;
    signal sio2_i               : std_logic;
    signal sio2_o               : std_logic;
    signal sio3_i               : std_logic;
    signal sio3_o               : std_logic;
    signal data_8byte           : std_logic_vector(63 downto 0);
    signal start                : std_logic;
    signal quad_tr_ready        : std_logic;
    signal quad_compleat        : std_logic;
    signal ready                : std_Logic;
    signal ila_control_0        : std_logic_vector(35 downto 0);
    signal ila_control_1        : std_logic_vector(35 downto 0);

    signal adc1_fifo_rst        : STD_LOGIC;
    signal adc1_fifo_rst_vect   : STD_LOGIC_VECTOR(7 downto 0);
    signal adc1_fifo_wr_en      : STD_LOGIC;
    signal adc1_fifo_rd_en      : STD_LOGIC;
    signal adc1_fifo_dout       : STD_LOGIC_VECTOR(7 DOWNTO 0);
    signal adc1_fifo_full       : STD_LOGIC;
    signal adc1_fifo_empty      : STD_LOGIC;
    signal adc1_fifo_valid      : STD_LOGIC;
    
    signal adc2_fifo_rst        : STD_LOGIC;
    signal adc2_fifo_rst_vect   : STD_LOGIC_VECTOR(7 DOWNTO 0);
    signal adc2_fifo_wr_en      : STD_LOGIC;
    signal adc2_fifo_rd_en      : STD_LOGIC;
    signal adc2_fifo_dout       : STD_LOGIC_VECTOR(7 DOWNTO 0);
    signal adc2_fifo_full       : STD_LOGIC;
    signal adc2_fifo_empty      : STD_LOGIC;
    signal adc2_fifo_valid      : STD_LOGIC;
    
    signal spifi_sck_d          : std_logic;
    signal spifi_sck_d_1        : std_logic;
    signal spifi_cs_d           : std_logic;
    signal spifi_cs_d1          : std_logic;
    signal spifi_cs_d2          : std_logic;
    signal spifi_cs_down        : std_logic;
    signal spifi_cs_up          : std_logic;
    signal spifi_sck_edge       : std_Logic;
    signal spifi_sck_fall       : std_logic;
    signal nibble               : std_logic_vector(3 downto 0);
    signal next_byte            : std_logic;
    signal next_byte_d1         : std_logic;
    signal next_byte_d2         : std_logic;
    signal next_byte_d3         : std_logic;
    signal second_activ         : std_logic;
    
begin

MOSI_IOBUF_inst : IOBUF
   generic map (
      DRIVE => 12,
      IOSTANDARD => "DEFAULT",
      SLEW => "SLOW")
   port map (
      O => mosi_i,     -- Buffer output
      IO => spifi_mosi,   -- Buffer inout port (connect directly to top-level port)
      I => mosi_o,     -- Buffer input
      T => spifi_tri_state      -- 3-state enable input, high=input, low=output 
   );

MISO_IOBUF_inst : IOBUF
   generic map (
      DRIVE => 12,
      IOSTANDARD => "DEFAULT",
      SLEW => "SLOW")
   port map (
      O => miso_i,     -- Buffer output
      IO => spifi_miso,   -- Buffer inout port (connect directly to top-level port)
      I => miso_o,     -- Buffer input
      T => spifi_tri_state      -- 3-state enable input, high=input, low=output 
   );

SIO2_IOBUF_inst : IOBUF
   generic map (
      DRIVE => 12,
      IOSTANDARD => "DEFAULT",
      SLEW => "SLOW")
   port map (
      O => sio2_i,     -- Buffer output
      IO => spifi_sio2,   -- Buffer inout port (connect directly to top-level port)
      I => sio2_o,     -- Buffer input
      T => spifi_tri_state      -- 3-state enable input, high=input, low=output 
   );

SIO3_IOBUF_inst : IOBUF
   generic map (
      DRIVE => 12,
      IOSTANDARD => "DEFAULT",
      SLEW => "SLOW")
   port map (
      O => sio3_i,     -- Buffer output
      IO => spifi_sio3,   -- Buffer inout port (connect directly to top-level port)
      I => sio3_o,     -- Buffer input
      T => spifi_tri_state      -- 3-state enable input, high=input, low=output 
   );

delay_process:
    process(clk)
    begin
      if rising_edge(clk) then
        spifi_cs_d  <= spifi_cs;
        spifi_cs_d1 <= spifi_cs_d;
        spifi_cs_d2 <= spifi_cs_d1;
      end if;
    end process;
spifi_cs_up     <= (not spifi_cs_d2) and spifi_cs_d1;

command_byte_proc:
  process(spifi_sck, spifi_cs)
  begin
    if (spifi_cs = '1') then
      command_bit_counter <= (others => '0');
    elsif rising_edge(spifi_sck) then
      if (state = rd_start_byte) then
        command_bit_counter <= command_bit_counter + 1;
        command_byte(7 downto 1) <= command_byte(6 downto 0);
        command_byte(0) <= mosi_i;
      end if;
    end if;
  end process;

second_activ <= command_byte(0);

sck_delay_process:
    process(clk)
    begin
      if rising_edge(clk) then
        next_byte_d1 <= next_byte;
        next_byte_d2 <= next_byte_d1;
        next_byte_d3 <= next_byte_d2;
      end if;
    end process;

process(spifi_sck)
begin
  if rising_edge(spifi_sck) then
    if (next_state = nibble_2) then 
      next_byte <= '1';
    else
      next_byte <= '0';
    end if;
  end if;
end process;


adc1_fifo_inst : ENTITY fifo_64_8
  PORT MAP(
    rst     => adc1_fifo_rst,
    wr_clk  => clk,
    rd_clk  => clk,
    din     => adc1_s_strm_data(7 downto 0) & adc1_s_strm_data(15 downto 8) & adc1_s_strm_data(23 downto 16) & adc1_s_strm_data(31 downto 24) & adc1_s_strm_data(39 downto 32) & adc1_s_strm_data(47 downto 40) & adc1_s_strm_data(55 downto 48) & adc1_s_strm_data(63 downto 56),
    wr_en   => adc1_fifo_wr_en,
    rd_en   => adc1_fifo_rd_en,
    dout    => adc1_fifo_dout ,
    full    => adc1_fifo_full ,
    empty   => adc1_fifo_empty,
    valid   => adc1_fifo_valid
  );

adc1_fifo_rd_en <= (not next_byte_d3) and next_byte_d2 and (not second_activ);
adc1_valid <= adc1_fifo_valid;
adc1_fifo_wr_en <= adc1_s_strm_valid and (not adc1_fifo_full);
adc1_s_strm_ready <= not adc1_fifo_full;

adc1_fifo_rst_proc :
  process(clk, rst) 
  begin
    if rst = '1' then
      adc1_fifo_rst_vect <= (others => '1');
    elsif rising_edge(clk) then
      if ((spifi_cs_up = '1') and (second_activ = '0')) then
        adc1_fifo_rst_vect <= (others => '1');
      else
        adc1_fifo_rst_vect(7 downto 1) <= adc1_fifo_rst_vect(6 downto 0);
        adc1_fifo_rst_vect(0) <= '0';
      end if;
    end if;
  end process;

adc1_fifo_rst <= adc1_fifo_rst_vect(7);
adc1_proc_rst_out <= adc1_fifo_rst_vect(7);

adc2_fifo_inst : ENTITY fifo_64_8
  PORT MAP(
    rst     => adc2_fifo_rst,
    wr_clk  => clk,
    rd_clk  => clk,
    din     => adc2_s_strm_data(7 downto 0) & adc2_s_strm_data(15 downto 8) & adc2_s_strm_data(23 downto 16) & adc2_s_strm_data(31 downto 24) & adc2_s_strm_data(39 downto 32) & adc2_s_strm_data(47 downto 40) & adc2_s_strm_data(55 downto 48) & adc2_s_strm_data(63 downto 56),
    wr_en   => adc2_fifo_wr_en,
    rd_en   => adc2_fifo_rd_en,
    dout    => adc2_fifo_dout ,
    full    => adc2_fifo_full ,
    empty   => adc2_fifo_empty,
    valid   => adc2_fifo_valid
  );

adc2_fifo_rd_en <= (not next_byte_d3) and next_byte_d2 and second_activ;
adc2_valid <= adc2_fifo_valid;
adc2_fifo_wr_en <= adc2_s_strm_valid and (not adc2_fifo_full);
adc2_s_strm_ready <= not adc2_fifo_full;

adc2_fifo_rst_proc :
  process(clk, rst) 
  begin
    if rst = '1' then
      adc2_fifo_rst_vect <= (others => '1');
    elsif rising_edge(clk) then
      if ((spifi_cs_up = '1') and (second_activ = '1')) then
        adc2_fifo_rst_vect <= (others => '1');
      else
        adc2_fifo_rst_vect(7 downto 1) <= adc2_fifo_rst_vect(6 downto 0);
        adc2_fifo_rst_vect(0) <= '0';
      end if;
    end if;
  end process;

adc2_fifo_rst <= adc2_fifo_rst_vect(7);
adc2_proc_rst_out <= adc2_fifo_rst_vect(7);
 

nibble <= adc1_fifo_dout(3 downto 0) when (next_state = nibble_1) and (second_activ = '0') else 
          adc1_fifo_dout(7 downto 4) when (next_state = nibble_2) and (second_activ = '0') else
          adc2_fifo_dout(3 downto 0) when (next_state = nibble_1) and (second_activ = '1') else 
          adc2_fifo_dout(7 downto 4) when (next_state = nibble_2) and (second_activ = '1') else
          (others => '0');

  mosi_o <= nibble(0);
  miso_o <= nibble(1);
  sio2_o <= nibble(2);
  sio3_o <= nibble(3);

state_sync_proc :
  process(spifi_sck, spifi_cs) 
  begin
    if (spifi_cs = '1') then
      state <= idle;
    elsif rising_edge(spifi_sck) then
      state <= next_state;
    end if;
  end process;

next_state_proc:
  process(state, command_bit_counter) 
  begin
    spifi_tri_state <= '1';
    next_state <= state;
      case state is
      when idle =>
        next_state <= rd_start_byte;
      when rd_start_byte =>
        if (command_bit_counter  = b"111") then
          next_state <= nibble_1;
        end if;
      when nibble_1 =>
          spifi_tri_state <= '0';
          next_state <= nibble_2;
      when nibble_2 =>
          spifi_tri_state <= '0';
          next_state <= nibble_1;
      when others =>
         next_state <= idle;
      end case;
  end process;

--ila_1 : entity ila
--  port map (
--    CONTROL     => ila_control_0,
--    CLK         => clk,
--    DATA        => adc1_fifo_dout & adc1_fifo_rd_en,
--    TRIG0(0)    => adc1_fifo_rd_en
--    );
--
--ila_2 : entity ila
--  port map (
--    CONTROL     => ila_control_1,
--    CLK         => clk,
--    DATA        => adc2_fifo_dout & adc2_fifo_rd_en,
--    TRIG0(0)    => adc2_fifo_rd_en
--    );
--
--icon_inst : ENTITY icon
--  port map (
--    CONTROL0 => ila_control_0,
--    CONTROL1 => ila_control_1
--    );

end Behavioral;
