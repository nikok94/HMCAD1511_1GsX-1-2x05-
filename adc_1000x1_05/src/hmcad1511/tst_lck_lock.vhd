----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.03.2019 17:22:10
-- Design Name: 
-- Module Name: tst_lck_lock - Behavioral
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

library work;
use work.ila;
use work.chipscope_icon_v1_06_a_0;
use work.lvds_deserializer;
use work.high_speed_clock_to_serdes;
use work.chipscope_vio;

entity tst_lck_lock is
    Port (
        in_clk_20MHz    : in std_logic;
--        calib           : in std_logic;
       -- adc_fclk_p      : in std_logic;
       -- adc_fclk_n      : in std_logic;
        adc_lck_p       : in std_logic;
        adc_lck_n       : in std_logic;
        adc_dx_a_p      : in std_logic_vector(3 downto 0);
        adc_dx_a_n      : in std_logic_vector(3 downto 0);
        adc_dx_b_p      : in std_logic_vector(3 downto 0);
        adc_dx_b_n      : in std_logic_vector(3 downto 0)
        
        );
end tst_lck_lock;

architecture Behavioral of tst_lck_lock is
    type adc_data is array(3 downto 0) of std_logic_vector(7 downto 0);
    signal adc_data_a_8bit  : adc_data;
    signal adc_data_b_8bit  : adc_data;
    signal BUFIO2_divclk_1                          : std_logic;
    signal IOCLK0_0                         : std_logic;
    signal IOCLK1_0                         : std_logic;
    signal serdesstrobe_0              : std_logic;
    signal BUFIO2_divclk_2                          : std_logic;
    signal IOCLK0_1                         : std_logic;
    signal IOCLK1_1                         : std_logic;
    signal serdesstrobe_1              : std_logic;

    signal ila_control                              : std_logic_vector(35 downto 0);
    signal div_clk_bufg_0                           : std_logic;
    signal div_clk_bufg_1                           : std_logic;
	
	signal vio_calib_vector							: std_logic_vector(7 downto 0);
	signal vio_calib_control					    : std_logic_vector(35 downto 0);
	
	signal vio_bitslip_vector					    : std_logic_vector(7 downto 0);
	signal vio_bitslip_control					    : std_logic_vector(35 downto 0);

    signal adc_lck_p_ibufg_df                       : std_logic;
    signal adc_lck_n_ibufg_df                       : std_logic;
	
	signal adc_lck_bufg							    : std_logic;
	
	signal CLKFBIN									: std_logic;
	signal CLKFBOUT									: std_logic;
    
    signal CLK_100MHz                               : std_logic;
    signal pll_clk0                                 : std_logic;
    
    signal bitslip_sync_vect                        : std_logic_vector(3 downto 0);
    signal bitslip                                  : std_logic;
    signal calib_sync_vect                          : std_logic_vector(3 downto 0);
    signal iodelay_calib                            : std_logic;
    signal ce_sync_vect                             : std_logic_vector(3 downto 0);
    signal iodelay_ce                               : std_logic;
    signal iodelay_inc                              : std_logic;
    
    signal adc_fclk_bufg                            : std_logic;
    signal fclk_bufio                               : std_logic;

begin

PLL_BASE_inst : PLL_BASE
   generic map (
      BANDWIDTH => "OPTIMIZED",             -- "HIGH", "LOW" or "OPTIMIZED" 
      CLKFBOUT_MULT => 20,                   -- Multiply value for all CLKOUT clock outputs (1-64)
      CLKFBOUT_PHASE => 0.0,                -- Phase offset in degrees of the clock feedback output
                                            -- (0.0-360.0).
      CLKIN_PERIOD => 50.0,                  -- Input clock period in ns to ps resolution (i.e. 33.333 is 30
                                            -- MHz).
      -- CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for CLKOUT# clock output (1-128)
      CLKOUT0_DIVIDE => 4,
      CLKOUT1_DIVIDE => 1,
      CLKOUT2_DIVIDE => 1,
      CLKOUT3_DIVIDE => 1,
      CLKOUT4_DIVIDE => 1,
      CLKOUT5_DIVIDE => 1,
      -- CLKOUT0_DUTY_CYCLE - CLKOUT5_DUTY_CYCLE: Duty cycle for CLKOUT# clock output (0.01-0.99).
      CLKOUT0_DUTY_CYCLE => 0.5,
      CLKOUT1_DUTY_CYCLE => 0.5,
      CLKOUT2_DUTY_CYCLE => 0.5,
      CLKOUT3_DUTY_CYCLE => 0.5,
      CLKOUT4_DUTY_CYCLE => 0.5,
      CLKOUT5_DUTY_CYCLE => 0.5,
      -- CLKOUT0_PHASE - CLKOUT5_PHASE: Output phase relationship for CLKOUT# clock output (-360.0-360.0).
      CLKOUT0_PHASE => 0.0,
      CLKOUT1_PHASE => 0.0,
      CLKOUT2_PHASE => 0.0,
      CLKOUT3_PHASE => 0.0,
      CLKOUT4_PHASE => 0.0,
      CLKOUT5_PHASE => 0.0,
      CLK_FEEDBACK => "CLKFBOUT",           -- Clock source to drive CLKFBIN ("CLKFBOUT" or "CLKOUT0")
      COMPENSATION => "SYSTEM_SYNCHRONOUS", -- "SYSTEM_SYNCHRONOUS", "SOURCE_SYNCHRONOUS", "EXTERNAL" 
      DIVCLK_DIVIDE => 1,                   -- Division value for all output clocks (1-52)
      REF_JITTER => 0.1,                    -- Reference Clock Jitter in UI (0.000-0.999).
      RESET_ON_LOSS_OF_LOCK => FALSE        -- Must be set to FALSE
   )
   port map (
      CLKFBOUT => CLKFBOUT, -- 1-bit output: PLL_BASE feedback output
      -- CLKOUT0 - CLKOUT5: 1-bit (each) output: Clock outputs
      CLKOUT0 => pll_clk0,
      CLKOUT1 => open,
      CLKOUT2 => open,
      CLKOUT3 => open,
      CLKOUT4 => open,
      CLKOUT5 => open,
      LOCKED => open,     -- 1-bit output: PLL_BASE lock status output
      CLKFBIN => CLKFBIN,   -- 1-bit input: Feedback clock input
      CLKIN => in_clk_20MHz,       -- 1-bit input: Clock input
      RST => '0'            -- 1-bit input: Reset input
   );
    
    bufg_inst : BUFG port map ( I => pll_clk0, O => CLK_100MHz);
   CLKFBIN <= CLKFBOUT;

--IBUFGDS_FCLK_inst : IBUFGDS
--   generic map (
--      IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
--      IOSTANDARD => "DEFAULT")
--   port map (
--      O => adc_lck_bufg,  -- Clock buffer output
--      I => adc_fclk_p,  -- Diff_p clock buffer input
--      IB => adc_fclk_n -- Diff_n clock buffer input
--   );
--
--BUFIO2_FCLK_inst : BUFIO2
--   generic map (
--      DIVIDE => 1,           -- DIVCLK divider (1,3-8)
--      DIVIDE_BYPASS => TRUE, -- Bypass the divider circuitry (TRUE/FALSE)
--      I_INVERT => FALSE,     -- Invert clock (TRUE/FALSE)
--      USE_DOUBLER => FALSE   -- Use doubler circuitry (TRUE/FALSE)
--   )
--   port map (
--      DIVCLK => DIVCLK,             -- 1-bit output: Divided clock output
--      IOCLK => open,               -- 1-bit output: I/O output clock
--      SERDESSTROBE => open, -- 1-bit output: Output SERDES strobe (connect to ISERDES2/OSERDES2)
--      I => adc_fclk_bufg            -- 1-bit input: Clock input (connect to IBUFG)
--   );

IBUFGDS_CLK_inst : IBUFGDS
   generic map (
      IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
      IOSTANDARD => "DEFAULT")
   port map (
      O => adc_lck_bufg,  -- Clock buffer output
      I => adc_lck_p,  -- Diff_p clock buffer input
      IB => adc_lck_n -- Diff_n clock buffer input
   );

high_speed_clock_to_serdes_1 : entity high_speed_clock_to_serdes
    Port map( 
        in_clk_from_bufg    => adc_lck_bufg,
        div_clk_bufg        => div_clk_bufg_0,
        serdesclk0          => IOCLK0_0,
        serdesclk1          => IOCLK1_0,
        serdesstrobe        => serdesstrobe_0
    );

high_speed_clock_to_serdes_2 : entity high_speed_clock_to_serdes
    Port map( 
        in_clk_from_bufg    => adc_lck_bufg,
        div_clk_bufg        => div_clk_bufg_1,
        serdesclk0          => IOCLK0_1,
        serdesclk1          => IOCLK1_1,
        serdesstrobe        => serdesstrobe_1
    );

 
adc_deserializer_gen1 : for i in 0 to 1 generate
lvds_deserializer_a_inst: entity lvds_deserializer
    Port map( 
      data_in_p             => adc_dx_a_p(i),
      data_in_n             => adc_dx_a_n(i),
      ioclk0          		=> IOCLK0_0,
      ioclk1          		=> IOCLK1_0,
      clkdiv         		=> div_clk_bufg_0,
      serdesstrobe   		=> serdesstrobe_0,
      
      data_8bit_out         => adc_data_a_8bit(i),
	  start_calib           => iodelay_calib,
      calib_busy            => open,
	  rst					=> '0'
    );

lvds_deserializer_b_inst: entity lvds_deserializer
    Port map( 
      data_in_p             => adc_dx_b_p(i),
      data_in_n             => adc_dx_b_n(i),
      ioclk0         		=> IOCLK0_0,
      ioclk1         		=> IOCLK1_0,
      clkdiv         		=> div_clk_bufg_0,
      serdesstrobe   		=> serdesstrobe_0,
      data_8bit_out         => adc_data_b_8bit(i),
	  start_calib           => iodelay_calib,
      calib_busy            => open,
	  rst					=> '0'
    );
end generate;

adc_deserializer_gen2 : for i in 2 to 3 generate
lvds_deserializer_a_inst: entity lvds_deserializer
    Port map( 
      data_in_p             => adc_dx_a_p(i),
      data_in_n             => adc_dx_a_n(i),
      ioclk0        		=> IOCLK0_1,
      ioclk1        		=> IOCLK1_1,
      clkdiv        		=> div_clk_bufg_1,
      serdesstrobe  		=> serdesstrobe_1,
      data_8bit_out         => adc_data_a_8bit(i),
	  start_calib           => iodelay_calib,
      calib_busy            => open,
	  rst					=> '0'
    );

lvds_deserializer_b_inst: entity lvds_deserializer
    Port map( 
      data_in_p             => adc_dx_b_p(i),
      data_in_n             => adc_dx_b_n(i),
      ioclk0         		=> IOCLK0_1,
      ioclk1         		=> IOCLK1_1,
      clkdiv         		=> div_clk_bufg_1,
      serdesstrobe   		=> serdesstrobe_1,
      data_8bit_out         => adc_data_b_8bit(i),
	  start_calib           => iodelay_calib,
      calib_busy            => open,
	  rst					=> '0'
    );
end generate;

bitslip_process :
    process(div_clk_bufg_0)
    begin
      if rising_edge(div_clk_bufg_0) then
        bitslip_sync_vect(3 downto 1) <= bitslip_sync_vect( 2 downto 0);
        bitslip_sync_vect(0) <= vio_calib_vector(3);
        bitslip <= (not bitslip_sync_vect(3)) and bitslip_sync_vect(2);
      end if;
    end process;


calib_process :
    process(div_clk_bufg_0)
    begin
      if rising_edge(div_clk_bufg_0) then
        calib_sync_vect(3 downto 1) <= calib_sync_vect( 2 downto 0);
        calib_sync_vect(0) <= vio_calib_vector(0);
        iodelay_calib <= (not calib_sync_vect(3)) and calib_sync_vect(2);
      end if;
    end process;
    
ce_process :
    process(div_clk_bufg_0)
    begin
      if rising_edge(div_clk_bufg_0) then
        ce_sync_vect(3 downto 1) <= ce_sync_vect( 2 downto 0);
        ce_sync_vect(0) <= vio_calib_vector(2);
        iodelay_ce <= (not ce_sync_vect(3)) and ce_sync_vect(2);
      end if;
    end process;

ila_inst : ENTITY ila
  port map(
    CONTROL => ila_control,
    CLK     => div_clk_bufg_0,
    DATA    => adc_data_b_8bit(3) & adc_data_a_8bit(3)& adc_data_b_8bit(2) & adc_data_a_8bit(2) & adc_data_b_8bit(1) & adc_data_a_8bit(1) & adc_data_b_8bit(0) & adc_data_a_8bit(0),
    TRIG0(0)   => '0'
    );

icon_inst : ENTITY chipscope_icon_v1_06_a_0 
  port map(
    CONTROL0    => ila_control,
    CONTROL1    => vio_calib_control--,
--    CONTROL2    => vio_bitslip_control
    );

vio_calib_inst :ENTITY chipscope_vio
  port map(
    CONTROL		=> vio_calib_control,
    CLK			=> div_clk_bufg_0,
    SYNC_IN		=> vio_calib_vector,
    SYNC_OUT	=> vio_calib_vector
    );

--vio_bitslip_inst :ENTITY chipscope_vio
--  port map(
--    CONTROL		=> vio_bitslip_control,
--    CLK			=> div_clk_bufg_0,
--    SYNC_IN		=> vio_bitslip_vector,
--    SYNC_OUT	=> vio_bitslip_vector
--	);
 

end Behavioral;
