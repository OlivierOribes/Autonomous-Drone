-- ==============================================================================
--  Module      : StartStop testbench      
--  File        : startstop_tb.vhd
--
--  Description : StartStop testbench. Check that an asynchronous input allows
--                moving from one state to another, going through all states. 
--      
--  Component   : DRONE 
--               
--  Author      : Olivier Oribes
--  Created     : 03/11/2026
--  Last update : 03/11/2026
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


entity StartStop_tb is
end entity StartStop_tb;


architecture sim of StartStop_tb is

    constant CLK_PERIOD   : time := 10 ns;    -- 100 MHz clock
    constant DEBOUNCE     : natural := 1_000; -- Reduced debounce time for simulation

    signal clk            : std_ulogic := '0'; 
    signal StartStop_btn  : std_ulogic := '0';
    signal rstn           : std_ulogic := '1';
    signal move           : std_ulogic := '0';
    
begin


    -- ------------------------------------------------------------------
    -- Device Under Test
    -- ------------------------------------------------------------------
    DUT_StartStop : entity work.StartStop
    generic map(
        DEBOUNCE_CYCLES  => DEBOUNCE
    )
    port map(
        clk_i            => clk,
        Start_Stop_btn_i => StartStop_btn,
        rstn_i           => rstn,
        move_o           => move
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

        -- Hold the button high for nb_cycles clock cycles, then release it
        -- for 10 cycles (sync + debounce + pulse + FSM latency)
        procedure press_button(nb_cycles : in natural) is
        begin
            StartStop_btn <= '1';
            for i in 1 to nb_cycles loop
                wait until rising_edge(clk);
            end loop;
            StartStop_btn <= '0';
            for i in 1 to 10 loop
                wait until rising_edge(clk);
            end loop;
            wait for 1 ns;
        end procedure;

        -- Compare move_o with the expected value
        procedure check_move(expected : in std_ulogic; 
                             msg : in string) is
        begin
            if (move /= expected) then
                report "Error (" & msg & ") move_o should be equal to " &
                    std_ulogic'image(expected) & " but got " &
                    std_ulogic'image(move)
                    severity error;
                error_count := error_count + 1;
            end if;
        end procedure;

    begin   

        -- Initial state : STOP
        wait until rising_edge(clk);
        wait for 1 ns;
        check_move('0', "initial state");

        -- ------------------------------------------------------------------
        -- Push Button test
        --  The button goes through a 2-stage sync and a debounce counter
        --  (DEBOUNCE cycles). Each stable press gives ONE pulse that toggles
        --  the FSM (STOP <-> START), move_o = '1' only in START.
        --    - glitch shorter than DEBOUNCE      -> no toggle (move stays '0')
        --    - long presses                      -> toggle on each press
        --    - button held 5 x DEBOUNCE          -> a single toggle only
        --    - last press brings the FSM back to START for the reset test
        -- ------------------------------------------------------------------

        -- Glitch shorter than the debounce time : no toggle
        press_button(DEBOUNCE / 2);
        check_move('0', "short glitch");

        -- Long press : STOP -> START
        press_button(DEBOUNCE + 10);
        check_move('1', "1st press");

        -- Long press : START -> STOP
        press_button(DEBOUNCE + 10);
        check_move('0', "2nd press");

        -- Long press : STOP -> START
        press_button(DEBOUNCE + 10);
        check_move('1', "3rd press");

        -- Button held a long time : only one toggle (START -> STOP)
        press_button(5 * DEBOUNCE);
        check_move('0', "long hold");

        -- Back to START before the reset test
        press_button(DEBOUNCE + 10);
        check_move('1', "5th press");


        -- ------------------------------------------------------------------
        -- Reset test
        --  rstn = '0' while in START : asynchronous reset -> move_o = '0'
        --  immediately (no clock edge needed).
        --  After release : FSM stays in STOP (move_o = '0') without any press.
        -- ------------------------------------------------------------------

        rstn <= '0';
        wait for 1 ns;
        check_move('0', "reset");

        rstn <= '1';
        wait until rising_edge(clk);
        wait for 1 ns;
        check_move('0', "after reset");


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

    end process STIM;

end architecture sim;
