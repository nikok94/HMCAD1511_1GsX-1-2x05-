----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 16.05.2019 10:31:28
-- Design Name: 
-- Module Name: low_adc_data_capture - Behavioral
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
use work.fifo_low_adc_8196;
use work.fifo_10x16;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity low_adc_data_capture is
    Port (
      low_adc_clk       : in std_logic;
      low_adc_data      : in std_logic_vector(9 downto 0);

      buff_len          : in std_logic_vector(15 downto 0);
      trig_start        : in std_logic;
      rst               : in std_logic;
      
      m_strm_clk        : in std_logic;
      m_strm_data       : out std_logic_vector(7 downto 0);
      m_strm_valid      : out std_logic;
      m_strm_ready      : in std_logic;
      
      buf_data_valid    : out std_logic
    );
end low_adc_data_capture;

architecture Behavioral of low_adc_data_capture is
    type state_machine  is (idle, wait_start, wr_buffer, rd_buffer, rd_addr_edge);
    signal state, next_state : state_machine;
    signal adc_clk          : std_logic:= '0';
    signal adc_clk_d        : std_logic;
    signal adc_clk_rising   : std_logic;
    
    signal adc_clk_counter  : std_logic_vector(5 downto 0):= (others => '0');
    signal wr_en            : std_logic;
    signal wr_addr          : std_logic_vector(13 downto 0):= (others => '0');
    signal rd_addr          : std_logic_vector(13 downto 0):= (others => '0');
    signal valid            : std_logic;
    
    signal fifo_empty       : std_logic;
    signal fifo_full        : std_logic;
    signal fifo_wr_en       : std_logic;
    signal fifo_rd_en       : std_logic;
    signal fifo_valid       : std_logic;
    signal trig_start_to_sync: std_logic;
    signal trig_start_vector: std_logic_vector(2 downto 0);
    signal buff_len_sync    : std_logic_vector(15 downto 0);
    signal buf_len_to_sync  : std_logic_vector(15 downto 0);
    signal domen_fifo_rd_en : std_logic;
    signal domen_fifo_empty : std_logic;
    signal domen_fifo_dout  : std_logic_vector(9 downto 0);
    signal domen_fifo_valid : std_logic;
    signal wr_buf_status    : std_logic;
    signal rd_buf_status    : std_logic;
    
    signal low_adc_data_in  : std_logic_vector(15 downto 0);

begin
clock_domen_fifo : ENTITY fifo_10x16
  PORT MAP(
    rst     => '0',
    wr_clk  => low_adc_clk,
    rd_clk  => m_strm_clk,
    din     => low_adc_data,
    wr_en   => '1',
    rd_en   => domen_fifo_rd_en,
    dout    => domen_fifo_dout,
    full    => open,
    empty   => domen_fifo_empty,
    valid   => domen_fifo_valid
  );

domen_fifo_rd_en <= (not domen_fifo_empty);

low_adc_data_in <= domen_fifo_dout(7 downto 0) & "000000" & domen_fifo_dout(9 downto 8);

mem_inst : ENTITY fifo_low_adc_8196
  PORT MAP(
    rst         => rst,
    wr_clk      => m_strm_clk,
    rd_clk      => m_strm_clk,
    din         => low_adc_data_in, --"000000" & domen_fifo_dout,
    wr_en       => fifo_wr_en,
    rd_en       => fifo_rd_en,
    dout        => m_strm_data,
    full        => fifo_full,
    empty       => fifo_empty,
    valid       => fifo_valid
  );

fifo_wr_en <= domen_fifo_valid and wr_buf_status;

fifo_rd_en      <= valid and m_strm_ready;
valid           <= fifo_valid and rd_buf_status;
m_strm_valid    <= valid;
buf_data_valid  <= rd_buf_status;

wr_addr_proc :
  process(m_strm_clk)
  begin
    if (state = idle) then 
      wr_addr <= (others => '0');
    elsif rising_edge(m_strm_clk) then
      if (fifo_wr_en = '1') then
        wr_addr <= wr_addr + 1;
      end if;
    end if;
    end process;

state_sync :
  process(m_strm_clk)
  begin
    if rising_edge(m_strm_clk) then
      if rst = '1' then 
        state <= idle;
      else
        state <= next_state;
      end if;
    end if;
  end process;

out_state_proc :
  process(state)
  begin
  wr_buf_status <= '0';
  rd_buf_status <= '0';
    case state is
      when idle =>
      when wr_buffer => 
        wr_buf_status <= '1';
      when rd_buffer =>
        rd_buf_status <= '1';
      when others => 
    end case;
  end process;

next_state_proc :
  process(state, trig_start, wr_addr, fifo_full, m_strm_ready, rd_addr, fifo_empty)
  begin
    next_state <= state;
      case state is
        when idle =>
          next_state <= wait_start;
        when wait_start => 
          if (trig_start = '1') then
            next_state <= wr_buffer;
          end if;
        when wr_buffer => 
          if (wr_addr >= buff_len_sync - 1) or (fifo_full = '1') then
            next_state <= rd_buffer;
          end if;
        when rd_buffer => 
          if (fifo_empty = '1') then
              next_state <= idle;
          end if;
        when others =>
      end case;
   end process;

end Behavioral;
