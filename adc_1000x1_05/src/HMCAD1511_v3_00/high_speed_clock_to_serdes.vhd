----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02.04.2019 19:37:43
-- Design Name: 
-- Module Name: high_speed_clock_to_serdes - Behavioral
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

entity high_speed_clock_to_serdes is
    Generic (
        S                   : integer := 8
        );
    Port (
--        clkin_p             : in std_logic;
--        clkin_n             : in std_logic;
        clkin_ibufg         : in std_logic;
        gclk                : out std_logic;
        serdesclk0          : out std_logic;
        serdesclk1          : out std_logic;
        serdesstrobe        : out std_logic 
    );
end high_speed_clock_to_serdes;

architecture Behavioral of high_speed_clock_to_serdes is
    signal div_clk          : std_logic;
   -- signal clkin_ibufg      : std_logic;

begin

--   IBUFGDS_inst : IBUFGDS
--   generic map (
--      IBUF_LOW_PWR => TRUE, -- Low power (TRUE) vs. performance (FALSE) setting for referenced I/O standards
--      IOSTANDARD => "DEFAULT")
--   port map (
--      O => clkin_ibufg,     -- Clock buffer output
--      I => clkin_p,         -- Diff_p clock buffer input
--      IB => clkin_n         -- Diff_n clock buffer input
--   );

div_clk_bufg_ins : BUFG port map ( I => div_clk, O => gclk );

BUFIO2_clk0_inst : BUFIO2
   generic map (
      DIVIDE => S,           -- DIVCLK divider (1,3-8)
      DIVIDE_BYPASS => FALSE, -- Bypass the divider circuitry (TRUE/FALSE)
      I_INVERT => FALSE,     -- Invert clock (TRUE/FALSE)
      USE_DOUBLER => TRUE   -- Use doubler circuitry (TRUE/FALSE)
   )
   port map (
      DIVCLK => div_clk,             -- 1-bit output: Divided clock output
      IOCLK => serdesclk0,               -- 1-bit output: I/O output clock
      SERDESSTROBE => serdesstrobe, -- 1-bit output: Output SERDES strobe (connect to ISERDES2/OSERDES2)
      I => clkin_ibufg                        -- 1-bit input: Clock input (connect to IBUFG)
   );

BUFIO2_clk1_inst : BUFIO2
   generic map (
      DIVIDE => S,           -- DIVCLK divider (1,3-8)
      DIVIDE_BYPASS => FALSE, -- Bypass the divider circuitry (TRUE/FALSE)
      I_INVERT => TRUE,     -- Invert clock (TRUE/FALSE)
      USE_DOUBLER => FALSE   -- Use doubler circuitry (TRUE/FALSE)
   )
   port map (
      DIVCLK => open,             -- 1-bit output: Divided clock output
      IOCLK => serdesclk1,               -- 1-bit output: I/O output clock
      SERDESSTROBE => open, -- 1-bit output: Output SERDES strobe (connect to ISERDES2/OSERDES2)
      I => clkin_ibufg                        -- 1-bit input: Clock input (connect to IBUFG)
   );

end Behavioral;
