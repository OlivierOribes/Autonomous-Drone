-- ==============================================================================
--  Module      : StartStop      
--  File        : StartStop.vhd
--
--  Description : Top-level control module for the drone system. Features a 
--                debounced push-button controller generating single pulses 
--                to toggle the system state between START and STOP modes.
--      
--  Component   : DRONE 
--               
--  Author      : Olivier Oribes
--  Created     : 02/11/2026
--  Last update : 02/11/2026
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

entity StartStop is
generic
(
    DEBOUNCE_CYCLES   : natural := 1_000_000  -- Debounce time in clock cycles (10 ms @ 100 MHz)
);
port
(
    clk_i             : in  std_ulogic;  -- input clock (100 Mhz basys3 clock)
    Start_Stop_btn_i  : in  std_ulogic;  -- Enable button for start and stop drone
    rstn_i            : in  std_ulogic;  -- Reset (active low)
    move_o            : out std_ulogic   -- Drone movement control output
);
end entity StartStop;

architecture rtl of StartStop is

    type state_t is (START, STOP);
    signal current_state : state_t := STOP;
    signal next_state : state_t;

    signal pulse           : std_ulogic := '0';
    signal btn_pressed     : std_ulogic := '0';
    signal btn_sync1       : std_ulogic := '0';
    signal btn_sync2       : std_ulogic := '0';
    signal debouncer_count : natural range 0 to DEBOUNCE_CYCLES := 0;
begin

    -- -------------------------------------------------------------------------
    -- Double synchronization, debounce filter, and one-shot pulse generator
    -- -------------------------------------------------------------------------
    proc_debouncer : process(clk_i, rstn_i)
    begin
        if (rstn_i = '0') then
            btn_sync1       <= '0';
            btn_sync2       <= '0';
            debouncer_count <= 0;
            pulse           <= '0';
            btn_pressed     <= '0';

        elsif rising_edge(clk_i) then
            -- 1. Double register synchronization to prevent metastability
            btn_sync1 <= Start_Stop_btn_i;
            btn_sync2 <= btn_sync1;

            -- Default value for pulse (one-shot per clock cycle)
            pulse <= '0';

            -- 2. Check if the synchronized button is pressed
            if btn_sync2 = '1' then
                if btn_pressed = '0' then
                
                    -- Button is pressed for the first time, count until stable
                    if debouncer_count < DEBOUNCE_CYCLES then
                        debouncer_count <= debouncer_count + 1;
                    else
                        -- Stable period reached: generate a single pulse and lock
                        pulse       <= '1';
                        btn_pressed <= '1'; -- Avoid continuous pulse
                    end if;
                end if;
            else
                -- Button is released: reset counter and state for the next press
                debouncer_count <= 0;
                btn_pressed     <= '0';
            end if;
        end if;
    end process proc_debouncer;


    -- -------------------------------------------------------------------------
    -- FSM Combinatorial Logic: Determines the next state based on current state 
    -- and the filtered push-button pulse (toggle behavior).
    -- ------------------------------------------------------------------------
    proc_comb : process(current_state, pulse) 
    begin

        -- Default value
        next_state <= current_state;

        case current_state is

            when START =>

                if (pulse = '1') then
                    next_state <= STOP;
                end if;

            when STOP => 

                if (pulse = '1') then
                    next_state <= START;
                end if;

            when others => 
                next_state <= STOP;
            end case;

    end process proc_comb;
    
    -- -------------------------------------------------------------------------
    -- FSM Sequential Logic: Updates the current state on the clock edge 
    -- or applies asynchronous active-low reset.
    -- -------------------------------------------------------------------------
    proc_ff : process(clk_i, rstn_i)
    begin
        
        if (rstn_i = '0') then

            current_state <= STOP;

        elsif rising_edge(clk_i) then
            current_state <= next_state;
        
        end if;
    end process proc_ff;

    move_o <= '1' when current_state = START else '0';
    
end architecture rtl;