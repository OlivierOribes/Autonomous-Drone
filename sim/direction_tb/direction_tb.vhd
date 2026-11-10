-- ==============================================================================
--  Module      : direction testbench
--  File        : direction_tb.vhd
--
--  Description : direction testbench. Drives the line sensors (SensRight,
--                SensLeft), the move enable and the reset, and checks the
--                speed level and rotation direction applied to each motor:
--                  1. Move straight : no sensor     -> L = HIGH,  R = HIGH
--                  2. Turn right    : SensRight     -> L = HIGH,  R = MID
--                  3. Turn left     : SensLeft      -> L = MID,   R = HIGH
--                  4. Turn around   : both sensors  -> L = STILL, R = HIGH
--                  5. Idle          : move = '0'    -> L = STILL, R = STILL
--                  6. Reset         : rstn = '0'    -> L = STILL, R = STILL
--                Both motor directions are expected to stay at '0'.
--
--  Component   : DRONE
--
--  Author      : Olivier Oribes
--  Created     : 02/11/2026
--  Last update : 05/11/2026
--
--  Version     : 1.0
--
--  Project     : Drone Lab Assignment (BE Drone)
--  Target Dev  : Digilent Basys 3 Board (Xilinx Artix-7)
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

entity direction_tb is
end entity direction_tb;


architecture sim of direction_tb is

    constant CLK_PERIOD        : time := 10 ns; -- 100 MHz clock

    signal clk                 : std_ulogic := '0'; 
    signal rstn                : std_ulogic := '1';
    signal SensRight           : std_ulogic := '0';
    signal SensLeft            : std_ulogic := '0';
    signal move                : std_ulogic := '0';
    signal pwm_duty_cycle_L    : std_ulogic_vector(2 downto 0) := (others => '0'); -- Selects the target speed level left motor (HIGH = 95%, MID = 50%, MIN = 15%, STILL = 0%)
    signal pwm_duty_cycle_R    : std_ulogic_vector(2 downto 0) := (others => '0');  -- Selects the target speed level right motor (HIGH = 95%, MID = 50%, MIN = 15%, STILL = 0%)
    signal MotorRight_dir      : std_ulogic := '0';  -- Rotation direction for the right motor output
    signal MotorLeft_dir       : std_ulogic := '0';  -- Rotation direction for the left motor output
        

    procedure check_speed_L(
        constant expected : in std_ulogic_vector(2 downto 0);
        variable count    : inout integer) is
    begin
        if (pwm_duty_cycle_L /= expected) then
            report "Error pwm_duty_cycle_L should be equal to " &
                slv_to_hstring(expected) & " but got " &
                slv_to_hstring(pwm_duty_cycle_L)
                severity error;
            count := count + 1;
        end if;
    end procedure;
    
    procedure check_speed_R(
        constant expected : in std_ulogic_vector(2 downto 0); 
        variable count    : inout integer) is
    begin
        if (pwm_duty_cycle_R /= expected) then
            report "Error pwm_duty_cycle_R should be equal to " &
                slv_to_hstring(expected) & " but got " &
                slv_to_hstring(pwm_duty_cycle_R)
                severity error;
            count := count + 1;
        end if;
    end procedure;


    procedure check_dir_R(
        constant expected : in std_ulogic; 
        variable count    : inout integer) is
    begin
        if (MotorRight_dir /= expected) then
            report "Error MotorRight_dir should be equal to " &
                std_ulogic'image(expected) & " but got " &
                std_ulogic'image(MotorRight_dir)
                severity error;
            count := count + 1;
        end if;
    end procedure;
    
    procedure check_dir_L(
        constant expected : in std_ulogic; 
        variable count    : inout integer) is
    begin
        if (MotorLeft_dir /= expected) then
            report "Error MotorLeft_dir should be equal to " &
                std_ulogic'image(expected) & " but got " &
                std_ulogic'image(MotorLeft_dir)
                severity error;
            count := count + 1;
        end if;
    end procedure;


begin


    -- ------------------------------------------------------------------
    -- Device Under Test
    -- ------------------------------------------------------------------
    DUT_direction : entity work.direction
    port map(
        clk_i              => clk,
        SensRight_i        => SensRight,
        SensLeft_i         => SensLeft,
        rstn_i             => rstn,
        move_i             => move,
        pwm_duty_cycle_L_o => pwm_duty_cycle_L,
        pwm_duty_cycle_R_o => pwm_duty_cycle_R,
        MotorRight_dir_o   => MotorRight_dir,
        MotorLeft_dir_o    => MotorLeft_dir
    );

    -- ------------------------------------------------------------------
    -- Clock generation : 100 MHz
    -- ------------------------------------------------------------------
    clk <= not clk after CLK_PERIOD/2;

    -- ------------------------------------------------------------------
    -- Stimulus
    -- ------------------------------------------------------------------
    STIM : process
        variable error_count : integer := 0;
    begin   

        -- ------------------------------------------------------------------
        -- TEST 1 : MOVESTRAIGHT
        --  move = '1', sensors "00" : IDLE -> DETECT -> MOVESTRAIGHT.
        --  Expected : L = HIGH, R = HIGH, both directions FORWARD ('0').
        --  Checked 3 clock cycles later (FSM latency).
        -- ------------------------------------------------------------------

        SensRight  <= '0';
        SensLeft   <= '0';
        move       <= '1';

        -- Three cycles needed for pwm_duty_cycle to be modified
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;

        check_speed_L(SPEED_HIGH, error_count);
        check_speed_R(SPEED_HIGH, error_count);
        check_dir_R('0', error_count);
        check_dir_L('0', error_count);


        if error_count = 0 then
            report "TEST 1 PASSED" severity note;
        else
            report "TEST 1 FINISHED WITH " &
                integer'image(error_count) & " ERROR(S)"
                severity failure;
        end if;

        -- ------------------------------------------------------------------
        -- TEST 2 : TURNRIGHT
        --  SensRight = '1' (sensors "01") -> TURNRIGHT : right motor slowed down.
        --  Expected : L = HIGH, R = MID, both directions FORWARD ('0').
        --  Checked 4 cycles later (2-stage sensor sync + DETECT + action state).
        -- ------------------------------------------------------------------

        SensRight  <= '1';
        SensLeft   <= '0';
        move       <= '1';
        
        -- Four cycles needed for pwm_duty_cycle to be modified
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;

        check_speed_L(SPEED_HIGH, error_count);
        check_speed_R(SPEED_LOW, error_count);
        check_dir_R('0', error_count);
        check_dir_L('0', error_count);


        if error_count = 0 then
            report "TEST 2 PASSED" severity note;
        else
            report "TEST 2 FINISHED WITH " &
                integer'image(error_count) & " ERROR(S)"
                severity failure;
        end if;

        -- ------------------------------------------------------------------
        -- TEST 3 : TURNLEFT
        --  SensLeft = '1' (sensors "10") -> TURNLEFT : left motor slowed down.
        --  Expected : L = MID, R = HIGH, both directions FORWARD ('0').
        -- ------------------------------------------------------------------

        SensRight  <= '0';
        SensLeft   <= '1';
        move       <= '1';

        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;
        
        -- Need to check what is the speed, as we improved the model throughout the project
        check_speed_L(SPEED_MID, error_count);
        check_speed_R(SPEED_HIGH, error_count);
        check_dir_R('0', error_count);
        check_dir_L('0', error_count);
        

        if error_count = 0 then
            report "TEST 3 PASSED" severity note;
        else
            report "TEST 3 FINISHED WITH " &
                integer'image(error_count) & " ERROR(S)"
                severity failure;
        end if;

        -- ------------------------------------------------------------------
        -- TEST 4 : TURNAROUND
        --  Both sensors (sensors "11") -> TURNAROUND, done by turning left.
        --  Expected : L = STILL, R = HIGH, both directions FORWARD ('0').
        -- ------------------------------------------------------------------

        SensRight  <= '1';
        SensLeft   <= '1';
        move       <= '1';

        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;
        
        -- Need to check what is the speed, as we improved the model throughout the project
        check_speed_L(SPEED_STILL, error_count);
        check_speed_R(SPEED_HIGH, error_count);
        check_dir_R('0', error_count);
        check_dir_L('0', error_count);
        

        if error_count = 0 then
            report "TEST 4 PASSED" severity note;
        else
            report "TEST 4 FINISHED WITH " &
                integer'image(error_count) & " ERROR(S)"
                severity failure;
        end if;

        -- ------------------------------------------------------------------
        -- TEST 5 : Move = '0' : IDLE
        --  move = '0' : the drone is stopped, FSM goes back to IDLE.
        --  Expected : L = STILL, R = STILL (speeds reset), directions FORWARD.
        -- ------------------------------------------------------------------

        SensRight  <= '0';
        SensLeft   <= '0';
        move       <= '0';

        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;

        check_speed_L(SPEED_STILL, error_count);
        check_speed_R(SPEED_STILL, error_count);
        check_dir_R('0', error_count);
        check_dir_L('0', error_count);
        

        if error_count = 0 then
            report "TEST 5 PASSED" severity note;
        else
            report "TEST 5 FINISHED WITH " &
                integer'image(error_count) & " ERROR(S)"
                severity failure;
        end if;

        -- ------------------------------------------------------------------
        -- TEST 6 : Rst
        --  rstn = '0' while move = '1' : asynchronous reset has priority.
        --  Expected : L = STILL, R = STILL, directions FORWARD.
        --  The reset is then released for one cycle before the end.
        -- ------------------------------------------------------------------

        SensRight  <= '0';
        SensLeft   <= '0';
        move       <= '1';
        rstn       <= '0';

        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;

        check_speed_L(SPEED_STILL, error_count);
        check_speed_R(SPEED_STILL, error_count);
        check_dir_R('0', error_count);
        check_dir_L('0', error_count);

        rstn <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        

        if error_count = 0 then
            report "TEST 6 PASSED" severity note;
        else
            report "TEST 6 FINISHED WITH " &
                integer'image(error_count) & " ERROR(S)"
                severity failure;
        end if;

        -- ================================================================
        -- Fin de simulation
        -- ================================================================
        if error_count = 0 then
            report "ALL TESTS PASSED" severity note;
        else
            report "SIMULATION FINISHED WITH " &
                integer'image(error_count) & " ERROR(S)"
                severity failure;
        end if;

        report "End of simulation" severity failure;
        wait;

    end process STIM;

end architecture sim;
