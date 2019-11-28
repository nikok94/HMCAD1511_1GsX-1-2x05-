----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.04.2019 11:54:24
-- Design Name: 
-- Module Name: spi_adc_250x4_master - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;
library work;
use work.spi_byte_receiver;
use work.spi_byte_transceiver;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity spi_adc_250x4_master is
    generic (
      C_CPHA            : integer := 0;
      C_CPOL            : integer := 0;
      C_LSB_FIRST       : integer := 0
      
    );
    Port ( 
      SCK           : in std_logic;
      CS            : in std_logic;

      MISO_I        : in std_logic;
      MISO_O        : out std_logic;
      MISO_T        : out std_logic;
      
      MOSI_I        : in std_logic;
      MOSI_O        : out std_logic;
      MOSI_T        : out std_logic;

      m_fcb_clk     : in std_logic;
      m_fcb_areset  : in std_logic;
      m_fcb_addr    : out std_logic_vector(8 - 1 downto 0);
      m_fcb_wrdata  : out std_logic_vector(16 - 1 downto 0);
      m_fcb_wrreq   : out std_logic;
      m_fcb_wrack   : in std_logic;
      m_fcb_rddata  : in std_logic_vector(16 - 1 downto 0);
      m_fcb_rdreq   : out std_logic;
      m_fcb_rdack   : in std_logic
    );
end spi_adc_250x4_master;

architecture Behavioral of spi_adc_250x4_master is
    constant c_fcb_addr_width           : integer := 8;
    constant c_fcb_data_width           : integer := 16;
    type spi_state_machine      is (idle, wait_valid_addr_byte, wait_valid_wr_data_lsb_byte, wait_valid_wr_data_msb_byte, fcb_write,  fcb_read,  send_rd_data_lsb_byte, wait_send_lsb_byte, send_rd_data_msb_byte, wait_send_msb_byte);
    signal state, next_state            : spi_state_machine;
    signal address                      : std_logic_vector(c_fcb_addr_width - 1 downto 0);
    signal wr_data                      : std_logic_vector(c_fcb_data_width - 1 downto 0);
    signal rd_data                      : std_logic_vector(c_fcb_data_width - 1 downto 0);
    signal spi_rec_byte                 : std_logic_vector(7 downto 0);
    signal spi_rec_valid                : std_logic;
    signal spi_trans_byte               : std_logic_vector(7 downto 0);
    signal spi_trans_start              : std_logic;
    signal spi_trans_ready              : std_logic;
    signal spi_trans_error              : std_logic;
    signal rst                          : std_logic;
    signal rd_req                       : std_logic;
 

begin
rst <= m_fcb_areset;
m_fcb_rdreq <= rd_req;

spi_receiver_inst : entity spi_byte_receiver
    Generic map(
      C_CPHA        => C_CPHA     ,
      C_CPOL        => C_CPOL     ,
      C_LSB_FIRST   => C_LSB_FIRST
    )
    Port map(
      SCK          => SCK ,
      CS           => CS  ,
      MOSI         => mosi_i,
      
      clk          => m_fcb_clk,
      rst          => rst,
      byte         => spi_rec_byte,
      valid        => spi_rec_valid
    );

spi_transceiver_ist : entity spi_byte_transceiver
    Generic map(
      C_CPHA        => C_CPHA     ,
      C_CPOL        => C_CPOL     ,
      C_LSB_FIRST   => C_LSB_FIRST
    )
    Port map(
      SCK           => SCK ,
      CS            => CS  ,
      MISO          => miso_o,

      clk           => m_fcb_clk,
      rst           => rst,
      byte          => spi_trans_byte,
      start         => spi_trans_start,
      ready         => spi_trans_ready,
      error         => spi_trans_error
    );

state_sync_proc :
  process(m_fcb_clk) 
  begin
    if rising_edge(m_fcb_clk) then
      if (CS = '1' or rst = '1')then
        state <= idle;
      else 
        state <= next_state;
        if (m_fcb_rdack = '1') and (rd_req = '1') then
          rd_data <= m_fcb_rddata;
        end if;
      end if;
    end if;
  end process;

fcb_addr_data_proc :
  process(m_fcb_clk)
  begin
    if rising_edge(m_fcb_clk) then
      if (spi_rec_valid = '1') then
        case state is 
          when wait_valid_addr_byte =>
              address <= spi_rec_byte;
          when wait_valid_wr_data_lsb_byte =>
            wr_data(7 downto 0) <= spi_rec_byte;
          when wait_valid_wr_data_msb_byte => 
            wr_data(15 downto 8) <= spi_rec_byte;
          when others =>
        end case;
      end if;
    end if;
  end process;


state_data_proc:
  process(state) 
  begin
    rd_req <= '0';
    m_fcb_wrreq <= '0';
    spi_trans_start <= '0';
    miso_t <= '1';
      case state is
        when idle => 
        when fcb_write => 
          m_fcb_wrreq <= '1';
          m_fcb_addr <= address;
          m_fcb_wrdata <= wr_data;
        when fcb_read =>
          rd_req <= '1';
          m_fcb_addr <= '0' & address(6 downto 0);
        when send_rd_data_lsb_byte =>
          miso_t <= '0';
          spi_trans_start <= '1';
          spi_trans_byte <=  rd_data(7 downto 0);
        when wait_send_lsb_byte =>
          miso_t <= '0';
        when send_rd_data_msb_byte =>
          miso_t <= '0';
          spi_trans_start <= '1';
          spi_trans_byte <=  rd_data(15 downto 8);
        when wait_send_msb_byte =>
          miso_t <= '0';
        when others =>
      end case;
  end process;

next_state_proc:
  process(state, spi_rec_valid, spi_rec_byte, m_fcb_wrack, m_fcb_rdack, spi_trans_ready) 
  begin
    next_state <= state;
      case state is
      when idle =>
        next_state <= wait_valid_addr_byte;
      when wait_valid_addr_byte =>
        if (spi_rec_valid  = '1') then
          if (spi_rec_byte(c_fcb_addr_width - 1) = '1') then 
            next_state <= fcb_read;
          else 
            next_state <= wait_valid_wr_data_lsb_byte;
          end if;
        end if;
      when wait_valid_wr_data_lsb_byte =>
        if (spi_rec_valid  = '1') then
          next_state <= wait_valid_wr_data_msb_byte;
        end if;
      when wait_valid_wr_data_msb_byte => 
        if (spi_rec_valid = '1') then
          next_state <= fcb_write;
        end if;
      when fcb_write => 
        if m_fcb_wrack = '1' then
          next_state <= idle;
        end if;
      when fcb_read => 
        if (m_fcb_rdack = '1') then
          next_state <= send_rd_data_msb_byte;
        end if;
      when send_rd_data_lsb_byte =>
          next_state <= wait_send_lsb_byte;
      when wait_send_lsb_byte => 
        if (spi_trans_ready = '1') then
          next_state <= idle;
        end if;
      when send_rd_data_msb_byte => 
         next_state <= wait_send_msb_byte;
      when wait_send_msb_byte =>
        if (spi_trans_ready = '1') then
          next_state <= send_rd_data_lsb_byte;
        end if;
      when others =>
         next_state <= idle;
      end case;
  end process;


end Behavioral;
