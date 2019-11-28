----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 17.04.2019 12:42:56
-- Design Name: 
-- Module Name: spi_byte_transceiver - Behavioral
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
library UNISIM;
use UNISIM.VComponents.all;

entity spi_byte_transceiver is
    Generic(
      C_CPHA        : integer := 0;
      C_CPOL        : integer := 0;
      C_LSB_FIRST   : integer := 0
    );
    Port (
      SCK           : in std_logic;
      CS            : in std_logic;
      MISO          : out std_logic;

      clk           : in std_logic;
      rst           : in std_logic;
      byte          : in std_logic_vector(7 downto 0);
      start         : in std_logic;
      ready         : out std_logic;
      error         : out std_logic
    );
end spi_byte_transceiver;

architecture Behavioral of spi_byte_transceiver is
    signal start_edge                   : std_logic;
    signal start_d                      : std_logic;
    signal busy                         : std_logic;
    signal rdy                          : std_logic;
    signal spi_cmlt_sync_vect           : std_logic_vector(2 downto 0);
    signal spi_cmlt_sync                : std_logic;
    signal tri_state                    : std_logic;
    signal miso_o                       : std_logic;
    signal cs_d                         : std_logic;
    signal last_bit                     : std_logic;
    signal spi_bit_shift_counter        : std_logic_vector(3 downto 0):= (others => '0');
    signal spi_byte_shift_reg           : std_logic_vector(8 downto 0):= (others => '0');
    signal byte_0                       : std_logic;

begin

ready <= spi_cmlt_sync;
MISO <= miso_o;

start_edge_proc:
    process(clk)
    begin
      if rising_edge(clk) then
        if (rst = '1') then
          start_d <= '0';
        else 
          start_d <= start;
        end if;
      end if;
    end process;

start_edge <= (not start_d) and start;

error_proc:
    process(clk, CS, rst)
    begin
      if rising_edge(clk) then
        if (rst = '1') or (start_edge = '1') then
          error <= '0';
        elsif (rdy = '0') and busy = '1' then
          error <= '1';
        end if;
      end if;
    end process;

busy_proc:
    process(clk, CS, rst)
    begin
      if rising_edge(clk) then
        if (rst = '1') then
          busy <= '0';
        elsif (start_edge = '1') then
          busy <= '1';
        elsif spi_cmlt_sync = '1'then
          busy <= '0';
        end if;
      end if;
    end process;

spi_cmlt_sync_vect_proc :
    process(clk)
    begin
      if rising_edge(clk) then
        if (rst = '1') then
          spi_cmlt_sync_vect <= (others => '0');
        else
          spi_cmlt_sync_vect(0) <= last_bit;
          spi_cmlt_sync_vect(2 downto 1) <= spi_cmlt_sync_vect(1 downto 0);
        end if;
      end if;
    end process;

spi_cmlt_sync <= (not spi_cmlt_sync_vect(2)) and spi_cmlt_sync_vect(1);

sck_rising_lsb_first_generate_0 : if ((C_CPOL = 0 and C_CPHA = 0) and (C_LSB_FIRST = 1)) generate
sck_rising_edge_process :
    process(SCK, CS, rst, start_edge)
    begin
      if (CS = '1') or (rst = '1') then
        spi_bit_shift_counter <= (others => '0');
        spi_byte_shift_reg <= (others => '0');
      elsif (start_edge = '1') then
        spi_byte_shift_reg(7 downto 0) <= byte;
      elsif falling_edge(SCK) then
        if spi_bit_shift_counter = "1000" then
          spi_bit_shift_counter <= ( 0 => '1', others => '0');
        else
        spi_bit_shift_counter <= spi_bit_shift_counter + 1;
        end if;
        spi_byte_shift_reg(6 downto 0) <= spi_byte_shift_reg(7 downto 1);
      end if;
    end process;
    miso_o <= spi_byte_shift_reg(0);
end generate sck_rising_lsb_first_generate_0;

sck_rising_not_lsb_first_generate_0 : if ((C_CPOL = 0 and C_CPHA = 0) and (C_LSB_FIRST = 0)) generate
sck_rising_edge_process :
    process(SCK, CS, rst, start_edge)
    begin
      if (CS = '1') or (rst = '1') then
        spi_bit_shift_counter <= (others => '0');
        spi_byte_shift_reg <= (others => '0');
      elsif (start_edge = '1') then
        spi_byte_shift_reg(7 downto 0) <= byte;
      elsif falling_edge(SCK) then
        if spi_bit_shift_counter = "1000" then
          spi_bit_shift_counter <= ( 0 => '1', others => '0');
        else
        spi_bit_shift_counter <= spi_bit_shift_counter + 1;
        end if;
        spi_byte_shift_reg(7 downto 1) <= spi_byte_shift_reg(6 downto 0);
      end if;
    end process;
    miso_o <= spi_byte_shift_reg(7);
end generate sck_rising_not_lsb_first_generate_0;

sck_rising_lsb_first_generate : if ((C_CPOL = 1 and C_CPHA = 1) and (C_LSB_FIRST = 1)) generate
sck_rising_edge_process :
    process(SCK, CS, rst, start_edge)
    begin
      if (start_edge = '1') then
        if SCK = '1' then
          spi_byte_shift_reg <= byte & byte(0);
        else 
          spi_byte_shift_reg <= byte(7) & byte ;
        end if;
        spi_bit_shift_counter <= (others => '0');
      elsif falling_edge(SCK) then
        if spi_bit_shift_counter = "1000" then
          spi_bit_shift_counter <= ( 0 => '1', others => '0');
        else
        spi_bit_shift_counter <= spi_bit_shift_counter + 1;
        end if;
        spi_byte_shift_reg(7 downto 0) <= spi_byte_shift_reg(8 downto 1);
      end if;
    end process;
    miso_o <= spi_byte_shift_reg(0);
end generate sck_rising_lsb_first_generate;

sck_rising_not_lsb_first_generate : if ((C_CPOL = 1 and C_CPHA = 1) and (C_LSB_FIRST = 0)) generate
sck_rising_edge_process :
    process(SCK, start_edge)
    begin
      if (start_edge = '1') then
        if SCK = '1' then
          spi_byte_shift_reg <= byte(7) & byte;
        else 
          spi_byte_shift_reg <= byte & byte(0);
        end if;
        spi_bit_shift_counter <= (others => '0');
      elsif falling_edge(SCK) then
        if spi_bit_shift_counter = "1000" then
          last_bit <= '1';
          spi_bit_shift_counter <= (0 => '1', others => '0');
        else
          last_bit <= '0';
          spi_bit_shift_counter <= spi_bit_shift_counter + 1;
        end if;
        spi_byte_shift_reg(8 downto 1) <= spi_byte_shift_reg(7 downto 0);
      end if;
    end process;
    miso_o <= spi_byte_shift_reg(8);
end generate sck_rising_not_lsb_first_generate;

sck_falling_lsb_first_generate : if ((C_CPOL = 1 and C_CPHA = 0) or (C_CPOL = 0 and C_CPHA = 1)) and (C_LSB_FIRST = 1) generate
sck_falling_edge_process :
    process(SCK, CS, rst, start_edge)
    begin
      if (CS = '1') or (rst = '1') then
        spi_bit_shift_counter <= (others => '0');
        spi_byte_shift_reg <= (others => '0');
      elsif (start_edge = '1') then
        spi_byte_shift_reg <= byte;
      elsif rising_edge(SCK) then
        if spi_bit_shift_counter = "1000" then
          spi_bit_shift_counter <= ( 0 => '1', others => '0');
        else
        spi_bit_shift_counter <= spi_bit_shift_counter + 1;
        end if;
        spi_byte_shift_reg(6 downto 0) <= spi_byte_shift_reg(7 downto 1);
      end if;
    end process;
  miso_o <= spi_byte_shift_reg(0);
end generate sck_falling_lsb_first_generate;

sck_falling_not_lsb_first_generate : if ((C_CPOL = 1 and C_CPHA = 0) or (C_CPOL = 0 and C_CPHA = 1)) and (C_LSB_FIRST = 0) generate
sck_falling_edge_process :
    process(SCK, CS, rst, start_edge)
    begin
      if (CS = '1') or (rst = '1') then
        spi_bit_shift_counter <= (others => '0');
        spi_byte_shift_reg <= (others => '0');
      elsif (start_edge = '1') then
        spi_byte_shift_reg <= byte;
      elsif rising_edge(SCK) then
        if spi_bit_shift_counter = "1000" then
          spi_bit_shift_counter <= ( 0 => '1', others => '0');
        else
        spi_bit_shift_counter <= spi_bit_shift_counter + 1;
        end if;
        spi_byte_shift_reg(7 downto 1) <= spi_byte_shift_reg(6 downto 0);
      end if;
    end process;
  miso_o <= spi_byte_shift_reg(7);
end generate sck_falling_not_lsb_first_generate;


end Behavioral;
