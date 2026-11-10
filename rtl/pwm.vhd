-- ==============================================================================
--  Module      : PWM Generator      
--  File        : pwm.vhd
--
--  Description : Generates a 50 Hz PWM signal with a 1% resolution (0-99 steps)
--                from a 100 MHz input clock, using a 5 kHz tick (100 ticks per
--                PWM period). Includes selectable speed levels for a DC motor
--                controller.
--      
--  Component   : PWM 
--               
--  Author      : Olivier Oribes
--  Created     : 02/11/2026
--  Last update : 02/11/2026
--
--  Version     : 1.0
--
--  Project     : DC Motor Controller
--  Target Dev  : FPGA (100 MHz Clock)
--  Language    : VHDL
--
--  License     : MIT
-- ==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.drone_pkg.all;

entity pwm is 
    port (
        clk_i            : in  std_ulogic;                             -- 100 MHz system clock
        rstn_i           : in  std_ulogic;                             -- Asynchronous active-low reset
        pwm_duty_cycle_i : in  std_ulogic_vector(2 downto 0);          -- Speed level selector (HIGH=95%, MID=50%, MIN=15%, STILL=0%)
        pwm_o            : out std_ulogic                              -- PWM output signal to motor driver
    );
end entity pwm;

architecture rtl of pwm is

    -- Internal signals definition
    signal   rhythm_5KHz  : std_ulogic := '0';                      -- 5 kHz tick pulse (200 µs period)
    signal   pwm_sig      : std_ulogic := '0';                      -- Internal PWM square wave
    signal   pwm_duty_cl  : natural range 0 to PWM_STEPS - 1 := 0;  -- Resolved target duty cycle value (0 to 99)
    
begin

    -- Combinational logic: Map input vector to target duty cycle percentage
    pwm_duty_cl <= HIGH_DUTY when pwm_duty_cycle_i = SPEED_HIGH else
                   MID_DUTY  when pwm_duty_cycle_i = SPEED_MID  else
                   LOW_DUTY  when pwm_duty_cycle_i = SPEED_LOW  else
                   0;

    -- Process 1: 5 kHz Clock Divider (100 MHz down to 5 kHz)
    proc_div_clock : process(clk_i, rstn_i)
        variable divcnt : natural range 0 to PWM_DIVID_RATIO := 0;
    begin
        if (rstn_i = '0') then -- When system reset, the first 
            divcnt     := 0;
            rhythm_5KHz <= '0';
    
        elsif rising_edge(clk_i) then
            rhythm_5KHz <= '0';

            if (divcnt = PWM_DIVID_RATIO) then
                rhythm_5KHz <= '1';
                divcnt     := 0;
            else  
                divcnt     := divcnt + 1;
            end if;
        end if;
    end process proc_div_clock;


    -- Process 2: PWM Generator (0 to 99 counter and comparator)
    proc_pwm : process(clk_i, rstn_i)
        variable PWMcnt : natural range 0 to PWM_STEPS - 1 := 0;
    begin
        if (rstn_i = '0') then
            PWMcnt  := 0;
            pwm_sig <= '0';

        elsif rising_edge(clk_i) then
            
            -- Advance PWM counter only at each 5 kHz tick
            if (rhythm_5KHz = '1') then

                if (PWMcnt = PWM_STEPS - 1) then
                    PWMcnt := 0;
                else 
                    PWMcnt := PWMcnt + 1;
                end if;

            end if;

            -- Compare counter with target duty cycle on every clock cycle
            if (PWMcnt < pwm_duty_cl) then
                pwm_sig <= '1';
            else  
                pwm_sig <= '0';
            end if;
            
        end if;
    end process proc_pwm;

    -- Output assignment
    pwm_o <= pwm_sig;

end architecture rtl;