----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.04.2019 17:38:20
-- Design Name: 
-- Module Name: clock_generator - Behavioral
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

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity clock_generator is
    Port ( 
      clk_in            : in std_logic;
      rst_in            : in std_logic;
      pll_lock          : out std_logic;
      clk_out_125MHz    : out std_logic;
      clk_out_250MHz    : out std_logic;
      rst_out           : out std_logic
    );
end clock_generator;

architecture Behavioral of clock_generator is
    signal pll_clkout_0     : std_logic;
    signal pll_clkout_1     : std_logic;
    signal pll_clkout_2     : std_logic;
    signal pll_clkout_3     : std_logic;
    signal CLKFBOUT         : std_logic;
    signal CLKFBOUT_bufg    : std_logic;
    signal CLKFBIN          : std_logic;
    signal LOCKED           : std_logic;
    signal rst              : std_logic:='1';
    signal rst_vector       : std_logic_vector(7 downto 0):= (OTHERS => '1');
begin

process(pll_clkout_0, LOCKED, rst_in) 
begin
    if (LOCKED = '0') or (rst_in = '1') then
      rst_vector <= (others => '1');
    else
      if rising_edge(pll_clkout_0) then
        rst_vector(7 downto 1 ) <= rst_vector(6 downto 0);
        rst_vector(0) <= '0';
      end if;
  end if;
end process;

rst <= rst_vector(7);

PLL_BASE_inst : PLL_BASE
   generic map (
      BANDWIDTH => "OPTIMIZED",             -- "HIGH", "LOW" or "OPTIMIZED" 
      CLKFBOUT_MULT => 20,                   -- Multiply value for all CLKOUT clock outputs (1-64)
      CLKFBOUT_PHASE => 0.0,                -- Phase offset in degrees of the clock feedback output
                                            -- (0.0-360.0).
      CLKIN_PERIOD => 20.0,                  -- Input clock period in ns to ps resolution (i.e. 33.333 is 30
                                            -- MHz).
      -- CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for CLKOUT# clock output (1-128)
      CLKOUT0_DIVIDE => 8,
      CLKOUT1_DIVIDE => 4,
      CLKOUT2_DIVIDE => 10,
      CLKOUT3_DIVIDE => 10,
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
      CLKOUT3_PHASE => 180.0,
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
      CLKOUT0 => pll_clkout_0,
      CLKOUT1 => pll_clkout_1,
      CLKOUT2 => pll_clkout_2,
      CLKOUT3 => pll_clkout_3,
      CLKOUT4 => open,
      CLKOUT5 => open,
      LOCKED => LOCKED,     -- 1-bit output: PLL_BASE lock status output
      CLKFBIN => CLKFBIN,   -- 1-bit input: Feedback clock input
      CLKIN => clk_in,       -- 1-bit input: Clock input
      RST => rst_in            -- 1-bit input: Reset input
   );
pll_lock <= LOCKED;

bufg1_inst : BUFG port map ( I => CLKFBOUT, O => CLKFBOUT_bufg);
bufg2_inst : BUFG port map ( I => pll_clkout_0, O => clk_out_125MHz);
bufg3_inst : BUFG port map ( I => pll_clkout_1, O => clk_out_250MHz);
--bufg4_inst : BUFG port map ( I => pll_clkout_2, O => clk_out_100MHz);
--bufg5_inst : BUFG port map ( I => pll_clkout_3, O => clk_out_100MHz_180);
--bufg3_inst : BUFG port map ( I => rst, O => rst_out);
rst_out <= rst;

BUFIO2FB_inst : BUFIO2FB
   generic map (
      DIVIDE_BYPASS => TRUE  -- Bypass divider (TRUE/FALSE)
   )
   port map (
      O => CLKFBIN, -- 1-bit output: Output feedback clock (connect to feedback input of DCM/PLL)
      I => CLKFBOUT_bufg  -- 1-bit input: Feedback clock input (connect to input port)
   );
end Behavioral;
