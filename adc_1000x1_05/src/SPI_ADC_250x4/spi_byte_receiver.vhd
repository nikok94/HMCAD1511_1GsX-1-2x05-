----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 17.04.2019 12:10:25
-- Design Name: 
-- Module Name: spi_byte_receiver - Behavioral
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

entity spi_byte_receiver is
    Generic(
      C_CPHA        : integer := 0;
      C_CPOL        : integer := 0;
      C_LSB_FIRST   : integer := 0
    );
    Port (
      SCK           : in std_logic;
      CS            : in std_logic;
      MOSI          : in std_logic;
      
      clk           : in std_logic;
      rst           : in std_logic;
      byte          : out std_logic_vector(7 downto 0);
      valid         : out std_logic
    );
end spi_byte_receiver;

architecture Behavioral of spi_byte_receiver is

    signal spi_bit_shift_counter        : std_logic_vector(3 downto 0):= (others => '0');
    signal spi_byte_shift_reg           : std_logic_vector(7 downto 0):= (others => '0');
    signal spi_wr_byte_valid            : std_logic;
    signal spi_wr_byte_valid_d          : std_logic;
    signal spi_wr_byte_valid_d1         : std_logic;
    signal byte_valid                   : std_logic;



begin
sck_rising_lsb_first_generate : if ((C_CPOL = 0 and C_CPHA = 0) or (C_CPOL = 1 and C_CPHA = 1)) and (C_LSB_FIRST = 1) generate
sck_rising_edge_process :
    process(SCK, CS, rst)
    begin
      if (CS = '1') or (rst = '1') then
        spi_bit_shift_counter <= (others => '0');
        spi_byte_shift_reg <= (others => '0');
      elsif rising_edge(SCK) then
        if spi_bit_shift_counter = "1000" then
          spi_bit_shift_counter <= ( 0 => '1', others => '0');
        else
        spi_bit_shift_counter <= spi_bit_shift_counter + 1;
        end if;
        spi_byte_shift_reg(7) <= MOSI;
        spi_byte_shift_reg(6 downto 0) <= spi_byte_shift_reg(7 downto 1);
      end if;
    end process;
end generate sck_rising_lsb_first_generate;

sck_rising_not_lsb_first_generate : if ((C_CPOL = 0 and C_CPHA = 0) or (C_CPOL = 1 and C_CPHA = 1)) and (C_LSB_FIRST = 0) generate
sck_rising_edge_process :
    process(SCK, CS, rst)
    begin
      if (CS = '1') or (rst = '1') then
        spi_bit_shift_counter <= (others => '0');
        spi_byte_shift_reg <= (others => '0');
      elsif rising_edge(SCK) then
        if spi_bit_shift_counter = "1000" then
          spi_bit_shift_counter <= ( 0 => '1', others => '0');
        else
        spi_bit_shift_counter <= spi_bit_shift_counter + 1;
        end if;
        spi_byte_shift_reg(0) <= MOSI;
        spi_byte_shift_reg(7 downto 1) <= spi_byte_shift_reg(6 downto 0);
      end if;
    end process;
end generate sck_rising_not_lsb_first_generate;

sck_falling_lsb_first_generate : if ((C_CPOL = 1 and C_CPHA = 0) or (C_CPOL = 0 and C_CPHA = 1)) and (C_LSB_FIRST = 1) generate
sck_falling_edge_process :
    process(SCK, CS, rst)
    begin
      if (CS = '1') or (rst = '1') then
        spi_bit_shift_counter <= (others => '0');
        spi_byte_shift_reg <= (others => '0');
      elsif falling_edge(SCK) then
        if spi_bit_shift_counter = "1000" then
          spi_bit_shift_counter <= ( 0 => '1', others => '0');
        else
        spi_bit_shift_counter <= spi_bit_shift_counter + 1;
        end if;
        spi_byte_shift_reg(7) <= MOSI;
        spi_byte_shift_reg(6 downto 0) <= spi_byte_shift_reg(7 downto 1);
      end if;
    end process;
end generate sck_falling_lsb_first_generate;

sck_falling_not_lsb_first_generate : if ((C_CPOL = 1 and C_CPHA = 0) or (C_CPOL = 0 and C_CPHA = 1)) and (C_LSB_FIRST = 0) generate
sck_rising_edge_process :
    process(SCK, CS, rst)
    begin
      if (CS = '1') or (rst = '1') then
        spi_bit_shift_counter <= (others => '0');
        spi_byte_shift_reg <= (others => '0');
      elsif rising_edge(SCK) then
        if spi_bit_shift_counter = "1000" then
          spi_bit_shift_counter <= ( 0 => '1', others => '0');
        else
        spi_bit_shift_counter <= spi_bit_shift_counter + 1;
        end if;
        spi_byte_shift_reg(0) <= MOSI;
        spi_byte_shift_reg(7 downto 1) <= spi_byte_shift_reg(6 downto 0);
      end if;
    end process;
end generate sck_falling_not_lsb_first_generate;


--spi_wr_byte_valid_sync_proc :
--    process(clk)
--    begin
--      if rising_edge(clk) then
--        if (rst = '1') then
--          spi_wr_byte_valid_sync_vec <= (others => '0');
--          spi_wr_byte_valid_sync <= '0';
--        else
--          spi_wr_byte_valid_sync_vec(0) <= spi_wr_byte_valid;
--          spi_wr_byte_valid_sync_vec(2 downto 1) <= spi_wr_byte_valid_sync_vec(1 downto 0);
--          spi_wr_byte_valid_sync <= (not spi_wr_byte_valid_sync_vec(2)) and spi_wr_byte_valid_sync_vec(1);
--        end if;
--      end if;
--    end process;

byte_valid <= (not spi_wr_byte_valid_d1) and spi_wr_byte_valid_d;

out_process:
    process(clk)
    begin
      if rising_edge(clk) then
        if (rst = '1') then
          byte  <= (others => '0');
          valid <= '0';
        elsif (byte_valid = '1') then
          valid <= '1';
          byte  <= spi_byte_shift_reg;
        else
          valid <= '0';
        end if;
        spi_wr_byte_valid <= spi_bit_shift_counter(3);
        spi_wr_byte_valid_d <= spi_wr_byte_valid;
        spi_wr_byte_valid_d1 <= spi_wr_byte_valid_d;
      end if;
    end process;


end Behavioral;
