-- ==============================================================================
--  Module      : Top
--  File        : top.vhd
--
--  Description : Top-level of the drone controller. Instantiates the
--                Start/Stop control, the direction logic (driven by the left
--                and right sensors) and two 50 Hz PWM generators for the motors.
--                Also drives a 4-digit 7-segment display (1 kHz scan) showing
--                the duty cycle (%) of each motor: right on digits 0-1,
--                left on digits 2-3.
--
--  Component   : TOP
--
--  Author      : Olivier Oribes
--  Created     : 02/11/2026
--  Last update : 03/11/2026
--
--  Version     : 1.1
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

library work;
use work.drone_pkg.all;

entity top is 
generic(
    DEBOUNCE_CYCLES : natural := 1_000_000
);
port
(
    clk_i           : in  std_ulogic;  -- input clock (100 Mhz basys3 clock)
    SensRight       : in  std_ulogic;  -- Sensor right
    SensLeft        : in  std_ulogic;  -- Sensor left
    Start_Stop_btn  : in  std_ulogic;  -- Enable button active high
    btn_L           : in  std_ulogic;  -- btn L
    MotorRight_pos  : out std_ulogic; -- Right motor rotation (0 = no rotation, 1 = rotation)
    MotorLeft_pos   : out std_ulogic; -- Left motor rotation  (0 = no rotation, 1 = rotation)
    MotorRight_neg  : out std_ulogic; -- Rotation direction for the right motor  (0 = positive rotation, 1 = negative rotation)
    MotorLeft_neg   : out std_ulogic; -- Rotation direction for the left motor  (0 = positive rotation, 1 = negative rotation)
    display_en      : in  std_ulogic; -- Button from fpga to enable display
    seg             : out std_ulogic_vector(6 downto 0); -- 7 segments display
    an              : out std_ulogic_vector(3 downto 0)  -- Digit position display      
);
end entity top;


architecture rtl of top is

    signal move                   : std_ulogic := '0';  -- Drone movement control signal
    signal pwm_duty_cycle_L       : std_ulogic_vector(2 downto 0) := (others => '0'); -- Selects the target speed level left motor (HIGH = 95%, MID = 50%, MIN = 15%, STILL = 0%)
    signal pwm_duty_cycle_R       : std_ulogic_vector(2 downto 0) := (others => '0'); -- Selects the target speed level right motor (HIGH = 95%, MID = 50%, MIN = 15%, STILL = 0%)
    signal tick_1kHz              : std_ulogic := '0';
    signal count                  : natural range 0 to NB_DIGITS - 1 := 0;
    signal current_digit          : std_ulogic_vector(3 downto 0) := (others => '1');
    signal right_tens, right_unit : std_ulogic_vector(3 downto 0) := (others => '0'); -- Right Motor (R) : tens and units
    signal left_tens, left_unit   : std_ulogic_vector(3 downto 0) := (others => '0'); -- Left Motor (L)  : tens and units
    signal rstn_i                 : std_ulogic := '1' ; -- global reset (active low)
    signal MotorLeft_dir          : std_ulogic := '0'; -- Rotation direction for the left motor  (0 = positive rotation, 1 = negative rotation)
    signal MotorRight_dir         : std_ulogic := '0'; -- Rotation direction for the right motor  (0 = positive rotation, 1 = negative rotation)
    signal MotorLeft_val          : std_ulogic := '0'; -- Left motor rotation (0 = no rotation, 1 = rotation)
    signal MotorRight_val         : std_ulogic := '0'; -- Right motor rotation (0 = no rotation, 1 = rotation)
    signal display_speed          : std_ulogic := '0';

begin 

    rstn_i <= not btn_L; -- Reset (active low)

    -- StartStop instance
    Startstop_inst : entity work.StartStop
    generic map(
        DEBOUNCE_CYCLES  => DEBOUNCE_CYCLES
    )
    port map(
        clk_i            => clk_i,
        Start_Stop_btn_i => Start_Stop_btn,
        rstn_i           => rstn_i,
        move_o           => move
    );


    -- Direction instance
    direction_inst : entity work.direction
    port map(
        clk_i              => clk_i,
        rstn_i             => rstn_i,
        SensRight_i        => SensRight,
        SensLeft_i         => SensLeft,
        move_i             => move,
        pwm_duty_cycle_L_o => pwm_duty_cycle_L,
        pwm_duty_cycle_R_o => pwm_duty_cycle_R,
        MotorRight_dir_o   => MotorRight_dir,
        MotorLeft_dir_o    => MotorLeft_dir
    );

    -- PWM instance for left motor
    pwm_L_inst : entity work.pwm
    port map(
        clk_i            => clk_i, 
        rstn_i           => rstn_i,
        pwm_duty_cycle_i => pwm_duty_cycle_L,
        pwm_o            => MotorLeft_val
    );

    -- PWM instance for right motor
    pwm_R_inst : entity work.pwm
    port map(
        clk_i            => clk_i, 
        rstn_i           => rstn_i,
        pwm_duty_cycle_i => pwm_duty_cycle_R,
        pwm_o            => MotorRight_val
    );

    -- Multiplexer for right units
    right_unit <= "0101" when (pwm_duty_cycle_R = SPEED_HIGH or pwm_duty_cycle_R = SPEED_LOW) else -- 5
                  "0000"; -- 0

    -- Multiplexer for right tens 
    right_tens <= "1001" when (pwm_duty_cycle_R = SPEED_HIGH) else -- 9
                  "0101" when (pwm_duty_cycle_R = SPEED_MID) else -- 5
                  "0001" when (pwm_duty_cycle_R = SPEED_LOW) else -- 1
                  "0000"; -- 0

    -- Multiplexer for left units 
    left_unit <= "0101" when (pwm_duty_cycle_L = SPEED_HIGH or pwm_duty_cycle_L = SPEED_LOW) else -- 5
                 "0000"; -- 0

    -- Multiplexer for left tens 
    left_tens <= "1001" when (pwm_duty_cycle_L = SPEED_HIGH) else -- 9 
                 "0101" when (pwm_duty_cycle_L = SPEED_MID) else -- 5 
                 "0001" when (pwm_duty_cycle_L = SPEED_LOW) else -- 1
                 "0000"; -- 0


    MotorRight_pos <= MotorRight_val when MotorRight_dir = '0' else '0';
    MotorLeft_pos  <= MotorLeft_val when MotorLeft_dir   = '0' else '0';
    MotorRight_neg <= MotorRight_val when MotorRight_dir = '1' else '0';
    MotorLeft_neg  <= MotorLeft_val when MotorLeft_dir   = '1' else '0';

    -- -------------------------------------------------------------------------
    -- 7 SEGMENT DISPLAY
    -- -------------------------------------------------------------------------

    -- Process 1: 1 kHz Clock Divider 
    -- Divides the main 100 MHz clock down to 1 kHz by counting 100,000 cycles.
    -- Generates a single-cycle pulse signal (tick_1kHz) every 1 ms.
    proc_div_clock : process(clk_i, rstn_i)
        variable divcnt : natural range 0 to DISP_DIVID_RATIO := 0;
    begin
        if (rstn_i = '0') then
            divcnt     := 0;
            tick_1kHz <= '0';
    
        elsif rising_edge(clk_i) then
            tick_1kHz <= '0';

            if (divcnt = DISP_DIVID_RATIO) then
                tick_1kHz <= '1';
                divcnt     := 0;
            else  
                divcnt     := divcnt + 1;
            end if;
        end if;
    end process proc_div_clock;


    -- Process 2: Scan Counter Incrementer
    -- Increments the display scan index (count from 0 to 3) 
    -- only when the 1 kHz tick pulse is active, using the main clock.
    proc_tick : process(clk_i, rstn_i)
    begin
        if (rstn_i = '0') then
            count <= 0;
        elsif rising_edge(clk_i) then
            if (tick_1kHz = '1') then
                if (count = NB_DIGITS - 1) then
                    count <= 0;
                else 
                    count <= count + 1;
                end if;
            end if;
        end if;
    end process proc_tick;


    -- Process 3: Display Multiplexer (Combinational)
    -- Selects the active digit anode (temp_an) and routes the corresponding 
    -- BCD value (current_digit) based on the current scan count.
    proc_comb: process(count, right_unit, right_tens, left_unit, left_tens, display_speed)
    begin

        if (display_speed = '0') then 

            an            <= "1111";
            current_digit <= "1111";

        else   
            case count is
                when 0      => 
                    an            <= "1110"; -- Select Right Digit 0 (Units)
                    current_digit <= right_unit;

                when 1      => 
                    an            <= "1101"; -- Select Right Digit 1 (Tens)
                    current_digit <= right_tens;

                when 2      => 
                    an            <= "1011"; -- Select Left Digit 2 (Units)
                    current_digit <= left_unit;

                when 3      => 
                    an           <= "0111";  -- Select Left Digit 3 (Tens)
                    current_digit <= left_tens;

                when others => 
                    an           <= "1111";
                    current_digit <= "1111";
            end case;

        end if;
    end process proc_comb;


    -- Process 4: 7-Segment Decoder (Combinational)
    -- Translates a 4-bit value (0-9) into physical 7-segment LED patterns.
    process(current_digit)
    begin
        case current_digit is
            when "0000" => seg <= SEG_0; -- 0
            when "0001" => seg <= SEG_1; -- 1
            when "0010" => seg <= SEG_2; -- 2
            when "0011" => seg <= SEG_3; -- 3
            when "0100" => seg <= SEG_4; -- 4
            when "0101" => seg <= SEG_5; -- 5
            when "0110" => seg <= SEG_6; -- 6
            when "0111" => seg <= SEG_7; -- 7
            when "1000" => seg <= SEG_8; -- 8
            when "1001" => seg <= SEG_9; -- 9
            when others => seg <= SEG_OFF; -- Blank / Off
        end case;
    end process;


    -- Display enable toggle: synchronized + debounced on clk_i
    display_toggle_inst : entity work.StartStop
    generic map(
        DEBOUNCE_CYCLES  => DEBOUNCE_CYCLES
    )
    port map(
        clk_i            => clk_i,
        Start_Stop_btn_i => display_en,
        rstn_i           => rstn_i,
        move_o           => display_speed
    );

end architecture rtl;