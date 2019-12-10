----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 25.11.2019 18:00:36
-- Design Name: 
-- Module Name: data_deserializer - Behavioral
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

entity data_deserializer is
    generic (
      DIFF_TERM         : boolean := true
    );
    Port (
      serdes_clk0       : in std_logic;
      serdes_clk1       : in std_logic;
      serdes_divclk     : in std_logic;
      serdes_strobe     : in std_logic;
      data_p            : in std_logic;
      data_n            : in std_logic;
      calib_valid       : out std_logic;
      reset             : in std_logic;
      result            : out std_logic_vector(7 downto 0);
      bitslip           : in std_logic;
      data_obuf         : out std_logic
    );
end data_deserializer;

architecture Behavioral of data_deserializer is

    type state_machine  is (idle, start_calib, delay_busy_fall, delay_rst_edge, counter_edge, slave_start_calib, slave_end_calib);
    signal state, next_state : state_machine;
    type bs_state_machine is (idle, bs_st);
    signal bs_state, bs_next_state : bs_state_machine;
    signal data_in      : std_logic;
    signal busys        : std_logic;
    signal busym        : std_logic;
    signal ddly_m       : std_logic;
    signal ddly_s       : std_logic;
    signal pd_edge      : std_logic;
    signal cascade      : std_logic;
    signal delay_cal_m  : std_logic;
    signal delay_cal_s  : std_logic;
    signal delay_inc    : std_logic ;
    signal delay_ce     : std_logic;
    signal delay_busy   : std_logic;
    signal delay_rst    : std_logic;
    signal counter      : std_logic_vector(10 downto 0);
    signal bs           : std_logic;

begin
data_obuf <= data_in;
delay_busy <= busym or busys;

bs_sync_proc :
process(reset, serdes_divclk)
begin
  if (reset = '1') then
    bs_state <= idle;
  elsif rising_edge(serdes_divclk) then
    bs_state <= bs_next_state;
  end if;
end process;

bs_next_state_proc :
process(bs_state, bitslip)
begin
  bs_next_state <= bs_state;
    case bs_state is
      when idle => 
        if (bitslip = '1') then
          bs_next_state <= bs_st;
        end if;
      when bs_st =>
        bs_next_state <= idle;
      when others =>
        bs_next_state <= idle;
    end case;
end process;

bs_out_proc :
process(bs_state)
begin
  bs <= '0';
    case bs_state is
      when bs_st =>
        bs <= '1';
      when others =>
    end case;
end process;

counter_proc :
process(serdes_divclk)
begin
  if rising_edge(serdes_divclk) then
    if (state = counter_edge) then
      counter <= counter + 1;
    else
      counter <= (others => '0');
    end if;
  end if;
end process;

sync_proc :
process(reset, serdes_divclk)
begin
  if (reset = '1') then
    state <= idle;
  elsif rising_edge(serdes_divclk) then
    state <= next_state;
  end if;
end process;

next_state_proc :
process(state, delay_busy, counter(counter'length - 1))
begin
  next_state <= state;
    case state is
      when idle =>
        next_state <= start_calib;
      when start_calib =>
        if (delay_busy = '1') then
          next_state <= delay_busy_fall;
        end if;
      when delay_busy_fall =>
        if (delay_busy = '0') then
          next_state <= delay_rst_edge;
        end if;
      when delay_rst_edge => 
        if (delay_busy = '1') then
          next_state <= counter_edge;
        end if;
      when counter_edge => 
        if counter(counter'length - 1) = '1' then
          next_state <= slave_start_calib;
        end if;
      when slave_start_calib =>
        if (delay_busy = '1') then
          next_state <= slave_end_calib;
        end if;
      when slave_end_calib =>
        if (delay_busy = '0') then
          next_state <= counter_edge;
        end if;
      when others =>
        next_state <= idle;
    end case;
end process;

out_proc :
process(state)
begin
  delay_rst <= '0';
  delay_inc <= '1';
  delay_ce <= '0';
  delay_cal_m <= '0';
  delay_cal_s <= '0';
  calib_valid <= '0';
    case state is
      when start_calib =>
        delay_cal_m <= '1';
        delay_cal_s <= '1';
      when delay_rst_edge =>
        delay_rst <= '1';
      when counter_edge => 
        calib_valid <= '1';
      when slave_start_calib =>
        delay_cal_s <= '1';
      when others =>
    end case;
end process;

iob_clk_in : IBUFGDS 
  generic map(
    DIFF_TERM		=> DIFF_TERM
    )
  port map ( 
    I       => data_p,
    IB      => data_n,
    O       => data_in
    );

iodelay_m : IODELAY2 generic map(
	DATA_RATE      		=> "DDR", 		-- <SDR>, DDR
	IDELAY_VALUE  		=> 0, 			-- {0 ... 255}
	IDELAY2_VALUE 		=> 0, 			-- {0 ... 255}
	IDELAY_MODE  		=> "NORMAL" , 		-- NORMAL, PCI
	ODELAY_VALUE  		=> 0, 			-- {0 ... 255}
	IDELAY_TYPE   		=> "DIFF_PHASE_DETECTOR",-- "DEFAULT", "DIFF_PHASE_DETECTOR", "FIXED", "VARIABLE_FROM_HALF_MAX", "VARIABLE_FROM_ZERO"
	COUNTER_WRAPAROUND 	=> "WRAPAROUND", 	-- <STAY_AT_LIMIT>, WRAPAROUND
	DELAY_SRC     		=> "IDATAIN", 		-- "IO", "IDATAIN", "ODATAIN"
	SERDES_MODE   		=> "MASTER", 		-- <NONE>, MASTER, SLAVE
	SIM_TAPDELAY_VALUE   	=> 49) 			--
port map (
	IDATAIN  		=> data_in, 	-- data from primary IOB
	TOUT     		=> open, 		-- tri-state signal to IOB
	DOUT     		=> open, 		-- output data to IOB
	T        		=> '1', 		-- tri-state control from OLOGIC/OSERDES2
	ODATAIN  		=> '0', 		-- data from OLOGIC/OSERDES2
	DATAOUT  		=> ddly_m, 		-- Output data 1 to ILOGIC/ISERDES2
	DATAOUT2 		=> open, 		-- Output data 2 to ILOGIC/ISERDES2
	IOCLK0   		=> serdes_clk0, 		-- High speed clock for calibration
	IOCLK1   		=> serdes_clk1, 		-- High speed clock for calibration
	CLK      		=> serdes_divclk, 		-- Fabric clock (serdes_divclk) for control signals
	CAL      		=> delay_cal_m,	-- Calibrate control signal
	INC      		=> delay_inc,		-- Increment counter
	CE       		=> delay_ce,		-- Clock Enable
	RST      		=> delay_rst,		-- Reset delay line
	BUSY      		=> busym) ; 		-- output signal indicating sync circuit has finished / calibration has finished

iodelay_s : IODELAY2 generic map(
	DATA_RATE      		=> "DDR", 		-- <SDR>, DDR
	IDELAY_VALUE  		=> 0, 			-- {0 ... 255}
	IDELAY2_VALUE 		=> 0, 			-- {0 ... 255}
	IDELAY_MODE  		=> "NORMAL" , 		-- NORMAL, PCI
	ODELAY_VALUE  		=> 0, 			-- {0 ... 255}
	IDELAY_TYPE   		=> "DIFF_PHASE_DETECTOR",-- "DEFAULT", "DIFF_PHASE_DETECTOR", "FIXED", "VARIABLE_FROM_HALF_MAX", "VARIABLE_FROM_ZERO"
	COUNTER_WRAPAROUND 	=> "WRAPAROUND", 	-- <STAY_AT_LIMIT>, WRAPAROUND
	DELAY_SRC     		=> "IDATAIN", 		-- "IO", "IDATAIN", "ODATAIN"
	SERDES_MODE   		=> "SLAVE", 		-- <NONE>, MASTER, SLAVE
	SIM_TAPDELAY_VALUE   	=> 49) 			--
port map (
	IDATAIN  		=> data_in, 	-- data from primary IOB
	TOUT     		=> open, 		-- tri-state signal to IOB
	DOUT     		=> open, 		-- output data to IOB
	T        		=> '1', 		-- tri-state control from OLOGIC/OSERDES2
	ODATAIN  		=> '0', 		-- data from OLOGIC/OSERDES2
	DATAOUT  		=> ddly_s, 		-- Output data 1 to ILOGIC/ISERDES2
	DATAOUT2 		=> open, 		-- Output data 2 to ILOGIC/ISERDES2
	IOCLK0   		=> serdes_clk0, 		-- High speed clock for calibration
	IOCLK1   		=> serdes_clk1, 		-- High speed clock for calibration
	CLK      		=> serdes_divclk, 		-- Fabric clock (serdes_divclk) for control signals
	CAL      		=> delay_cal_s,	-- Calibrate control signal
	INC      		=> delay_inc,		-- Increment counter
	CE       		=> delay_ce,		-- Clock Enable
	RST      		=> delay_rst,		-- Reset delay line
	BUSY      		=> busys) ; 		-- output signal indicating sync circuit has finished / calibration has finished
		
iserdes_m : ISERDES2 generic map (
	DATA_WIDTH     		=> 8, 			-- SERDES word width.  This should match the setting is BUFPLL
	DATA_RATE      		=> "DDR", 		-- <SDR>, DDR
	BITSLIP_ENABLE 		=> TRUE, 		-- <FALSE>, TRUE
	SERDES_MODE    		=> "MASTER", 		-- <DEFAULT>, MASTER, SLAVE
	INTERFACE_TYPE 		=> "RETIMED") 		-- NETWORKING, NETWORKING_PIPELINED, <RETIMED>
port map (
	D       		=> ddly_m,
	CE0     		=> '1',
	CLK0    		=> serdes_clk0,
	CLK1    		=> serdes_clk1,
	IOCE    		=> serdes_strobe,
	RST     		=> reset,
	CLKDIV  		=> serdes_divclk,
	SHIFTIN 		=> pd_edge,
	BITSLIP 		=> bs,
	FABRICOUT 		=> open,
	Q4  			=> result(7),
	Q3  			=> result(6),
	Q2  			=> result(5),
	Q1  			=> result(4),
	DFB  			=> open,			-- are these the same as above? These were in Johns design
	CFB0 			=> open,
	CFB1 			=> open,
	VALID    		=> open,
	INCDEC   		=> open,
	SHIFTOUT 		=> cascade
    );

iserdes_s : ISERDES2 generic map(
	DATA_WIDTH     		=> 8, 			-- SERDES word width.  This should match the setting is BUFPLL
	DATA_RATE      		=> "DDR", 		-- <SDR>, DDR
	BITSLIP_ENABLE 		=> TRUE, 		-- <FALSE>, TRUE
	SERDES_MODE    		=> "SLAVE", 		-- <DEFAULT>, MASTER, SLAVE
	INTERFACE_TYPE 		=> "RETIMED") 		-- NETWORKING, NETWORKING_PIPELINED, <RETIMED>
port map (
	D       		=> ddly_s,
	CE0     		=> '1',
	CLK0    		=> serdes_clk0,
	CLK1    		=> serdes_clk1,
	IOCE    		=> serdes_strobe,
	RST     		=> reset,
	CLKDIV  		=> serdes_divclk,
	SHIFTIN 		=> cascade,
	BITSLIP 		=> bs,
	FABRICOUT 		=> open,
	Q4  			=> result(3),
	Q3  			=> result(2),
	Q2  			=> result(1),
	Q1  			=> result(0),
	DFB  			=> open,			-- are these the same as above? These were in Johns design
	CFB0 			=> open,
	CFB1 			=> open,
	VALID 			=> open,
	INCDEC 			=> open,
	SHIFTOUT 		=> pd_edge
    );


end Behavioral;
