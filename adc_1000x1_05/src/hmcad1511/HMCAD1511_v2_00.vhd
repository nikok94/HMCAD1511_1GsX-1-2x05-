----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.04.2019 12:34:53
-- Design Name: 
-- Module Name: HMCAD1511_v2_00 - Behavioral
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
use work.lvds_deserializer;
use work.high_speed_clock_to_serdes;
--use work.adc1_ila;
--use work.adc1_icon;
--use work.adc1_vio;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity HMCAD1511_v2_00 is
    Port (
      LCLKp                 : in std_logic;
      LCLKn                 : in std_logic;

      FCLKp                 : in std_logic;
      FCLKn                 : in std_logic;

      DxXAp                 : in std_logic_vector(3 downto 0);
      DxXAn                 : in std_logic_vector(3 downto 0);
      DxXBp                 : in std_logic_vector(3 downto 0);
      DxXBn                 : in std_logic_vector(3 downto 0);

--      CAL                   : in std_logic;
--      CAL_DONE              : out std_logic;
--      CLK                   : in std_logic;
--      ARESET                : in std_logic;

      M_STRM_VALID          : out std_logic;
      M_STRM_DATA           : out std_logic_vector(63 downto 0);
      DIVCLK_OUT            : out std_logic
    );
end HMCAD1511_v2_00;

architecture Behavioral of HMCAD1511_v2_00 is

    type   adc_data is array(3 downto 0) of std_logic_vector(7 downto 0);
    signal adc_data_a_8bit                  : adc_data;
    signal adc_data_b_8bit                  : adc_data;
    signal frame_pattern                    : std_logic_vector(7 downto 0);
    signal high_speed_clk                   : std_logic;
    signal ioclk0                           : std_logic;
    signal ioclk1                           : std_logic;
    signal serdesstrobe                     : std_logic;
    signal IOCLK0_1                         : std_logic;
    signal IOCLK1_1                         : std_logic;
    signal serdesstrobe_1                   : std_logic;
    signal div_clk_bufg_0                   : std_logic;
    signal div_clk                     : std_logic;
    signal pll_clkfbout                     : std_logic;
    signal pll_clkfbout_bufg                : std_logic;
    signal pll_clkfbin                      : std_logic;
    signal pll_locked                       : std_logic;
    signal pll_clkout0_125MHz               : std_logic;
    signal lvds_deserializers_busy_vec      : std_logic_vector(7 downto 0);
    signal lvds_deserializers_busy          : std_logic;
    signal lvds_deserializers_busy_d        : std_logic;
    signal lvds_deserializers_busy_edge     : std_logic;
    signal lvds_deserializers_busy_fall     : std_logic;
    signal cal_in                           : std_logic;
    signal cal_in_d1                        : std_logic;
    signal cal_in_d2                        : std_logic;
    signal cal_in_d3                        : std_logic;
    signal cal_in_sync                      : std_logic;
    signal data_out_valid                   : std_logic;
    signal data_out_valid_d1                : std_logic;
    signal data_out_valid_d2                : std_logic;
    signal data_out_valid_d3                : std_logic;
    signal cal_done_sync                    : std_logic;
    signal iodelay_clk                      : std_logic;
    signal iodelay_inc                      : std_logic;
    signal iodelay_ce                       : std_logic;
    signal iodelay_cal                      : std_logic;
    signal iodelay_rst                      : std_logic:= '1';
    signal iodelay_calib                    : std_logic;
    signal adc1_ila_control                 : std_logic_vector(35 downto 0);
    signal adc1_vio_control                 : std_logic_vector(35 downto 0);
    signal vio_calib_vector                 : std_logic_vector(3 downto 0);
    signal vio_calib_vector_d               : std_logic_vector(3 downto 0);
    signal data_out                         : std_logic_vector(63 downto 0);
    

begin
DIVCLK_OUT <= div_clk;
M_STRM_VALID <= data_out_valid;







iodelay_clk <= div_clk;

IBUFGDS_LCLK_inst : IBUFGDS
   generic map (
      IBUF_LOW_PWR => TRUE,     -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
      IOSTANDARD   => "DEFAULT")
   port map (
      O  => high_speed_clk,     -- Clock buffer output
      I  => LCLKp,              -- Diff_p clock buffer input
      IB => LCLKn               -- Diff_n clock buffer input
   );

high_speed_clock_to_serdes_inst : entity high_speed_clock_to_serdes
    Port map( 
        in_clk_from_bufg    => high_speed_clk,
        div_clk_bufg        => div_clk,
        serdesclk0          => ioclk0,
        serdesclk1          => ioclk1,
        serdesstrobe        => serdesstrobe
    );

FCLK_deserializer_inst : entity lvds_deserializer
    Port map( 
      data_in_p             => FCLKp,
      data_in_n             => FCLKn,
      ioclk0                => ioclk0,
      ioclk1                => ioclk1,
      clkdiv                => div_clk,
      serdesstrobe          => serdesstrobe,
      
      iodelay_clk           => iodelay_clk,
      iodelay_inc           => iodelay_inc,
      iodelay_ce            => iodelay_ce ,
      iodelay_cal           => iodelay_cal,
      iodelay_rst           => iodelay_rst,
      
      data_8bit_out         => frame_pattern
    );

adc_deserializer_gen : for i in 0 to 3 generate
lvds_deserializer_a_inst: entity lvds_deserializer
    Port map( 
      data_in_p             => DxXAp(i),
      data_in_n             => DxXAn(i),
      ioclk0                => ioclk0,
      ioclk1                => ioclk1,
      clkdiv                => div_clk,
      serdesstrobe          => serdesstrobe,
      
      iodelay_clk           => iodelay_clk,
      iodelay_inc           => iodelay_inc,
      iodelay_ce            => iodelay_ce ,
      iodelay_cal           => iodelay_cal,
      iodelay_rst           => iodelay_rst,
      
      data_8bit_out         => adc_data_a_8bit(i)
    );

lvds_deserializer_b_inst: entity lvds_deserializer
    Port map( 
      data_in_p             => DxXBp(i),
      data_in_n             => DxXBn(i),
      ioclk0                => ioclk0,
      ioclk1                => ioclk1,
      clkdiv                => div_clk,
      serdesstrobe          => serdesstrobe,
      
      iodelay_clk           => iodelay_clk,
      iodelay_inc           => iodelay_inc,
      iodelay_ce            => iodelay_ce ,
      iodelay_cal           => iodelay_cal,
      iodelay_rst           => iodelay_rst,

      data_8bit_out         => adc_data_b_8bit(i)
    );
end generate;

    M_STRM_DATA <= data_out;
    data_out    <= adc_data_b_8bit(3) & adc_data_a_8bit(3) & 
                   adc_data_b_8bit(2) & adc_data_a_8bit(2) & 
                   adc_data_b_8bit(1) & adc_data_a_8bit(1) & 
                   adc_data_b_8bit(0) & adc_data_a_8bit(0);


end Behavioral;
