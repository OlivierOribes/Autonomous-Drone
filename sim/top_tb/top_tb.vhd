-- ==============================================================================
--  Module      : top_tb
--  File        : top_tb.vhd
--
--  Description : Top-level testbench. Checks the motor outputs (PWM duty
--                cycle for each navigation case) and the 7-segment display.
--
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

entity top_tb is
end entity;

architecture sim of top_tb is

  constant CLK_PERIOD      : time    := 10 ns;  -- 100 MHz clock period
  constant CLK_PERIOD_1KHZ : time    := 1 ms;   -- 1 KHz clock period
  constant CLK_5KHZ_PERIOD : time    := 200 us; -- 5 KHz clock period
  constant N               : natural := 100;
  constant DEBOUNCE_CYCLES : natural := 1000;

  signal clk            : std_ulogic := '0';             -- 100 MHz clock
  signal clk_1kHZ       : std_ulogic := '0';             -- 1 KhZ clock
  signal clk_5kHZ       : std_ulogic := '0';             -- 5 KHz clock
  signal StartStop_btn  : std_ulogic := '0';
  signal btn_L          : std_ulogic := '0';             -- btn L (reset, active high)
  signal SensRight      : std_ulogic := '0';
  signal SensLeft       : std_ulogic := '0';
  signal MotorRight_pos : std_ulogic := '0';             -- Selects the target speed level left motor (HIGH = 95%, MID = 50%, MIN = 15%, STILL = 0%)
  signal MotorLeft_pos  : std_ulogic := '0';             -- Selects the target speed level right motor (HIGH = 95%, MID = 50%, MIN = 15%, STILL = 0%)
  signal MotorRight_neg : std_ulogic := '0';             -- Rotation direction for the right motor output
  signal MotorLeft_neg  : std_ulogic := '0';             -- Rotation direction for the left motor output
  signal seg            : std_ulogic_vector(6 downto 0) := SEG_OFF; -- 7 segments display
  signal an             : std_ulogic_vector(3 downto 0) := "1111"; -- Digit position display      
  signal display_en     : std_ulogic := '0';


   -- ------------------------------------------------------------------
    -- check_motors : compares the current value of motor_left and motor_right pos and neg with the
    -- expected level. On mismatch, reports an error and increments the
    -- error counter.
    -- ------------------------------------------------------------------
  procedure check_motors(
      constant expected_motor_Left_pos  : in    std_ulogic;
      constant expected_motor_Right_pos : in    std_ulogic;
      constant expected_motor_Left_neg  : in    std_ulogic;
      constant expected_motor_Right_neg : in    std_ulogic;
      variable count                    : inout integer) is
  begin
    if (MotorRight_pos /= expected_motor_Right_pos) then
      report "Error MotorRight_pos should be equal to " & std_ulogic'image(expected_motor_Right_pos) & " but got " & std_ulogic'image(MotorRight_pos)
        severity error;
      count := count + 1;
    end if;

    if (MotorLeft_pos /= expected_motor_Left_pos) then
      report "Error MotorLeft_pos should be equal to " & std_ulogic'image(expected_motor_Left_pos) & " but got " & std_ulogic'image(MotorLeft_pos)
        severity error;
      count := count + 1;
    end if;

    if (MotorRight_neg /= expected_motor_Right_neg) then
      report "Error MotorRight_neg should be equal to " & std_ulogic'image(expected_motor_Right_neg) & " but got " & std_ulogic'image(MotorRight_neg)
        severity error;
      count := count + 1;
    end if;

    if (MotorLeft_neg /= expected_motor_Left_neg) then
      report "Error MotorLeft_neg should be equal to " & std_ulogic'image(expected_motor_Left_neg) & " but got " & std_ulogic'image(MotorLeft_neg)
        severity error;
      count := count + 1;
    end if;
  end procedure;

  procedure check_7_segments(
      constant expected_an_v : in    std_ulogic_vector(3 downto 0);
      constant expected_seg  : in    std_ulogic_vector(6 downto 0);
      variable count         : inout integer) is
  begin
    if (an /= expected_an_v) then
      report "Error an vector should be equal to " & slv_to_hstring(expected_an_v) & " but got " & slv_to_hstring(an)
        severity error;
      count := count + 1;
    end if;

    if (seg /= expected_seg) then
      report "Error segment vector should be equal to " & slv_to_hstring(expected_seg) & " but got " & slv_to_hstring(seg)
        severity error;
      count := count + 1;
    end if;
  end procedure;

begin

  -- ------------------------------------------------------------------
  -- Device Under Test
  -- ------------------------------------------------------------------
  DUT_top: entity work.top
    generic map (
      DEBOUNCE_CYCLES => DEBOUNCE_CYCLES
    )
    port map (
      clk_i          => clk,
      btn_L          => btn_L,
      Start_Stop_btn => StartStop_btn,
      SensRight      => SensRight,
      SensLeft       => SensLeft,
      MotorRight_pos => MotorRight_pos,
      MotorLeft_pos  => MotorLeft_pos,
      MotorRight_neg => MotorRight_neg,
      MotorLeft_neg  => MotorLeft_neg,
      display_en     => display_en,
      seg            => seg,
      an             => an
    );

  -- ------------------------------------------------------------------
  -- Clock generation : 100 MHz
  -- ------------------------------------------------------------------
  clk <= not clk after CLK_PERIOD / 2;

  -- ------------------------------------------------------------------
  -- Clock generation : 1 KHz (sampling reference for the display)
  -- NOTE: this clock is NOT synchronized with the DUT 1 kHz divider.
  -- Its rising edges (500 us + k*1 ms) fall in the middle of each
  -- display digit (the DUT switches digits at ~k*1 ms), giving a safe
  -- sampling margin. The digit order checked in TEST 6 relies on the
  -- elapsed time before TEST 6 being aligned with the 4-digit scan
  -- (count = 0 at the first check): changing a wait duration in a
  -- previous test may shift the expected digit order.
  -- ------------------------------------------------------------------
  clk_1kHZ <= not clk_1kHZ after CLK_PERIOD_1KHZ / 2;

  -- ------------------------------------------------------------------
  -- Clock generation : 5 KHz (sampling reference for the PWM outputs)
  -- NOTE: this clock is NOT synchronized with the DUT 5 kHz divider.
  -- Its rising edges (100 us + k*200 us) fall in the middle of each
  -- PWM step (the DUT counter increments at ~200 us + k*200 us), giving
  -- a safe sampling margin. The loop index i matches the DUT PWM counter
  -- only because the elapsed time before each test is aligned with the
  -- 20 ms PWM period: changing a wait duration may shift i and make the
  -- duty cycle boundary checks (50 / 95) fail without any RTL bug.
  -- ------------------------------------------------------------------
  clk_5kHZ <= not clk_5kHZ after CLK_5KHZ_PERIOD / 2;

  -- ------------------------------------------------------------------
  -- Stimulus
  -- ------------------------------------------------------------------
  STIM: process
    variable error_count    : integer                       := 0;
    variable expected_an    : std_ulogic_vector(3 downto 0) := (others => '0');
    variable expected_7_seg : std_ulogic_vector(6 downto 0) := (others => '0');

  begin

    -- ------------------------------------------------------------------
    -- TEST 1 : IDLE state and no display
    --   No Start pulse yet : StartStop is in STOP, so the direction FSM
    --   stays in IDLE with both speeds at STILL.
    --   Expected : all motor outputs at 0 during a full PWM period
    --   (100 samples), display off (an = "1111", seg = SEG_OFF).
    -- ------------------------------------------------------------------
    SensRight <= '0';
    SensLeft <= '0';
    StartStop_btn <= '0';
    btn_L <= '0';
    display_en <= '0';
    expected_an := "1111";
    expected_7_seg := SEG_OFF;

    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait for 0 ns;

    for j in 0 to 10_000 loop
      wait until rising_edge(clk);
    end loop;
    wait for 0 ns;

    for i in 0 to N - 1 loop

      check_7_segments(expected_an, expected_7_seg, error_count);
      check_motors('0', '0', '0', '0', error_count);

      wait until rising_edge(clk_5kHZ);
      wait for 0 ns;

    end loop;

    if error_count = 0 then
      report "TEST 1 PASSED" severity note;
    else
      report "TEST 1 FINISHED WITH " & integer'image(error_count) & " ERROR(S)"
        severity failure;
    end if;

    -- ------------------------------------------------------------------
    -- TEST 2 :  START state, MOVEFORWARD and no display
    --   Start_Stop_btn is held longer than DEBOUNCE_CYCLES to generate a
    --   single Start pulse (STOP -> START). Sensors "00" -> MOVESTRAIGHT.
    --   Expected : both motors at HIGH (95%) -> pos = '1' for steps 0..94,
    --   '0' for steps 95..99. neg outputs always '0' (forward only).
    --   Display still off.
    -- ------------------------------------------------------------------
    StartStop_btn <= '1';
    expected_an := "1111";
    expected_7_seg := SEG_OFF;

    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait for 0 ns;

    for j in 0 to 10_000 loop
      wait until rising_edge(clk);
    end loop;
    wait for 0 ns;

    StartStop_btn <= '0';
    wait until rising_edge(clk);
    wait for 0 ns;

    SensRight <= '0';
    SensLeft <= '0';
    
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait for 0 ns;

    for i in 0 to N-1 loop

      check_7_segments(expected_an, expected_7_seg, error_count);

      if (i < HIGH_DUTY) then
        check_motors('1', '1', '0', '0', error_count);
      else
        check_motors('0', '0', '0', '0', error_count);
      end if;
    
      wait until rising_edge(clk_5kHZ);
      wait for 0 ns;
      
    end loop;

    if error_count = 0 then
      report "TEST 2 PASSED" severity note;
    else
      report "TEST 2 FINISHED WITH " & integer'image(error_count) & " ERROR(S)"
        severity failure;
    end if;

    -- ------------------------------------------------------------------
    -- TEST 3 :  START state, TURNLEFT and no display
    --   Sensors "10" (SensLeft = '1') -> TURNLEFT : left motor slowed down.
    --   Expected : left = MID (50%), right = HIGH (95%)
    --     steps  0..49 : L = '1', R = '1'
    --     steps 50..94 : L = '0', R = '1'
    --     steps 95..99 : L = '0', R = '0'
    -- ------------------------------------------------------------------
    SensRight <= '0';
    SensLeft  <= '1';

    for k in 0 to 5 loop
        wait until rising_edge(clk);
    end loop;
    wait for 0 ns;

    for i in 0 to N-1 loop

      check_7_segments(expected_an, expected_7_seg, error_count);

      if (i < MID_DUTY) then
        check_motors('1', '1', '0', '0', error_count);

      elsif (i < HIGH_DUTY) then
        check_motors('0', '1', '0', '0', error_count);

      else 
        check_motors('0', '0', '0', '0', error_count);
      end if;
    
      wait until rising_edge(clk_5kHZ);
      wait for 0 ns;

    end loop;
    
    if error_count = 0 then
      report "TEST 3 PASSED" severity note;
    else
      report "TEST 3 FINISHED WITH " & integer'image(error_count) & " ERROR(S)"
        severity failure;
    end if;
    

    -- ------------------------------------------------------------------
    -- TEST 4 :  START state, TURNRIGHT and no display
    --   Sensors "01" (SensRight = '1') -> TURNRIGHT : right motor slowed down.
    --   Expected : left = HIGH (95%), right = MID (50%)
    --     steps  0..49 : L = '1', R = '1'
    --     steps 50..94 : L = '1', R = '0'
    --     steps 95..99 : L = '0', R = '0'
    -- ------------------------------------------------------------------
    SensRight <= '1';
    SensLeft  <= '0';

    for k in 0 to 5 loop
        wait until rising_edge(clk);
    end loop;
    wait for 0 ns;


    for i in 0 to N-1 loop

      check_7_segments(expected_an, expected_7_seg, error_count);

      if (i < MID_DUTY) then
        check_motors('1', '1', '0', '0', error_count);

      elsif (i < HIGH_DUTY) then
        check_motors('1', '0', '0', '0', error_count);

      else 
        check_motors('0', '0', '0', '0', error_count);
      end if;
    
      wait until rising_edge(clk_5kHZ);
      wait for 0 ns;

    end loop;
    
    if error_count = 0 then
      report "TEST 4 PASSED" severity note;
    else
      report "TEST 4 FINISHED WITH " & integer'image(error_count) & " ERROR(S)"
        severity failure;
    end if;

    -- ------------------------------------------------------------------
    -- TEST 5 :  START state, TURNAROUND and no display
    --   Sensors "11" (both sensors) -> TURNAROUND, done by turning left.
    --   Expected : left = STILL (0%), right = HIGH (95%)
    --     steps  0..94 : L = '0', R = '1'
    --     steps 95..99 : L = '0', R = '0'
    -- ------------------------------------------------------------------
    SensRight <= '1';
    SensLeft <= '1';

    for k in 0 to 6 loop
        wait until rising_edge(clk);
    end loop;
    wait for 0 ns;


    for i in 0 to N-1 loop

      check_7_segments(expected_an, expected_7_seg, error_count);

      if (i < HIGH_DUTY) then
        check_motors('0', '1', '0', '0', error_count);

      else 
        check_motors('0', '0', '0', '0', error_count);
      end if;
    
      wait until rising_edge(clk_5kHZ);
      wait for 0 ns;

    end loop;   
    
    if error_count = 0 then
      report "TEST 5 PASSED" severity note;
    else
      report "TEST 5 FINISHED WITH " & integer'image(error_count) & " ERROR(S)"
        severity failure;
    end if;

    -- ------------------------------------------------------------------
    -- TEST 6 :  Display 7 segments
    --   display_en = '1' : the 4 digits are scanned at 1 kHz and show the
    --   duty cycle (%) of each motor (an3 an2 | an1 an0 = left | right).
    --   Each digit is sampled once per scan, 100 scans per case :
    --     a) MOVESTRAIGHT (sensors "00") : expected "95 95"
    --        an0 = 5, an1 = 9, an2 = 5, an3 = 9
    --     b) TURNRIGHT    (sensors "01") : expected "95 50"
    --        an0 = 0, an1 = 5, an2 = 5, an3 = 9
    -- ------------------------------------------------------------------
    SensRight <= '0';
    SensLeft <= '0';
    display_en <= '1';

    for k in 0 to 6 loop
        wait until rising_edge(clk);
    end loop;
    wait for 0 ns;

    for i in 0 to N-1 loop

        expected_an := "1110";
        expected_7_seg := SEG_5;

        -- First digit
        wait until rising_edge(clk_1kHZ);
        wait for 0 ns;
        check_7_segments(expected_an, expected_7_seg, error_count);

        expected_an := "1101";
        expected_7_seg := SEG_9;

        -- Second digit
        wait until rising_edge(clk_1kHZ);
        wait for 0 ns;
        check_7_segments(expected_an, expected_7_seg, error_count);

        expected_an := "1011";
        expected_7_seg := SEG_5;

        -- Third digit
        wait until rising_edge(clk_1kHZ);
        wait for 0 ns;
        check_7_segments(expected_an, expected_7_seg, error_count);

        expected_an := "0111";
        expected_7_seg := SEG_9;

        -- Fourth digit
        wait until rising_edge(clk_1kHZ);
        wait for 0 ns;
        check_7_segments(expected_an, expected_7_seg, error_count);
        
    end loop;
    

    SensRight <= '1';
    SensLeft <= '0';
    display_en <= '1';

    for k in 0 to 6 loop
        wait until rising_edge(clk);
    end loop;
    wait for 0 ns;

    for i in 0 to N-1 loop
        
        expected_an := "1110";
        expected_7_seg := SEG_0;

        -- First digit
        wait until rising_edge(clk_1kHZ);
        wait for 0 ns;
        check_7_segments(expected_an, expected_7_seg, error_count);

        expected_an := "1101";
        expected_7_seg := SEG_5;

        -- Second digit
        wait until rising_edge(clk_1kHZ);
        wait for 0 ns;
        check_7_segments(expected_an, expected_7_seg, error_count);

        expected_an := "1011";
        expected_7_seg := SEG_5;

        -- Third digit
        wait until rising_edge(clk_1kHZ);
        wait for 0 ns;
        check_7_segments(expected_an, expected_7_seg, error_count);

        expected_an := "0111";
        expected_7_seg := SEG_9;

        -- Fourth digit
        wait until rising_edge(clk_1kHZ);
        wait for 0 ns;
        check_7_segments(expected_an, expected_7_seg, error_count);
        
    end loop;

    if error_count = 0 then
      report "TEST 6 PASSED" severity note;
    else
      report "TEST 6 FINISHED WITH " & integer'image(error_count) & " ERROR(S)"
        severity failure;
    end if;

    -- ------------------------------------------------------------------
    -- TEST 7 : Reset (btn_L, asynchronous)
    --   The drone is moving (TURNRIGHT) and the display is enabled.
    --   a) While btn_L is held : motors are stopped and the display scan
    --      counter is frozen at 0 (digit 0 selected, speed STILL -> "0").
    --   b) After release : StartStop is back in STOP, so the drone must
    --      stay still (motors at 0, display "00 00") even with sensors set.
    -- ------------------------------------------------------------------
    btn_L <= '1';

    for k in 0 to 2 loop
        wait until rising_edge(clk);
    end loop;
    wait for 0 ns;

    -- a) Reset held during 4 display periods : count must stay at 0
    for i in 0 to 3 loop
        check_motors('0', '0', '0', '0', error_count);
        check_7_segments("1110", SEG_0, error_count);

        wait until rising_edge(clk_1kHZ);
        wait for 0 ns;
    end loop;

    -- b) Release reset : drone must remain stopped (no Start pulse)
    btn_L <= '0';

    for k in 0 to 2 loop
        wait until rising_edge(clk);
    end loop;
    wait for 0 ns;

    for i in 0 to N-1 loop
        -- After reset the DUT dividers restart, so the scanned digit is not
        -- aligned with the testbench clock anymore : only seg is checked
        -- (every digit shows 0 since both speeds are STILL).
        check_motors('0', '0', '0', '0', error_count);
        if (seg /= SEG_0) then
          report "Error segment vector should be equal to " & slv_to_hstring(SEG_0) & " but got " & slv_to_hstring(seg)
            severity error;
          error_count := error_count + 1;
        end if;

        wait until rising_edge(clk_5kHZ);
        wait for 0 ns;
    end loop;

    if error_count = 0 then
      report "TEST 7 PASSED" severity note;
    else
      report "TEST 7 FINISHED WITH " & integer'image(error_count) & " ERROR(S)"
        severity failure;
    end if;

    -- ================================================================
    -- Fin de simulation
    -- ================================================================
    if error_count = 0 then
      report "ALL TESTS PASSED" severity note;
    else
      report "SIMULATION FINISHED WITH " & integer'image(error_count) & " ERROR(S)"
        severity failure;
    end if;
    report "End of simulation" severity failure;
    wait;

  end process;

end architecture;
