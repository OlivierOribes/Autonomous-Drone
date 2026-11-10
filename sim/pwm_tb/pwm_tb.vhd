-- ==============================================================================
--  Module      : pwm_tb
--  File        : pwm_tb.vhd
--
--  Description : PWM testbench.
--                Checks the PWM output of the DUT for each speed level
--                (HIGH = 95%, MID = 50%, LOW = 15%, STILL = 0%) over one
--                full PWM period (PWM_STEPS steps of 200 us), then checks
--                the behaviour of the asynchronous active-low reset.
--
--                Principle : a reference clock at the same step rate as the
--                DUT internal tick (5 kHz) is generated in the testbench.
--                On each of its rising edges, pwm_out is sampled, compared
--                with the expected level, and the number of '1' samples is
--                counted to verify the duty cycle.
--  Component   : DRONE 
--               
--  Author      : Olivier Oribes
--  Created     : 02/11/2026
--  Last update : 02/11/2026
--
--  Version     : 1.0
--
--  Project     : BE on drone
--  Language    : VHDL
--
--  License     : MIT
-- ==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

library work;
use work.drone_pkg.all;

entity pwm_tb is
end entity pwm_tb;


architecture sim of pwm_tb is

    -- ------------------------------------------------------------------
    -- Constants
    -- ------------------------------------------------------------------
    constant CLK_PERIOD        : time := 10 ns;  -- 100 MHz system clock period
    constant CLK_5KHZ_PERIOD  : time := 200 us; -- PWM step period (200 us = 5 kHz, same rate as the DUT internal tick)

    -- ------------------------------------------------------------------
    -- Signals
    -- ------------------------------------------------------------------
    signal clk                 : std_ulogic := '0'; -- 100 MHz system clock (drives the DUT)
    signal clk_5kHz           : std_ulogic := '0'; -- Testbench sampling clock (period 200 us => 5 kHz)
    signal rstn                : std_ulogic := '1'; -- Active-low asynchronous reset
    signal pwm_duty_cycle      : std_ulogic_vector(2 downto 0) := (others => '0'); -- Selects the target speed level of a motor (HIGH = 95%, MID = 50%, MIN = 15%, STILL = 0%)
    signal pwm_out             : std_ulogic := '0';  -- PWM output signal to motor driver
        

    -- ------------------------------------------------------------------
    -- check_PWM_out : compares the current value of pwm_out with the
    -- expected level. On mismatch, reports an error and increments the
    -- error counter.
    -- ------------------------------------------------------------------
    procedure check_PWM_out(
        constant expected : in std_ulogic;
        variable count    : inout integer) is
    begin
        if (pwm_out /= expected) then
            report "Error pwm_out should be equal to " &
                std_ulogic'image(expected) & " but got " &
                std_ulogic'image(pwm_out)
                severity error;
            count := count + 1;
        end if;
    end procedure;

    -- ------------------------------------------------------------------
    -- check_PWM_coun : compares the number of '1' samples counted over a
    -- full PWM period (PWM_cnt) with the expected duty cycle value.
    -- On mismatch, reports an error and increments the error counter.
    -- ------------------------------------------------------------------
    procedure check_PWM_coun(
        constant expected : in natural range 0 to PWM_STEPS - 1;
        constant PWM_cnt  : in natural range 0 to PWM_STEPS - 1;
        variable count    : inout integer) is
    begin
        if (PWM_cnt /= expected) then
            report "Error PWM_cnt should be equal to " &
                natural'image(expected) & " but got " &
                natural'image(PWM_cnt)
                severity error;
            count := count + 1;
        end if;
    end procedure;
    
begin


    -- ------------------------------------------------------------------
    -- Device Under Test
    -- ------------------------------------------------------------------
    DUT_pwm : entity work.pwm
    port map(
        clk_i              => clk,
        rstn_i             => rstn,
        pwm_duty_cycle_i   => pwm_duty_cycle,
        pwm_o              => pwm_out
    );

    -- ------------------------------------------------------------------
    -- Clock generation : 100 MHz
    -- ------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD/2;

    -- ------------------------------------------------------------------
    -- Sampling clock generation : 5 kHz (period 200 us)
    -- ------------------------------------------------------------------
    -- One rising edge every 200 us, i.e. one sample per PWM step.
    -- Not synchronised with the DUT divider : it only provides a sampling
    -- instant per step, the exact phase does not matter as long as the
    -- PWM counter does not move between two samples.

    clk_5kHz <= not clk_5kHz after CLK_5KHZ_PERIOD/2;

    -- ------------------------------------------------------------------
    -- Stimulus
    -- ------------------------------------------------------------------
    STIM : process
        variable error_count : integer := 0;                     -- Cumulative number of errors (all tests)
        variable PWMcnt      : natural range 0 to PWM_STEPS - 1; -- Number of '1' samples over one PWM period
    begin   

        -- ------------------------------------------------------------------
        -- TEST 1 : HIGH_DUTY -- 95% PWM
        --  Speed code SPEED_HIGH ("100") applied, one full PWM period sampled.
        --  Expected : pwm_out = '1' for steps 0..94, '0' for steps 95..99
        --  -> 95 '1' samples counted over the period.
        -- ------------------------------------------------------------------

        pwm_duty_cycle <= "100";  -- SPEED_HIGH
        PWMcnt := 0;

        -- Sample pwm_out once per PWM step over a full period
        for i in 0 to PWM_STEPS - 1 loop
            
            wait until rising_edge(clk_5kHz);
            wait for 0 ns;  -- Delta delay : let signals settle before sampling

            -- Count the number of steps where the output is high
            if ( pwm_out = '1') then

                PWMcnt := PWMcnt + 1;

            end if;

            -- Output must be high for the first HIGH_DUTY steps, low afterwards
            if (i < HIGH_DUTY) then

                check_PWM_out( '1', error_count);
                
            else
                check_PWM_out( '0', error_count);

            end if;

        end loop;

        -- Check the measured duty cycle over the whole period
        check_PWM_coun(HIGH_DUTY, PWMcnt, error_count);


        -- Test result (error_count is cumulative : a failure stops the simulation)
        if error_count = 0 then
            report "TEST 1 PASSED" severity note;
        else
            report "TEST 1 FINISHED WITH " &
                integer'image(error_count) & " ERROR(S)"
                severity failure;
        end if;

        -- ------------------------------------------------------------------
        -- TEST 2 : MID_DUTY -- 50% PWM
        --  Speed code SPEED_MID ("010") applied, one full PWM period sampled.
        --  Expected : pwm_out = '1' for steps 0..49, '0' for steps 50..99
        --  -> 50 '1' samples counted over the period.
        -- ------------------------------------------------------------------

        
        pwm_duty_cycle <= "010";  -- SPEED_MID
        PWMcnt := 0;

        -- Sample pwm_out once per PWM step over a full period
        for i in 0 to PWM_STEPS - 1 loop
            
            wait until rising_edge(clk_5kHz);
            wait for 0 ns;  -- Delta delay : let signals settle before sampling

            -- Count the number of steps where the output is high
            if ( pwm_out = '1') then

                PWMcnt := PWMcnt + 1;

            end if;

            -- Output must be high for the first MID_DUTY steps, low afterwards
            if (i < MID_DUTY) then

                check_PWM_out( '1', error_count);
            
            else
                check_PWM_out( '0', error_count);

            end if;

        end loop;

        -- Check the measured duty cycle over the whole period
        check_PWM_coun(MID_DUTY, PWMcnt, error_count);


        -- Test result (error_count is cumulative : a failure stops the simulation)
        if error_count = 0 then
            report "TEST 2 PASSED" severity note;
        else
            report "TEST 2 FINISHED WITH " &
                integer'image(error_count) & " ERROR(S)"
                severity failure;
        end if;

        -- ------------------------------------------------------------------
        -- TEST 3 : LOW_DUTY -- 15% PWM
        --  Speed code SPEED_LOW ("001") applied, one full PWM period sampled.
        --  Expected : pwm_out = '1' for steps 0..14, '0' for steps 15..99
        --  -> 15 '1' samples counted over the period.
        -- ------------------------------------------------------------------

        pwm_duty_cycle <= "001";  -- SPEED_LOW
        PWMcnt := 0;

        -- Sample pwm_out once per PWM step over a full period
        for i in 0 to PWM_STEPS - 1 loop
            
            wait until rising_edge(clk_5kHz);
            wait for 0 ns;  -- Delta delay : let signals settle before sampling

            -- Count the number of steps where the output is high
            if ( pwm_out = '1') then

                PWMcnt := PWMcnt + 1;

            end if;

            -- Output must be high for the first LOW_DUTY steps, low afterwards
            if (i < LOW_DUTY) then

                check_PWM_out( '1', error_count);
            
            else
                check_PWM_out( '0', error_count);

            end if;

        end loop;

        -- Check the measured duty cycle over the whole period
        check_PWM_coun(LOW_DUTY, PWMcnt, error_count);

        -- Test result (error_count is cumulative : a failure stops the simulation)
        if error_count = 0 then
            report "TEST 3 PASSED" severity note;
        else
            report "TEST 3 FINISHED WITH " &
                integer'image(error_count) & " ERROR(S)"
                severity failure;
        end if;

        -- ------------------------------------------------------------------
        -- TEST 4 : STILL -- 0% PWM
        --  Speed code SPEED_STILL ("000") applied, one full PWM period sampled.
        --  Expected : pwm_out stays at '0' on every step -> 0 '1' sample.
        -- ------------------------------------------------------------------

        pwm_duty_cycle <= "000";  -- STILL (no valid speed code => 0%)
        PWMcnt := 0;

        -- Sample pwm_out once per PWM step over a full period
        for i in 0 to PWM_STEPS - 1 loop
            
            wait until rising_edge(clk_5kHz);
            wait for 0 ns;  -- Delta delay : let signals settle before sampling

            -- Count the number of steps where the output is high
            if ( pwm_out = '1') then

                PWMcnt := PWMcnt + 1;

            end if;

            -- 0% duty cycle : the first branch is never taken, output must stay low
            if (i < 0) then

                check_PWM_out( '1', error_count);
            
            else
                check_PWM_out( '0', error_count);

            end if;

        end loop;

        -- Check the measured duty cycle over the whole period (expected 0)
        check_PWM_coun(0, PWMcnt, error_count);

        -- Test result (error_count is cumulative : a failure stops the simulation)
        if error_count = 0 then
            report "TEST 4 PASSED" severity note;
        else
            report "TEST 4 FINISHED WITH " &
                integer'image(error_count) & " ERROR(S)"
                severity failure;
        end if;

        -- ------------------------------------------------------------------
        -- TEST 5 :  Reset
        --  a) rstn = '0' for ~100 clock cycles while SPEED_HIGH is requested :
        --     asynchronous reset, pwm_out must be forced to '0'.
        --  b) rstn released : the divider and PWM counter restart from 0 and
        --     a correct 95% period must be produced again (same checks as TEST 1).
        -- ------------------------------------------------------------------

        -- Assert the reset while requesting the highest speed : the output
        -- must nevertheless be forced to '0'.
        pwm_duty_cycle <= "100";  -- SPEED_HIGH
        PWMcnt         := 0;
        rstn           <= '0';    -- Assert reset (active low)

        wait until rising_edge(clk);
        wait for 0 ns;
        
        -- Check that pwm_out stays at 0 while rstn is enabled
        for j in 0 to 100 loop
            check_PWM_out( '0', error_count);
            wait until rising_edge(clk);
            wait for 0 ns;
        end loop;
        
        -- Release the reset : the DUT restarts from a cleared counter and
        -- must produce a correct 95% PWM again
        rstn           <= '1';

        -- Sample pwm_out once per PWM step over a full period
        for i in 0 to PWM_STEPS - 1 loop
            
            wait until rising_edge(clk_5kHz);
            wait for 0 ns;  -- Delta delay : let signals settle before sampling

            -- Count the number of steps where the output is high
            if ( pwm_out = '1') then

                PWMcnt := PWMcnt + 1;

            end if;

            -- Output must be high for the first HIGH_DUTY steps, low afterwards
            if (i < HIGH_DUTY) then

                check_PWM_out( '1', error_count);
            
            else
                check_PWM_out( '0', error_count);

            end if;

        end loop;

        -- Check the measured duty cycle over the whole period
        check_PWM_coun(HIGH_DUTY, PWMcnt, error_count);

        -- Test result (error_count is cumulative : a failure stops the simulation)
        if error_count = 0 then
            report "TEST 5 PASSED" severity note;
        else
            report "TEST 5 FINISHED WITH " &
                integer'image(error_count) & " ERROR(S)"
                severity failure;
        end if;
        
        -- ================================================================
        -- End of simulation : global result
        -- ================================================================
        if error_count = 0 then
            report "ALL TESTS PASSED" severity note;
        else
            report "SIMULATION FINISHED WITH " &
                integer'image(error_count) & " ERROR(S)"
                severity failure;
        end if;

        -- severity failure is used to stop the simulator
        report "End of simulation" severity failure;
        wait;  -- Never reached, prevents the process from restarting

    end process STIM;

end architecture sim;
