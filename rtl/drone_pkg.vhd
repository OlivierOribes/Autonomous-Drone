-- ==============================================================================
--  Module      : drone_pkg
--  File        : drone_pkg.vhd
--
--  Description : Shared constants for the drone controller (speed level codes,
--                duty cycles, clock divider ratios, debounce delay, display
--                parameters). Every RTL module uses this package.
--
--  Component   : DRONE
--
--  Author      : Olivier Oribes
--  Created     : 03/11/2026
--  Last update : 03/11/2026
--
--  Version     : 1.0
--
--  Project     : BE on drone
--  Target Dev  : FPGA Basys3 (100 MHz Clock)
--  Language    : VHDL
--
--  License     : MIT
-- ==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package drone_pkg is

    -- Speed level codes (direction -> pwm / display)
    constant SPEED_HIGH        : std_ulogic_vector(2 downto 0) := "100";  -- 95% duty cycle code
    constant SPEED_MID         : std_ulogic_vector(2 downto 0) := "010";  -- 50% duty cycle code
    constant SPEED_LOW         : std_ulogic_vector(2 downto 0) := "001";  -- 15% duty cycle code
    constant SPEED_STILL       : std_ulogic_vector(2 downto 0) := "000";  -- 0% duty cycle code

    -- Duty cycle values (%) associated with each speed level
    constant HIGH_DUTY         : natural := 95;                          -- 95% duty cycle threshold
    constant MID_DUTY          : natural := 50;                          -- 50% duty cycle threshold
    constant LOW_DUTY          : natural := 15;                          -- 15% duty cycle threshold

    -- Motor rotation direction
    constant DIR_FORWARD       : std_ulogic := '0';                      -- Positive rotation
    constant DIR_BACKWARD      : std_ulogic := '1';                      -- Negative rotation

    -- PWM generator (50 Hz PWM, 100 steps of 200 µs)
    constant PWM_DIVID_RATIO   : natural := 19_999;                      -- 100 MHz / 5 kHz = 20,000 cycles (0 to 19,999)
    constant PWM_STEPS         : natural := 100;                         -- Number of steps per PWM period (1% resolution)

    -- StartStop debouncer
    constant DEBOUNCE_COUNT    : natural := 1_000_000;                   -- 10 ms at 100 MHz

    -- 7-segment display
    constant DISP_DIVID_RATIO  : natural := 99_999;                      -- 100 MHz / 1 kHz = 100,000 cycles (0 to 99,999)
    constant NB_DIGITS         : natural := 4;                           -- Number of 7-segment digits to scan

    -- 7-segment patterns (active low, segments "gfedcba")
    constant SEG_0             : std_ulogic_vector(6 downto 0) := "1000000";  -- 0
    constant SEG_1             : std_ulogic_vector(6 downto 0) := "1111001";  -- 1
    constant SEG_2             : std_ulogic_vector(6 downto 0) := "0100100";  -- 2
    constant SEG_3             : std_ulogic_vector(6 downto 0) := "0110000";  -- 3
    constant SEG_4             : std_ulogic_vector(6 downto 0) := "0011001";  -- 4
    constant SEG_5             : std_ulogic_vector(6 downto 0) := "0010010";  -- 5
    constant SEG_6             : std_ulogic_vector(6 downto 0) := "0000010";  -- 6
    constant SEG_7             : std_ulogic_vector(6 downto 0) := "1111000";  -- 7
    constant SEG_8             : std_ulogic_vector(6 downto 0) := "0000000";  -- 8
    constant SEG_9             : std_ulogic_vector(6 downto 0) := "0010000";  -- 9
    constant SEG_OFF           : std_ulogic_vector(6 downto 0) := "1111111";  -- Blank / Off

    --------------------------------------------------------------------------
    -- Functions
    --------------------------------------------------------------------------
    function slv_to_hstring(slv : std_ulogic_vector) return string;
    
end package drone_pkg;


package body drone_pkg is

    --------------------------------------------------------------------------
    -- Function : slv_to_hstring
    -- Purpose  : Converts a std_logic_vector to a hexadecimal string.
    --            Compatible with VHDL-2008 (replacement for to_hstring).
    --------------------------------------------------------------------------
    function slv_to_hstring(slv : std_ulogic_vector) return string is
        constant HEX_CHARS : string(1 to 16) := "0123456789ABCDEF";
        constant PAD_LEN   : integer := ((slv'length + 3) / 4) * 4;
        variable padded    : std_ulogic_vector(PAD_LEN - 1 downto 0) := (others => '0');
        variable nibble    : std_ulogic_vector(3 downto 0);
        variable result    : string(1 to PAD_LEN / 4);
        variable idx       : integer;
    begin
        padded(slv'length - 1 downto 0) := slv;
        for i in result'range loop
            nibble := padded(PAD_LEN - 1 - (i-1)*4 downto PAD_LEN - i*4);
            idx    := to_integer(unsigned(nibble));
            result(i) := HEX_CHARS(idx + 1);
        end loop;
        return result;
    end function;

end package body drone_pkg;