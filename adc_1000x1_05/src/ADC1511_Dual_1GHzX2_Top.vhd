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
use work.HMCAD1511_x2_v1_00;
use work.clock_generator;
use work.spi_adc_250x4_master;
--use work.fifo_sream;
use work.async_fifo_64;
use work.trigger_capture;
--use work.data_capture_module;
use work.data_capture;
use work.QuadSPI_adc_250x4_module;
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
    signal serdesclk0_1                 : std_logic;
    signal serdesclk1_1                 : std_logic;
    signal serdesstrobe_1               : std_logic;
    signal serdesclk0_2                 : std_logic;
    signal serdesclk1_2                 : std_logic;
    signal serdesstrobe_2               : std_logic;
begin

rst <= infrst_rst_out or control_reg(1);

sys_rst <= (not xc_sys_rstn);

Clock_gen_inst : entity clock_generator
    Port map( 
      clk_in            => in_clk_50MHz,
      rst_in            => sys_rst,
      pll_lock          => pll_lock,
      clk_out_125MHz    => clk_125MHz,
      clk_out_250MHz    => clk_250MHz, 
      rst_out           => infrst_rst_out
    );

main_pll_lock <= pll_lock;

adc_calib_done <= adc1_valid and adc2_valid;

--adc1_data_receiver : entity HMCAD1511_v3_00
--    Port map(
--      LCLKp                 => adc1_lclk_p,
--      LCLKn                 => adc1_lclk_n,
--
--      FCLKp                 => adc1_fclk_p,
--      FCLKn                 => adc1_fclk_n,
--
--      DxXAp                 => adc1_dx_a_p,
--      DxXAn                 => adc1_dx_a_n,
--      DxXBp                 => adc1_dx_b_p,
--      DxXBn                 => adc1_dx_b_n,
--      
--      reset                 => rst,
--      m_strm_valid          => adc1_valid,
--      m_strm_data           => adc1_data,
--      bsleep_counter        => bitsleep_counter1,
--      gclk_o                => adc1_clk_div8,
--      serdesclk0_o          => serdesclk0_1,
--      serdesclk1_o          => serdesclk1_1,
--      serdesstrobe_o        => serdesstrobe_1,
--      
--      frame                 => frame1,
--      lclk_obuf             => lclk1,
--      fclk_obuf             => fclk1
--    );
--
--
--adc2_data_receiver : entity HMCAD1511_v3_00
--    Port map(
--      LCLKp                 => adc2_lclk_p,
--      LCLKn                 => adc2_lclk_n,
--
--      FCLKp                 => adc2_fclk_p,
--      FCLKn                 => adc2_fclk_n,
--
--      DxXAp                 => adc2_dx_a_p,
--      DxXAn                 => adc2_dx_a_n,
--      DxXBp                 => adc2_dx_b_p,
--      DxXBn                 => adc2_dx_b_n,
--
--      reset                 => rst,
--      m_strm_valid          => adc2_valid,
--      m_strm_data           => adc2_data,
--      bsleep_counter        => bitsleep_counter2,
--      gclk_o                => adc2_clk_div8,
--      serdesclk0_o          => serdesclk0_2,
--      serdesclk1_o          => serdesclk1_2,
--      serdesstrobe_o        => serdesstrobe_2,
--
--      frame                 => frame2,
--      lclk_obuf             => lclk2,
--      fclk_obuf             => fclk2
--    );

adc_data_receiver   :  entity HMCAD1511_x2_v1_00
    Port map(
      LCLKp_1               => adc1_lclk_p,
      LCLKn_1               => adc1_lclk_n,
                            
      FCLKp_1               => adc1_fclk_p,
      FCLKn_1               => adc1_fclk_n,
                            
      DxXAp_1               => adc1_dx_a_p,
      DxXAn_1               => adc1_dx_a_n,
      DxXBp_1               => adc1_dx_b_p,
      DxXBn_1               => adc1_dx_b_n,

      LCLKp_2               => adc2_lclk_p,
      LCLKn_2               => adc2_lclk_n,
                            
      FCLKp_2               => adc2_fclk_p,
      FCLKn_2               => adc2_fclk_n,
                            
      DxXAp_2               => adc2_dx_a_p,
      DxXAn_2               => adc2_dx_a_n,
      DxXBp_2               => adc2_dx_b_p,
      DxXBn_2               => adc2_dx_b_n,

      reset                 => rst,
      m1_clk_o              => adc1_clk_div8,
      m1_strm_valid         => adc1_valid,
      m1_strm_data          => adc1_data,
      
      m2_clk_o              => adc2_clk_div8,
      m2_strm_valid         => adc2_valid,
      m2_strm_data          => adc2_data,
      
      frame_patter1         => frame1,
      frame_patter2         => frame2
    );

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

adc_receivers_rst_proc :
    process(clk_125MHz, rst)
    begin
      if (rst = '1') then
        adc_receiver_rst_vect <= (others => '0');
      elsif rising_edge(clk_125MHz) then
        if control_reg(5) = '1' then
          adc_receiver_rst_vect <= (others => '1');
        else
          adc_receiver_rst_vect(7 downto 1) <= adc_receiver_rst_vect(6 downto 0);
          adc_receiver_rst_vect(0) <= '0';
        end if;
      end if;
    end process;

adc_receiver_rst    <= adc_receiver_rst_vect(7);

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
        if (infrst_rst_out = '1') then
        elsif (m_fcb_rdreq = '1') then
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
              m_fcb_rddata(15 downto 0) <= frame2 & frame1;
            when others =>
          end case;
        else 
          m_fcb_rdack <= '0';
        end if;
      end if;
    end process;

--ila1_inst : ENTITY ila
--  port map(
--    CONTROL => control_0,
--    CLK     => clk_125MHz,
--    DATA    => adc2_fifo_m_rd_data_cntr & adc1_fifo_m_rd_data_cntr & adc2_sync_data & adc1_sync_data & adc2_sync_valid & adc1_sync_valid & trigger_start,
--    TRIG0   => adc2_sync_valid & adc1_sync_valid & trigger_start 
--    );
--
--ila1_data_adc1 : ENTITY ila_data_in
--  port map(
--    CONTROL => control_1,
--    CLK     => adc1_clk_div8,
--    TRIG0   => adc1_data & adc1_valid & trigger_start 
--    );
--
--ila1_data_adc2 : ENTITY ila_data_in
--  port map(
--    CONTROL => control_2,
--    CLK     => adc1_clk_div8,
--    TRIG0   => adc2_data & adc2_valid & trigger_start 
--    );
--    
--icon_inst : entity icon
--  port map (
--    CONTROL0    => control_0,
--    CONTROL1    => control_1,
--    CONTROL2    => control_2
--    );

end Behavioral;
