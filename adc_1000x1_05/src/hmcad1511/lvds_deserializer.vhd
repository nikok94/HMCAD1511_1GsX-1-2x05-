----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01.04.2019 10:48:03
-- Design Name: 
-- Module Name: lvds_deserializer - Behavioral
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

entity lvds_deserializer is
    Port ( 
      data_in_p             : in std_logic;
      data_in_n             : in std_logic;
      ioclk0                : in std_logic;
      ioclk1                : in std_logic;
      clkdiv                : in std_logic;
      serdesstrobe          : in std_logic;
      
      iodelay_clk           : in std_logic;
      iodelay_inc           : in std_logic;
      iodelay_ce            : in std_logic;
      iodelay_cal           : in std_logic;
      iodelay_rst           : in std_logic;
      
      data_8bit_out         : out std_logic_vector(7 downto 0)
    );
end lvds_deserializer;

architecture Behavioral of lvds_deserializer is
    type calib_state_machine is (idle, compare, serdes_bitslip, wait1, wait2, wait3);
    signal state, next_state : calib_state_machine;
    signal serial_data_in               : std_logic;
    signal serial_data_in_delay_m       : std_logic;
    signal serial_data_in_delay_s       : std_logic;
    signal slave_iserdes_shifth_out     : std_logic;
    signal master_iserdes_shifth_out    : std_logic;    
    signal master_dly_busy              : std_logic;
    signal slave_dly_busy               : std_logic;
    signal serdes_out_8bit              : std_logic_vector(7 downto 0);
    signal counter_data_rate            : std_logic_vector(1 downto 0):= "00";
    signal calib_data_valid             : std_logic;
    signal calib_data_0                 : std_logic_vector(7 downto 0);
    signal calib_data_0_sts             : std_logic;
    signal calib_data_1                 : std_logic_vector(7 downto 0);
    signal calib_data_1_sts             : std_logic;
    signal calib_data_0_delay           : std_logic_vector(7 downto 0);
    signal calib_data_1_delay           : std_logic_vector(7 downto 0);
    signal bitslip                      : std_logic;

begin
data_8bit_out <= serdes_out_8bit;

IBUFDS_inst : IBUFDS
   generic map (
      DIFF_TERM => FALSE, -- Differential Termination 
      IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
      IOSTANDARD => "DEFAULT")
   port map (
      O => serial_data_in,  -- Buffer output
      I => data_in_p,  -- Diff_p buffer input (connect directly to top-level port)
      IB => data_in_n -- Diff_n buffer input (connect directly to top-level port)
   );

MASTER_IODELAY2_INST : IODELAY2
   generic map (
      COUNTER_WRAPAROUND => "WRAPAROUND", -- "STAY_AT_LIMIT" or "WRAPAROUND" 
      DATA_RATE => "DDR",                 -- "SDR" or "DDR" 
      DELAY_SRC => "IDATAIN",                  -- "IO", "ODATAIN" or "IDATAIN" 
      IDELAY2_VALUE => 0,                 -- Delay value when IDELAY_MODE="PCI" (0-255)
      IDELAY_MODE => "NORMAL",            -- "NORMAL" or "PCI" 
      IDELAY_TYPE => "VARIABLE_FROM_ZERO",           -- "FIXED", "DEFAULT", "VARIABLE_FROM_ZERO", "VARIABLE_FROM_HALF_MAX" 
                                          -- or "DIFF_PHASE_DETECTOR" 
      IDELAY_VALUE => 0,                  -- Amount of taps for fixed input delay (0-255)
      ODELAY_VALUE => 0,                  -- Amount of taps fixed output delay (0-255)
      SERDES_MODE => "MASTER",              -- "NONE", "MASTER" or "SLAVE" 
      SIM_TAPDELAY_VALUE => 75            -- Per tap delay used for simulation in ps
   )
   port map (
      BUSY => master_dly_busy,         -- 1-bit output: Busy output after CAL
      DATAOUT => serial_data_in_delay_m,   -- 1-bit output: Delayed data output to ISERDES/input register
      DATAOUT2 => open, -- 1-bit output: Delayed data output to general FPGA fabric
      DOUT => open,         -- 1-bit output: Delayed data output
      TOUT => open,         -- 1-bit output: Delayed 3-state output
      CAL => iodelay_cal,           -- 1-bit input: Initiate calibration input
      CE => iodelay_ce,             -- 1-bit input: Enable INC input
      CLK => iodelay_clk,           -- 1-bit input: Clock input
      IDATAIN => serial_data_in,   -- 1-bit input: Data input (connect to top-level port or I/O buffer)
      INC => iodelay_inc,           -- 1-bit input: Increment / decrement input
      IOCLK0 => ioclk0,     -- 1-bit input: Input from the I/O clock network
      IOCLK1 => ioclk1,     -- 1-bit input: Input from the I/O clock network
      ODATAIN => '0',   -- 1-bit input: Output data input from output register or OSERDES2.
      RST => iodelay_rst,           -- 1-bit input: Reset to zero or 1/2 of total delay period
      T => '1'                -- 1-bit input: 3-state input signal
   );

SLAVE_IODELAY2_INST : IODELAY2
   generic map (
      COUNTER_WRAPAROUND => "WRAPAROUND", -- "STAY_AT_LIMIT" or "WRAPAROUND" 
      DATA_RATE => "DDR",                 -- "SDR" or "DDR" 
      DELAY_SRC => "IDATAIN",             -- "IO", "ODATAIN" or "IDATAIN" 
      IDELAY2_VALUE => 0,                 -- Delay value when IDELAY_MODE="PCI" (0-255)
      IDELAY_MODE => "NORMAL",            -- "NORMAL" or "PCI" 
      IDELAY_TYPE => "VARIABLE_FROM_ZERO",-- "FIXED", "DEFAULT", "VARIABLE_FROM_ZERO", "VARIABLE_FROM_HALF_MAX" 
                                          -- or "DIFF_PHASE_DETECTOR" 
      IDELAY_VALUE => 0,                  -- Amount of taps for fixed input delay (0-255)
      ODELAY_VALUE => 0,                  -- Amount of taps fixed output delay (0-255)
      SERDES_MODE => "SLAVE",              -- "NONE", "MASTER" or "SLAVE" 
      SIM_TAPDELAY_VALUE => 75            -- Per tap delay used for simulation in ps
   )
   port map (
      BUSY => slave_dly_busy,         -- 1-bit output: Busy output after CAL
      DATAOUT => serial_data_in_delay_s ,   -- 1-bit output: Delayed data output to ISERDES/input register
      DATAOUT2 => open, -- 1-bit output: Delayed data output to general FPGA fabric
      DOUT => open,         -- 1-bit output: Delayed data output
      TOUT => open,         -- 1-bit output: Delayed 3-state output
      CAL => iodelay_cal,           -- 1-bit input: Initiate calibration input
      CE => iodelay_ce,             -- 1-bit input: Enable INC input
      CLK => iodelay_clk,           -- 1-bit input: Clock input
      IDATAIN => serial_data_in,   -- 1-bit input: Data input (connect to top-level port or I/O buffer)
      INC => iodelay_inc,           -- 1-bit input: Increment / decrement input
      IOCLK0 => ioclk0,     -- 1-bit input: Input from the I/O clock network
      IOCLK1 => ioclk1,     -- 1-bit input: Input from the I/O clock network
      ODATAIN => '0',   -- 1-bit input: Output data input from output register or OSERDES2.
      RST => iodelay_rst,           -- 1-bit input: Reset to zero or 1/2 of total delay period
      T => '1'                -- 1-bit input: 3-state input signal
   );

MASTER_ISERDES2 : ISERDES2
   generic map (
      BITSLIP_ENABLE => true,        -- Enable Bitslip Functionality (TRUE/FALSE)
      DATA_RATE => "DDR",             -- Data-rate ("SDR" or "DDR")
      DATA_WIDTH => 8,                -- Parallel data width selection (2-8)
      INTERFACE_TYPE => "NETWORKING_PIPELINED", -- "NETWORKING", "NETWORKING_PIPELINED" or "RETIMED" 
      SERDES_MODE => "NONE"           -- "NONE", "MASTER" or "SLAVE" 
   )
   port map (
      CFB0 => open,           -- 1-bit output: Clock feed-through route output
      CFB1 => open,           -- 1-bit output: Clock feed-through route output
      DFB => open,             -- 1-bit output: Feed-through clock output
      FABRICOUT => open, -- 1-bit output: Unsynchrnonized data output
      INCDEC => open,       -- 1-bit output: Phase detector output
      -- Q1 - Q4: 1-bit (each) output: Registered outputs to FPGA logic
      Q1 => serdes_out_8bit(4),
      Q2 => serdes_out_8bit(5),
      Q3 => serdes_out_8bit(6),
      Q4 => serdes_out_8bit(7),
      SHIFTOUT => master_iserdes_shifth_out,   -- 1-bit output: Cascade output signal for master/slave I/O
      VALID => open,         -- 1-bit output: Output status of the phase detector
      BITSLIP => bitslip,     -- 1-bit input: Bitslip enable input
      CE0 => '1',             -- 1-bit input: Clock enable input
      CLK0 => ioclk0,           -- 1-bit input: I/O clock network input
      CLK1 => ioclk1,           -- 1-bit input: Secondary I/O clock network input
      CLKDIV => clkdiv,       -- 1-bit input: FPGA logic domain clock input
      D => serial_data_in_delay_m,                 -- 1-bit input: Input data
      IOCE => serdesstrobe,           -- 1-bit input: Data strobe input
      RST => rst,                               -- 1-bit input: Asynchronous reset input
      SHIFTIN => slave_iserdes_shifth_out       -- 1-bit input: Cascade input signal for master/slave I/O
   );

SLAVE_ISERDES2 : ISERDES2
   generic map (
      BITSLIP_ENABLE => false,        -- Enable Bitslip Functionality (TRUE/FALSE)
      DATA_RATE => "DDR",             -- Data-rate ("SDR" or "DDR")
      DATA_WIDTH => 8,                -- Parallel data width selection (2-8)
      INTERFACE_TYPE => "NETWORKING_PIPELINED", -- "NETWORKING", "NETWORKING_PIPELINED" or "RETIMED" 
      SERDES_MODE => "SLAVE"           -- "NONE", "MASTER" or "SLAVE" 
   )
   port map (
      CFB0 => open,           -- 1-bit output: Clock feed-through route output
      CFB1 => open,           -- 1-bit output: Clock feed-through route output
      DFB => open,             -- 1-bit output: Feed-through clock output
      FABRICOUT => open, -- 1-bit output: Unsynchrnonized data output
      INCDEC => open,       -- 1-bit output: Phase detector output
      -- Q1 - Q4: 1-bit (each) output: Registered outputs to FPGA logic
      Q1 => serdes_out_8bit(0),
      Q2 => serdes_out_8bit(1),
      Q3 => serdes_out_8bit(2),
      Q4 => serdes_out_8bit(3),
      SHIFTOUT => slave_iserdes_shifth_out,   -- 1-bit output: Cascade output signal for master/slave I/O
      VALID => open,         -- 1-bit output: Output status of the phase detector
      BITSLIP => bitslip,     -- 1-bit input: Bitslip enable input
      CE0 => '1',             -- 1-bit input: Clock enable input
      CLK0 => ioclk0,           -- 1-bit input: I/O clock network input
      CLK1 => ioclk1,           -- 1-bit input: Secondary I/O clock network input
      CLKDIV => clkdiv,       -- 1-bit input: FPGA logic domain clock input
      D => serial_data_in_delay_s,                 -- 1-bit input: Input data
      IOCE => serdesstrobe,           -- 1-bit input: Data strobe input
      RST => rst,             -- 1-bit input: Asynchronous reset input
      SHIFTIN => master_iserdes_shifth_out      -- 1-bit input: Cascade input signal for master/slave I/O
   );


end Behavioral;
