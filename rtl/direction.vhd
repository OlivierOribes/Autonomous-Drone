-- ==============================================================================
--  Module      : direction      
--  File        : direction.vhd
--
--  Description :
--      Main control finite state machine (FSM) for a drone. Reads left and right 
--      sensors and generates target speed level commands (PWM duty cycles) 
--      for both motors based on the navigation logic.
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

library work;
use work.drone_pkg.all;

entity direction is port
(
    clk_i                : in  std_ulogic;   -- input clock (100 Mhz basys3 clock)
    SensRight_i          : in  std_ulogic;   -- Sensor right
    SensLeft_i           : in  std_ulogic;   -- Sensor left
    rstn_i               : in  std_ulogic;   -- Reset (active low)
    move_i               : in  std_ulogic;   -- Drone movement control input
    pwm_duty_cycle_L_o   : out std_ulogic_vector(2 downto 0); -- Selects the target speed level left motor (HIGH = 95%, MID = 50%, MIN = 15%, STILL = 0%)
    pwm_duty_cycle_R_o   : out std_ulogic_vector(2 downto 0); -- Selects the target speed level right motor (HIGH = 95%, MID = 50%, MIN = 15%, STILL = 0%)
    MotorRight_dir_o     : out std_ulogic; -- Rotation direction for the right motor output
    MotorLeft_dir_o      : out std_ulogic  -- Rotation direction for the left motor output

);

end entity direction;

architecture rtl of direction is

    type action_t is (IDLE, DETECT, TURNRIGHT, TURNLEFT, TURNAROUND, MOVESTRAIGHT);
    signal current_action : action_t := IDLE;

    signal speed_R       : std_ulogic_vector(2 downto 0) := SPEED_STILL; 
    signal speed_L       : std_ulogic_vector(2 downto 0) := SPEED_STILL;
    signal dir_L         : std_ulogic := '0';
    signal dir_R         : std_ulogic := '0';   
    signal sens_sync1    : std_ulogic_vector(1 downto 0) := (others => '0'); -- 1st sync stage (may go metastable)
    signal sensors       : std_ulogic_vector(1 downto 0) := (others => '0'); -- 2nd sync stage (stable, used by the FSM)

begin

    -- -------------------------------------------------------------------------
    -- Synchronisation of the input sensor signal to avoid metastability
    -- -------------------------------------------------------------------------
    proc_sync : process(clk_i, rstn_i)
    begin
        if (rstn_i = '0') then
            sens_sync1 <= (others => '0');
            sensors    <= (others => '0');

        elsif rising_edge(clk_i) then
            -- Double register synchronization to prevent metastability
            sens_sync1 <= SensLeft_i & SensRight_i;
            sensors    <= sens_sync1;
        end if;
    end process proc_sync;

    -- -------------------------------------------------------------------------
    -- Synchronous FSM process
    -- -----------------------------------------------------------------------
    proc_fsm : process(clk_i, rstn_i) 
    begin

        if (rstn_i = '0') then 

            speed_L <= SPEED_STILL; 
            speed_R <= SPEED_STILL;
            dir_L   <= DIR_FORWARD; -- default rotation direction
            dir_R   <= DIR_FORWARD; -- default rotation direction
            current_action <= IDLE;

        elsif rising_edge(clk_i) then


            if (move_i = '0') then

                dir_L   <= DIR_FORWARD;
                dir_R   <= DIR_FORWARD; 

                -- Speed is reset only when the drone is stopped, so that it is
                -- held stable while the FSM goes through DETECT
                speed_L  <= SPEED_STILL;
                speed_R  <= SPEED_STILL;
                current_action <= IDLE;

            else
                case current_action is

                    when IDLE =>

                        current_action <= DETECT;

                    when DETECT =>
                            
                        case sensors is
                            
                            when "00"   => current_action <= MOVESTRAIGHT;

                            when "01"   => current_action <= TURNRIGHT;
                            
                            when "10"   => current_action <= TURNLEFT;

                            when "11"   => current_action <= TURNAROUND;

                            when others => current_action <= IDLE;

                        end case;
                        
                    when MOVESTRAIGHT =>
                        
                        dir_L   <= DIR_FORWARD;
                        dir_R   <= DIR_FORWARD; 
                        speed_L <= SPEED_HIGH; -- HIGH (95%)
                        speed_R <= SPEED_HIGH; -- HIGH (95%)
                        current_action <= DETECT;
                    
                    when TURNLEFT =>
                        
                        dir_L   <= DIR_FORWARD;
                        dir_R   <= DIR_FORWARD;

                        -- Left wheel slower than right wheel -> drone turns left
                        speed_L <= SPEED_LOW; -- MID (15%)
                        speed_R <= SPEED_HIGH; -- HIGH (95%)
                        current_action <= DETECT;

                    when TURNRIGHT =>
                        
                        dir_L   <= DIR_FORWARD;
                        dir_R   <= DIR_FORWARD;

                        -- Right wheel slower than left wheel -> drone turns right
                        speed_L <= SPEED_HIGH; -- HIGH (95%)
                        speed_R <= SPEED_LOW; -- MID (15%)
                        current_action <= DETECT;

                    when TURNAROUND =>  
                    
                        dir_L   <= DIR_BACKWARD;
                        dir_R   <= DIR_FORWARD;

                        -- We choose to turn left for turn around
                        speed_L <= SPEED_MID; -- MID (50%)
                        speed_R <= SPEED_HIGH; -- HIGH (95%)
                        current_action <= DETECT;
                    
                    when others =>
                        
                        current_action <= IDLE;
                end case;
            end if;
        end if;

    end process proc_fsm;
                    
    pwm_duty_cycle_L_o <= speed_L;
    pwm_duty_cycle_R_o <= speed_R;
    MotorRight_dir_o   <= dir_R;
    MotorLeft_dir_o    <= dir_L;
 
end architecture rtl;