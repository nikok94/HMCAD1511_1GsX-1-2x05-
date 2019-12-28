----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 30.05.2019 09:43:32
-- Design Name: 
-- Module Name: ADC1511_Dual_1GHzX2_Top - Behavioral
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
use work.HMCAD1511_v3_00;
--use work.HMCAD1511_x2_v1_00;
use work.clock_generator;
use work.fclk_clock_gen;
use work.spi_adc_250x4_master;
--use work.fifo_sream;
use work.async_fifo_64;
use work.async_fifo_8;
use work.trigger_capture;
--use work.data_capture_module;
use work.data_capture;
use work.QuadSPI_adc_250x4_module;
use work.high_speed_clock_to_serdes;
--use work.ila;
--use work.ila_data_in;
--use work.icon;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity ADC1511_Dual_1GHzX2_Top is
    Port ( 
        adc1_lclk_p             : in std_logic;
        adc1_lclk_n             : in std_logic;
        adc1_fclk_p             : in std_logic;
        adc1_fclk_n             : in std_logic;
        adc1_dx_a_p             : in std_logic_vector(3 downto 0);
        adc1_dx_a_n             : in std_logic_vector(3 downto 0);
        adc1_dx_b_p             : in std_logic_vector(3 downto 0);
        adc1_dx_b_n             : in std_logic_vector(3 downto 0);


        adc2_lclk_p             : in std_logic;
        adc2_lclk_n             : in std_logic;
        adc2_fclk_p             : in std_logic;
        adc2_fclk_n             : in std_logic;
        adc2_dx_a_p             : in std_logic_vector(3 downto 0);
        adc2_dx_a_n             : in std_logic_vector(3 downto 0);
        adc2_dx_b_p             : in std_logic_vector(3 downto 0);
        adc2_dx_b_n             : in std_logic_vector(3 downto 0);
        
        xc_sys_rstn             : in std_logic;
        
--        tst_clk_adc1_out        : out std_logic;
--        tst_clk_adc2_out        : out std_logic;
        
        adc1_data_valid         : out std_logic;
        adc2_data_valid         : out std_logic;
        adc_calib_done          : out std_logic;
        main_pll_lock           : out std_logic;
        
        --rst_out                 : out std_logic;

        pulse_out_p             : out std_logic;
        pulse_out_n             : out std_logic;

        in_clk_50MHz            : in std_logic;

        spifi_cs                : in std_logic;
        spifi_sck               : in std_logic;
        spifi_miso              : inout std_logic;
        spifi_mosi              : inout std_logic;
        spifi_sio2              : inout std_logic;
        spifi_sio3              : inout std_logic;
        
        --fclk_div1               : out std_logic;
        --fclk_div2               : out std_logic;
        
        t6                      : out std_logic;
        t7                      : out std_logic;
        t8                      : out std_logic;
        
        p6_6_xor_out            : out std_logic;
        
        fpga_sck                : in std_logic;
        fpga_cs                 : in std_logic;
        fpga_miso               : out std_logic;
        fpga_mosi               : in std_logic

    );
end ADC1511_Dual_1GHzX2_Top;

architecture Behavioral of ADC1511_Dual_1GHzX2_Top is
    signal adc1_clk_div8            : std_logic;
    signal adc1_sync_valid          : std_logic;
    signal adc1_fifo_m_stream_ready : std_logic;
    signal adc1_valid               : std_logic;
    signal adc1_data                : std_logic_vector(63 downto 0);
    signal adc2_clk_div8            : std_logic;
    signal adc2_sync_valid          : std_logic;
    signal adc2_fifo_m_stream_ready : std_logic;
    signal adc2_valid               : std_logic;
    signal adc2_data                : std_logic_vector(63 downto 0);
    signal mod1_sync_valid        : std_logic;
    signal mod2_sync_valid        : std_logic;
    
    signal MISO_I               : std_logic;
    signal MISO_O               : std_logic;
    signal MISO_T               : std_logic;
    signal MOSI_I               : std_logic;
    signal MOSI_O               : std_logic;
    signal MOSI_T               : std_logic;
    signal m_fcb_aresetn        : std_logic;
    signal m_fcb_addr           : std_logic_vector(8 - 1 downto 0);
    signal m_fcb_wrdata         : std_logic_vector(16 - 1 downto 0);
    signal m_fcb_wrreq          : std_logic;
    signal m_fcb_wrack          : std_logic;
    signal m_fcb_rddata         : std_logic_vector(16 - 1 downto 0);
    signal m_fcb_rdreq          : std_logic;
    signal m_fcb_rdack          : std_logic;
    
    signal trig_set_up_reg              : std_logic_vector(15 downto 0):= x"7f00";
    signal trig_window_width_reg        : std_logic_vector(15 downto 0):= x"0200";
    signal trig_position_reg            : std_logic_vector(15 downto 0):= x"0800";
    signal control_reg                  : std_logic_vector(15 downto 0):= (others => '0');
    signal calib_pattern_reg            : std_logic_vector(15 downto 0):= x"55AA";
    signal wr_req_vec                   : std_logic_vector(5 downto 0);
    signal reg_address_int              : integer;
    signal adc_calib                    : std_logic:= '0';
    signal control_reg_d                : std_logic_vector(15 downto 0);
    signal low_adc_buff_len             : std_logic_vector(15 downto 0);

    signal adc1_sync_data      : std_logic_vector(63 downto 0);
    signal adc2_sync_data      : std_logic_vector(63 downto 0);

--    signal strm_fifo1_rstn              : std_logic;
--    signal strm_fifo2_rstn              : std_logic;

    signal adc1_ila_control             : std_logic_vector(35 downto 0);
    signal control_0                    : std_logic_vector(35 downto 0);
    signal control_1                    : std_logic_vector(35 downto 0);
    signal control_2                    : std_logic_vector(35 downto 0);
    signal cal                          : std_logic;
    signal infrst_rst_out               : std_logic;
    signal vio_calib_vector             : std_logic_vector(3 downto 0);
    signal vio_calib_vector_d           : std_logic_vector(3 downto 0);
    signal clk_125MHz                   : std_logic;
    signal clk_250MHz                   : std_logic;
    signal clk_500MHz                   : std_logic;
    signal rst                          : std_logic;
    signal ext_trig                     : std_logic:= '0';
    signal adc1_trigger_start           : std_logic;
    signal adc2_trigger_start           : std_logic;
    signal adc3_trigger_start           : std_logic;
    signal adc1_trigger_set_up          : std_logic;
    signal adc1_trigger_set_vec         : std_logic_vector(1 downto 0);
    signal adc2_trigger_set_up          : std_logic;
    signal adc2_trigger_set_vec         : std_logic_vector(1 downto 0);
    signal adc3_trigger_set_up          : std_logic;
    signal adc3_trigger_set_vec         : std_logic_vector(1 downto 0);
    signal adc1_capture_module_rst      : std_logic;
    signal adc2_capture_module_rst      : std_logic;
    signal trigger_start                : std_logic;
    signal trigger_start_up             : std_logic;
    signal trigger_start_up_d           : std_logic;
    signal adc1_m_strm_data             : std_logic_vector(63 downto 0);
    signal adc1_m_strm_valid            : std_logic;
    signal adc1_m_strm_ready            : std_logic;
    signal adc2_m_strm_data             : std_logic_vector(63 downto 0);
    signal adc2_m_strm_valid            : std_logic;
    signal adc2_m_strm_ready            : std_logic;
    signal adc_receiver_rst             : std_logic:= '0';
    signal adc_receiver_rst_vect        : std_logic_vector(7 downto 0);
    signal pulse_start                  : std_logic:= '0';
    signal pulse                        : std_logic;
    signal pulse_counter                : std_logic_vector(2 downto 0);
    signal pll_lock                     : std_logic;
    signal adc1_rst                     : std_logic;
    signal high_speed_clock_bufg        : std_logic;
    signal sys_rst                      : std_logic;
    signal lck1                         : std_logic;
    signal lck2                         : std_logic;
    signal trig_wait_sts1               : std_logic;
    signal trig_wait_sts1_d1            : std_logic;
    signal trig_wait_sts1_d2            : std_logic;
    signal trig_wait_sts1_d3            : std_logic;
    signal trig_wait_sts2               : std_logic;
    signal trig_wait_sts2_d1            : std_logic;
    signal trig_wait_sts2_d2            : std_logic;
    signal trig_wait_sts2_d3            : std_logic;
    signal error                        : std_logic;
    signal trig1_en                     : std_logic;
    signal trig2_en                     : std_logic;
    signal adc1_data_sync               : std_logic_vector(63 downto 0);
    signal adc2_data_sync               : std_logic_vector(63 downto 0);
    signal adc1_data_sync_valid         : std_logic;
    signal adc2_data_sync_valid         : std_logic;
    signal rd_data_sync_count1          : std_logic_vector(4 downto 0);
    signal rd_data_sync_count2          : std_logic_vector(4 downto 0);
    signal dec1                         : std_logic;
    signal dec2                         : std_logic;
    signal to_dec1                      : std_logic;
    signal to_dec2                      : std_logic;
    signal fifo_stream_s_tready1        : std_logic;
    signal fifo_stream_s_tready2        : std_logic;
    signal fifo_stream_m_tvalid1        : std_logic;
    signal fifo_stream_m_tvalid2        : std_logic;
    signal fifo_stream_m_tdata1         : std_logic_vector(63 downto 0);
    signal fifo_stream_m_tdata2         : std_logic_vector(63 downto 0);
    signal fifo_stream_m_tready1        : std_logic;
    signal fifo_stream_m_tready2        : std_logic;
    signal fifo_stream_m_full1          : std_logic;
    signal fifo_stream_m_full2          : std_logic;
    signal all_fifo_valid               : std_logic;
    signal vector_valid1                : std_logic_vector(7 downto 0);
    signal vector_valid2                : std_logic_vector(7 downto 0);
    signal bitsleep_counter1            : std_logic_vector(3 downto 0);
    signal bitsleep_counter2            : std_logic_vector(3 downto 0);
    signal lclk1                        : std_logic;
    signal fclk1                        : std_logic;
    signal lclk2                        : std_logic;
    signal fclk2                        : std_logic;
    signal all_fifo_rst                 : std_logic;
    signal frame1                       : std_logic_vector(7 downto 0);
    signal frame2                       : std_logic_vector(7 downto 0);
    signal frame1_s1                    : std_logic_vector(7 downto 0);
    signal frame2_s1                    : std_logic_vector(7 downto 0);
    signal frame1_s2                    : std_logic_vector(7 downto 0);
    signal frame2_s2                    : std_logic_vector(7 downto 0);
    
    signal serdesclk0_1                 : std_logic;
    signal serdesclk1_1                 : std_logic;
    signal serdesstrobe_1               : std_logic;
    signal serdesclk0_2                 : std_logic;
    signal serdesclk1_2                 : std_logic;
    signal serdesstrobe_2               : std_logic;
    signal gclk                         : std_logic;
    signal serdesclk0                   : std_logic;
    signal serdesclk1                   : std_logic;
    signal serdesstrobe                 : std_logic;
    signal nvalid_counter               : std_logic_vector(15 downto 0);
    signal nvalid_counter_msb_d         : std_logic;
    signal fclk_div1                    : std_logic;
    signal fclk_div2                    : std_logic;
    signal fclk_div1_s                  : std_logic;
    signal fclk_div2_s                  : std_logic;
    signal clk_250MHz_counter           : std_logic_vector(3 downto 0):=(others => '0');
    signal clk_250MHz_strob             : std_logic;
    signal fclk_div1_shift_reg          : std_logic_vector(15 downto 0);
    signal fclk_div2_shift_reg          : std_logic_vector(15 downto 0);
    signal frame1_s16                   : std_logic_vector(15 downto 0);
    signal frame2_s16                   : std_logic_vector(15 downto 0);
    signal fck1_xor_fck2                : std_logic;
    signal calib_done                   : std_logic;
    signal ff1_reg, ff2_reg             : std_logic_vector(3 downto 0);
    signal lck_counter                  : std_logic_vector(1 downto 0);
    signal ff_val                       : std_logic;
    signal ff1, ff2                     : std_logic_vector(3 downto 0);
    
    signal ff1_reg_f, ff2_reg_f         : std_logic_vector(3 downto 0);
    signal lck_counter_f                : std_logic_vector(1 downto 0);
    signal ff_val_f                     : std_logic;
    signal ff1_f, ff2_f                 : std_logic_vector(3 downto 0);
    
    
    signal ff1_ff2_vec                  : std_logic_vector(15 downto 0):= (others => '0');
    signal ff1_ff2_vec1                 : std_logic_vector(15 downto 0):= (others => '0');

    signal async_fifo_8_wr_en           : std_logic;
    signal async_fifo_8_rd_en           : std_logic;
    signal async_fifo_8_full            : std_logic;
    signal async_fifo_8_valid           : std_logic;
    signal async_fifo_8_din             : std_logic_vector(15 downto 0);
    signal async_fifo_8_dout            : std_logic_vector(15 downto 0);
    signal async_fifo_8_dout_d          : std_logic_vector(15 downto 0);
    type state_machine                  is (idle, all_fifo_val_st, counter_st, ready_st);
    signal next_state, state            : state_machine;
    signal tick_counter                 : std_logic_vector(12 downto 0);
    signal lck2_pll                     : std_logic;
    signal lck2_pll_180                 : std_logic;
    signal rst_lck2_pll_s               : std_logic;
    signal fclk_pll_lock                : std_logic;

begin

rst <= infrst_rst_out or control_reg(1) or adc_receiver_rst;

sys_rst <= (not xc_sys_rstn);

Clock_gen_inst : entity clock_generator
    Port map( 
      clk_in            => in_clk_50MHz,
      rst_in            => sys_rst,
      pll_lock          => pll_lock,
      clk_out_125MHz    => clk_125MHz,
      clk_out_250MHz    => clk_250MHz,
      clk_out_500MHz    => clk_500MHz,
      rst_out           => infrst_rst_out
    );
    
fclk_clock_gen_inst : entity fclk_clock_gen
    Port map( 
      fclk          => fclk2,
      rst           => rst,
      pll_lock      => fclk_pll_lock,
      clk_out       => lck2_pll,
      clk_out_180   => lck2_pll_180
    );

main_pll_lock <= pll_lock;

adc_calib_done_proc :
process(clk_125MHz, rst)
begin
  if (rst = '1') then
    calib_done <= '0';
  elsif rising_edge(clk_125MHz) then
    if all_fifo_valid = '1' then
      calib_done <= '1';
    end if;
  end if;
end process;

adc_calib_done <= calib_done;

rst_lck2_pll_s_proc :
process(lck2_pll_180, rst)
begin
  if rst = '1' then
    rst_lck2_pll_s <= '1';
  elsif rising_edge(lck2_pll_180) then
    rst_lck2_pll_s <= '0';
  end if;
end process;

frames_reg_process:
process(lck2_pll, rst_lck2_pll_s)
begin
  if (rst_lck2_pll_s = '1') then
    ff1_reg <= (others => '0');
    ff2_reg <= (others => '0');
    lck_counter <= (others => '0');
    ff_val <= '0';
  elsif rising_edge(lck2_pll) then
    ff1_reg(0) <= fclk1;
    ff1_reg(3 downto 1) <= ff1_reg(2 downto 0);
    ff2_reg(0) <= fclk2;
    ff2_reg(3 downto 1) <= ff2_reg(2 downto 0);
    if (lck_counter = "11") then
      ff1 <= ff1_reg;
      ff2 <= ff2_reg;
      lck_counter <= (others => '0');
      ff_val <= '1';
    else
      lck_counter <= lck_counter + 1;
      ff_val <= '0';
    end if;
  end if;
end process;

frames_f_reg_process:
process(lck2_pll_180, rst_lck2_pll_s)
begin
  if (rst_lck2_pll_s = '1') then
    ff1_reg_f <= (others => '0');
    ff2_reg_f <= (others => '0');
    lck_counter_f <= (others => '0');
    ff_val_f <= '0';
  elsif rising_edge(lck2_pll_180) then
    ff1_reg_f(0) <= fclk1;
    ff1_reg_f(3 downto 1) <= ff1_reg_f(2 downto 0);
    ff2_reg_f(0) <= fclk2;
    ff2_reg_f(3 downto 1) <= ff2_reg_f(2 downto 0);
    if (lck_counter_f = "11") then
      ff1_f <= ff1_reg_f;
      ff2_f <= ff2_reg_f;
      lck_counter_f <= (others => '0');
      ff_val_f <= '1';
    else
      lck_counter_f <= lck_counter_f + 1;
      ff_val_f <= '0';
    end if;
  end if;
end process;

async_fifo_8_wr_en_proc :
process(lck2_pll)
begin
  if rising_edge(lck2_pll) then
    if (ff_val_f = '1') and (ff_val = '1') then
      async_fifo_8_din(7 downto 0) <= ff1_reg(3) & ff1_reg_f(3) & ff1_reg(2) & ff1_reg_f(2) & ff1_reg(1) & ff1_reg_f(1) & ff1_reg(0) & ff1_reg_f(0);
      async_fifo_8_din(15 downto 8) <= ff2_reg(3) & ff2_reg_f(3) & ff2_reg(2) & ff2_reg_f(2) & ff2_reg(1) & ff2_reg_f(1) & ff2_reg(0) & ff2_reg_f(0);
      async_fifo_8_wr_en <= '1';
    else 
      async_fifo_8_wr_en <= '0';
    end if;
  end if;
end process;


--lck2_bufg <= clk_125MHz;

async_fifo_8_inst : ENTITY async_fifo_8
  PORT MAP(
    rst         => rst,
    wr_clk      => lck2_pll,
    rd_clk      => clk_125MHz,
    din         => async_fifo_8_din,
    wr_en       => async_fifo_8_wr_en,
    rd_en       => async_fifo_8_rd_en,
    dout        => async_fifo_8_dout,
    full        => async_fifo_8_full,
    empty       => open,
    valid       => async_fifo_8_valid
  );

async_fifo_8_rd_en <= async_fifo_8_valid;


state_sync_proc :
process(clk_125MHz, rst)
begin
  if (rst = '1') then
    state <= idle;
  elsif rising_edge(clk_125MHz) then
    state <= next_state;
  end if;
end process;

next_state_process :
process(state, all_fifo_valid, tick_counter(tick_counter'length - 1))
begin
  next_state <= state;
  p6_6_xor_out <= '0';
    case (state) is
      when idle =>
        next_state <= all_fifo_val_st;
      when all_fifo_val_st => 
        if (all_fifo_valid = '1') then
          next_state <= counter_st;
        end if;
      when counter_st =>
        if tick_counter(tick_counter'length - 1) = '1' then
          next_state <= ready_st;
        end if;
      when ready_st =>
        p6_6_xor_out <= '1';
      when others =>
        next_state <= idle;
    end case;
end process;

--async_fifo_8_dout <= ff2 & ff1;
--async_fifo_8_valid <= ff_val;

async_fifo_8_dout_d_proc :
  process(clk_125MHz)
  begin
    if rising_edge(clk_125MHz) then
      if (async_fifo_8_valid = '1') then
        async_fifo_8_dout_d <= async_fifo_8_dout;
      end if;
    end if;
  end process;

tick_counter_proc :
  process(clk_125MHz, state)
  begin
    if (state /= counter_st) then
      tick_counter <= (others => '0');
    elsif rising_edge(clk_125MHz) then
      if (async_fifo_8_valid = '1') then
        if (async_fifo_8_dout_d = async_fifo_8_dout) then
          tick_counter <= tick_counter + 1;
          ff1_ff2_vec <= async_fifo_8_dout;
        else
          tick_counter <= (others => '0');
        end if;
      end if;
    end if;
  end process;
  
ff1_ff2_vec1 <= ff1_ff2_vec;


IBUFGDS1_inst : IBUFGDS
   generic map (
      IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
      IOSTANDARD => "DEFAULT")
   port map (
      O => lclk1,     -- Clock buffer output
      I => adc1_lclk_p,         -- Diff_p clock buffer input
      IB => adc1_lclk_n         -- Diff_n clock buffer input
   );

hscs1 : entity high_speed_clock_to_serdes
    Generic map (
      S                   => 8
      )
    Port map(
      clkin_ibufg         => lclk1,
      gclk                => adc1_clk_div8,
      serdesclk0          => serdesclk0_1,
      serdesclk1          => serdesclk1_1,
      serdesstrobe        => serdesstrobe_1
    );

IBUFGDS2_inst : IBUFGDS
   generic map (
      IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
      IOSTANDARD => "DEFAULT")
   port map (
      O => lclk2,     -- Clock buffer output
      I => adc2_lclk_p,         -- Diff_p clock buffer input
      IB => adc2_lclk_n         -- Diff_n clock buffer input
   );

hscs2 : entity high_speed_clock_to_serdes
    Generic map (
      S                   => 8
      )
    Port map(
      clkin_ibufg         => lclk2,
      gclk                => adc2_clk_div8,
      serdesclk0          => serdesclk0_2,
      serdesclk1          => serdesclk1_2,
      serdesstrobe        => serdesstrobe_2
    );

adc1_data_receiver : entity HMCAD1511_v3_00
    Port map(
      FCLKp                 => adc1_fclk_p,
      FCLKn                 => adc1_fclk_n,

      DxXAp                 => adc1_dx_a_p,
      DxXAn                 => adc1_dx_a_n,
      DxXBp                 => adc1_dx_b_p,
      DxXBn                 => adc1_dx_b_n,
      
      reset                 => rst,
      m_strm_valid          => adc1_valid,
      m_strm_data           => adc1_data,
      bsleep_counter        => bitsleep_counter1,

      gclk                  => adc1_clk_div8,
      serdesclk0            => serdesclk0_1,
      serdesclk1            => serdesclk1_1,
      serdesstrobe          => serdesstrobe_1,

      frame                 => frame1,
      fclk_obuf             => fclk1
    );

adc2_data_receiver : entity HMCAD1511_v3_00
    Port map(
      FCLKp                 => adc2_fclk_p,
      FCLKn                 => adc2_fclk_n,

      DxXAp                 => adc2_dx_a_p,
      DxXAn                 => adc2_dx_a_n,
      DxXBp                 => adc2_dx_b_p,
      DxXBn                 => adc2_dx_b_n,

      reset                 => rst,
      m_strm_valid          => adc2_valid,
      m_strm_data           => adc2_data,
      bsleep_counter        => bitsleep_counter2,
      gclk                  => adc2_clk_div8,
      serdesclk0            => serdesclk0_2,
      serdesclk1            => serdesclk1_2,
      serdesstrobe          => serdesstrobe_2,

      frame                 => frame2,
      fclk_obuf             => fclk2
    );

t6 <= fclk1;
t7 <= fclk2;
fck1_xor_fck2 <= (fclk1 xor fclk2);
t8 <= fck1_xor_fck2;

nvalid_counter_proc:
process(clk_125MHz, rst, all_fifo_valid)
begin
    if (rst = '1') then
      nvalid_counter <= (others => '0');
    elsif rising_edge(clk_125MHz) then
      if (all_fifo_valid = '0') then
        if (nvalid_counter(nvalid_counter'length - 1) = '0') then
          nvalid_counter <= nvalid_counter + 1;
        end if;
      else
        nvalid_counter <= (others => '0');
      end if;
    end if;
end process;

nvalid_counter_msb_d_proc :
process(clk_125MHz)
begin
    if rising_edge(clk_125MHz) then
      nvalid_counter_msb_d <= nvalid_counter(nvalid_counter'length - 1);
      adc_receiver_rst <= (nvalid_counter(nvalid_counter'length - 1)) and (not nvalid_counter_msb_d);
    end if;
end process;

all_fifo_rst <= (not (adc2_valid and adc1_valid)) or rst;

adc1_async_fifo_inst : ENTITY async_fifo_64
  PORT MAP(
    rst             => all_fifo_rst,
    wr_clk          => adc1_clk_div8,
    rd_clk          => clk_250MHz,
    din             => adc1_data,
    wr_en           => adc1_valid,
    rd_en           => fifo_stream_s_tready1,
    dout            => adc1_sync_data,
    full            => open,
    empty           => open,
    valid           => adc1_sync_valid,
    rd_data_count   => rd_data_sync_count1
  );

adc2_async_fifo_inst : ENTITY async_fifo_64
  PORT MAP(
    rst             => all_fifo_rst,
    wr_clk          => adc2_clk_div8,
    rd_clk          => clk_250MHz,
    din             => adc2_data,
    wr_en           => adc2_valid,
    rd_en           => fifo_stream_s_tready2,
    dout            => adc2_sync_data,
    full            => open,
    empty           => open,
    valid           => adc2_sync_valid,
    rd_data_count   => open
  );
  
fifo_strm1 : ENTITY async_fifo_64
  PORT MAP(
    rst             => all_fifo_rst,
    wr_clk          => clk_250MHz,
    rd_clk          => clk_125MHz,
    din             => adc1_sync_data,
    wr_en           => adc1_sync_valid,
    rd_en           => fifo_stream_m_tready1,
    dout            => fifo_stream_m_tdata1,
    full            => fifo_stream_m_full1,
    empty           => open,
    valid           => fifo_stream_m_tvalid1,
    rd_data_count   => open
  );
  
fifo_stream_s_tready1 <= adc1_sync_valid and (not fifo_stream_m_full1);
fifo_stream_m_tready1 <= all_fifo_valid;

fifo_strm2 : ENTITY async_fifo_64
  PORT MAP(
    rst             => all_fifo_rst,
    wr_clk          => clk_250MHz,
    rd_clk          => clk_125MHz,
    din             => adc2_sync_data,
    wr_en           => adc2_sync_valid,
    rd_en           => fifo_stream_m_tready2,
    dout            => fifo_stream_m_tdata2,
    full            => fifo_stream_m_full2,
    empty           => open,
    valid           => fifo_stream_m_tvalid2,
    rd_data_count   => open
  );
  
fifo_stream_s_tready2 <= adc2_sync_valid and (not fifo_stream_m_full2);
fifo_stream_m_tready2 <= all_fifo_valid;

all_fifo_valid <= fifo_stream_m_tvalid1 and fifo_stream_m_tvalid2;

adc1_trigger_capture_inst : entity trigger_capture
    generic map(
      c_data_width    => 64
    )
    Port map( 
      clk               => clk_125MHz,
      rst               => rst,
      capture_mode      => trig_set_up_reg(1 downto 0),
      capture_level     => trig_set_up_reg(15 downto 8),
      trigger_set_up    => adc1_trigger_set_up,

      valid             => all_fifo_valid,
      data              => fifo_stream_m_tdata1,        -- входные значения данных от АЦП
      ext_trig          => ext_trig,                    -- внешний триггер
      vector_valid      => vector_valid1,

      trigger_start     => adc1_trigger_start           -- выходной сигнал управляет модулем захвата данных
    );

adc2_trigger_capture_inst : entity trigger_capture
    generic map(
      c_data_width    => 32
    )
    Port map( 
      clk               => clk_125MHz,
      rst               => rst,
      capture_mode      => trig_set_up_reg(1 downto 0),
      capture_level     => trig_set_up_reg(15 downto 8),
      trigger_set_up    => adc2_trigger_set_up,

      valid             => all_fifo_valid,
      data              => fifo_stream_m_tdata2(31 downto 0),       -- входные значения данных от АЦП
      ext_trig          => ext_trig,                   -- внешний триггер
      vector_valid      => open,
      
      trigger_start     => adc2_trigger_start          -- выходной сигнал управляет модулем захвата данных
    );

adc3_trigger_capture_inst : entity trigger_capture
    generic map(
      c_data_width    => 32
    )
    Port map( 
      clk               => clk_125MHz,
      rst               => rst,
      capture_mode      => trig_set_up_reg(1 downto 0),
      capture_level     => trig_set_up_reg(15 downto 8),
      trigger_set_up    => adc3_trigger_set_up,

      valid             => all_fifo_valid,
      data              => fifo_stream_m_tdata2(63 downto 32),       -- входные значения данных от АЦП
      ext_trig          => ext_trig,                   -- внешний триггер
      vector_valid      => open,
      
      trigger_start     => adc3_trigger_start          -- выходной сигнал управляет модулем захвата данных
    );


adc1_data_capture_inst : entity data_capture
    generic map(
      c_max_window_size_width   =>  16,
      c_strm_data_width         =>  64,
      c_trig_delay              =>  2
    )
    Port map( 
      areset                    => rst,
      trigger_start             => trigger_start,
      window_size               => trig_window_width_reg,
      trig_position             => trig_position_reg,

      aclk                      => clk_125MHz, 
      s_strm_data               => fifo_stream_m_tdata1,
      s_strm_valid              => all_fifo_valid,
      --dec                       => dec1,

      m_strm_data               => adc1_m_strm_data,
      m_strm_valid              => adc1_m_strm_valid,
      m_strm_ready              => adc1_m_strm_ready,
      m_strm_rst                => adc1_capture_module_rst
    );

adc2_data_capture_inst : entity data_capture
    generic map(
      c_max_window_size_width   =>  16,
      c_strm_data_width         =>  64,
      c_trig_delay              =>  2
    )
    Port map( 
      areset                    => rst,
      trigger_start             => trigger_start,
      window_size               => trig_window_width_reg,
      trig_position             => trig_position_reg,

      aclk                      => clk_125MHz, 
      s_strm_data               => fifo_stream_m_tdata2,
      s_strm_valid              => all_fifo_valid,

      m_strm_data               => adc2_m_strm_data,
      m_strm_valid              => adc2_m_strm_valid,
      m_strm_ready              => adc2_m_strm_ready,
      m_strm_rst                => adc2_capture_module_rst
    );

error <= (trig1_en and (not trig2_en)) or (trig1_en and (not trig2_en));


trigger_set_up_process :
  process(clk_125MHz)
  begin
    if rising_edge(clk_125MHz) then
      if (control_reg(4) = '1') then
        case trig_set_up_reg(3 downto 2) is
          when b"00" => 
            adc1_trigger_set_vec(0) <= '1';
            adc2_trigger_set_vec(0) <= '1';
            adc2_trigger_set_vec(0) <= '1';
          when b"10" => 
            adc2_trigger_set_vec(0) <= '1';
          when b"01" => 
            adc1_trigger_set_vec(0) <= '1';
          when b"11" => 
            adc3_trigger_set_vec(0) <= '1';
          when others =>
            null;
        end case;
      else
        adc1_trigger_set_vec(1) <= adc1_trigger_set_vec(0);
        adc2_trigger_set_vec(1) <= adc2_trigger_set_vec(0);
        adc3_trigger_set_vec(1) <= adc3_trigger_set_vec(0);
        adc1_trigger_set_vec(0) <= '0';
        adc2_trigger_set_vec(0) <= '0';
        adc3_trigger_set_vec(0) <= '0';
      end if;
    end if;
  end process;

--adc1_trigger_set_up <= control_reg(4) when trig_set_up_reg(3) = '0' else '0';
--adc2_trigger_set_up <= control_reg(4) when trig_set_up_reg(2) = '0' else '0';

adc1_trigger_set_up <= (not adc1_trigger_set_vec(1)) and adc1_trigger_set_vec(0);
adc2_trigger_set_up <= (not adc2_trigger_set_vec(1)) and adc2_trigger_set_vec(0);
adc3_trigger_set_up <= (not adc3_trigger_set_vec(1)) and adc3_trigger_set_vec(0);

trigger_start <= adc1_trigger_start or adc2_trigger_start or adc3_trigger_start;

QuadSPI_adc_250x4_module_inst : entity QuadSPI_adc_250x4_module
    Port map(
      spifi_cs                  => spifi_cs  ,
      spifi_sck                 => spifi_sck ,
      spifi_miso                => spifi_miso,
      spifi_mosi                => spifi_mosi,
      spifi_sio2                => spifi_sio2,
      spifi_sio3                => spifi_sio3,
      
      clk                       => clk_125MHz,
      rst                       => rst,
      
      adc1_s_strm_data          => adc1_m_strm_data,
      adc1_s_strm_valid         => adc1_m_strm_valid,
      adc1_s_strm_ready         => adc1_m_strm_ready,
      adc1_valid                => adc1_data_valid,
      
      adc1_proc_rst_out         => adc1_capture_module_rst,
      
      adc2_s_strm_data          => adc2_m_strm_data,
      adc2_s_strm_valid         => adc2_m_strm_valid,
      adc2_s_strm_ready         => adc2_m_strm_ready,
      adc2_valid                => adc2_data_valid,

      adc2_proc_rst_out         => adc2_capture_module_rst
    );

spi_fcb_master_inst : entity spi_adc_250x4_master
    generic map(
      C_CPHA            => 1,
      C_CPOL            => 1,
      C_LSB_FIRST       => 0
    )
    Port map( 
      SCK               => fpga_sck,
      CS                => fpga_cs,

      MISO_I            => MISO_I,
      MISO_O            => MISO_O,
      MISO_T            => MISO_T,
      MOSI_I            => MOSI_I,
      MOSI_O            => MOSI_O,
      MOSI_T            => MOSI_T,

      m_fcb_clk         => clk_125MHz,
      m_fcb_areset      => infrst_rst_out,
      m_fcb_addr        => m_fcb_addr   ,
      m_fcb_wrdata      => m_fcb_wrdata ,
      m_fcb_wrreq       => m_fcb_wrreq  ,
      m_fcb_wrack       => m_fcb_wrack  ,
      m_fcb_rddata      => m_fcb_rddata ,
      m_fcb_rdreq       => m_fcb_rdreq  ,
      m_fcb_rdack       => m_fcb_rdack  
    );

OBUFT_inst : OBUFT
   generic map (
      DRIVE => 12,
      IOSTANDARD => "DEFAULT",
      SLEW => "SLOW")
   port map (
      O => fpga_miso,     -- Buffer output (connect directly to top-level port)
      I => MISO_O,     -- Buffer input
      T => MISO_T      -- 3-state enable input 
   );

MOSI_I <= fpga_mosi;

-------------------------------------------------
-- управляющие регистры 
-------------------------------------------------
-- процесс записи/чтения регистров управления
reg_address_int <= conv_integer(m_fcb_addr(6 downto 0));

m_fcb_wr_process :
    process(clk_125MHz)
    begin
      if rising_edge(clk_125MHz) then
        if (infrst_rst_out = '1') then
          wr_req_vec <= (others => '0');
          control_reg(15 downto 0) <= (others => '0');
          trig_set_up_reg(15 downto 8) <= x"7f";
          trig_set_up_reg(3 downto 0) <= (others => '0');
          low_adc_buff_len <= x"2004";
          trig_window_width_reg <= x"0200";
          calib_pattern_reg <= x"55AA";
          adc_calib <= '0';
        elsif (m_fcb_wrreq = '1') then
          m_fcb_wrack <= '1';
          case reg_address_int is
            when 0 => 
              wr_req_vec(0) <= '1';
              trig_set_up_reg(15 downto 2) <= m_fcb_wrdata(15 downto 2);
            when 1 => 
              wr_req_vec(1) <= '1';
              trig_window_width_reg <= m_fcb_wrdata;
            when 2 =>
              wr_req_vec(2) <= '1';
              trig_position_reg <= m_fcb_wrdata;
            when 3 =>
              wr_req_vec(3) <= '1';
              trig_set_up_reg(1 downto 0) <= m_fcb_wrdata(3 downto 2);
              control_reg(1 downto 0) <= m_fcb_wrdata(1 downto 0);
              control_reg(7 downto 4) <= m_fcb_wrdata(7 downto 4);
            when 4 =>
              wr_req_vec(4) <= '1';
              calib_pattern_reg <= m_fcb_wrdata;
            when 5 =>
              wr_req_vec(5) <= '1';
              low_adc_buff_len <= m_fcb_wrdata;
            when 6 => 
              pulse_start <= m_fcb_wrdata(0);
            when others =>
          end case;
        else 
          m_fcb_wrack               <= '0';
          wr_req_vec                <= (others => '0');
          control_reg(15 downto 0)  <= (others => '0');
          pulse_start               <= '0';
          adc_calib                 <= control_reg(0);
        end if;
      end if;
    end process;

--OBUF_inst : OBUF
--   generic map (
--      DRIVE => 8,
--      IOSTANDARD => "LVTTL",
--      SLEW => "slow")
--   port map (
--      O => pulse_out,     -- Buffer output (connect directly to top-level port)
--      I => pulse      -- Buffer input 
--   );

--pulse_out_p <= pulse;
   OBUFDS_inst : OBUFDS
   generic map (
      IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
      SLEW => "SLOW")          -- Specify the output slew rate
   port map (
      O => pulse_out_p,     -- Diff_p output (connect directly to top-level port)
      OB => pulse_out_n,   -- Diff_n output (connect directly to top-level port)
      I => (not pulse)      -- Buffer input 
   );

--pulse_out <= pulse;

pulse_counter_proc :
    process(clk_125MHz)
    begin
      if rising_edge(clk_125MHz) then
        if pulse_start = '1' then
          pulse_counter <= B"011";
        else
          pulse_counter(2 downto 1) <= pulse_counter(1 downto 0);
          pulse_counter(0) <= '0';
        end if;
        pulse <= pulse_counter(2);
      end if;
    end process;

m_fcb_rd_process :
    process(clk_125MHz)
    begin
      if rising_edge(clk_125MHz) then
        if (m_fcb_rdreq = '1') then
          m_fcb_rdack <= '1';
          case reg_address_int is
            when 0 => 
              m_fcb_rddata(15 downto 2) <= trig_set_up_reg(15 downto 2);
            when 1 => 
              m_fcb_rddata <= trig_window_width_reg;
            when 2 =>
              m_fcb_rddata <= trig_position_reg;
            when 3 =>
              m_fcb_rddata(1 downto 0) <= control_reg(1 downto 0);
              m_fcb_rddata(3 downto 2) <= trig_set_up_reg(1 downto 0);
              m_fcb_rddata(14 downto 4)<= control_reg(14 downto 4);
              m_fcb_rddata(15)<= error;
            when 4 =>
              m_fcb_rddata <= calib_pattern_reg;
            when 5 => 
              m_fcb_rddata <= low_adc_buff_len;
            when 6 =>
              m_fcb_rddata(0) <= fclk_pll_lock;
            when 7 =>
              m_fcb_rddata <= ff1_ff2_vec1;
            when others =>
          end case;
        else 
          m_fcb_rdack <= '0';
        end if;
      end if;
    end process;



end Behavioral;
