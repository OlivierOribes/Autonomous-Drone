# =============================================================================
# drone_constraint.xdc
# Pin constraints for BE drone (Basys3 - top.vhd)
#
#
# ── SIGNAL MAPPING SUMMARY ──────────────────────────────────────────────────
#  clk_i          → PL 100 MHz oscillator              (W5)
#  btn_L          → Push button btnL (Reset, rstn_i = not btn_L)  (W19)
#  Start_Stop_btn → Push button btnC (BP_start_stop)   (U18)
#  display_en     → Push button btnD (display enable)  (U17)
#  MotorLeft_pos  → JB7  (Moteur gauche)               (A15)
#  MotorLeft_neg  → JB8  (Moteur gauche)               (A17)
#  MotorRight_pos → JC9  (Moteur droit)                (P17)
#  MotorRight_neg → JC10 (Moteur droit)                (R18)
#  SensLeft       → Detector left                      (P18)
#  SensRight      → Detector right                     (B16)
#  seg[6:0]       → 7-segment display segments         (W7, W6, U8, V8, U5, V5, U7)
#  an[3:0]        → 7-segment display anodes           (U2, U4, V4, W4)
# =============================================================================


set_property -dict { PACKAGE_PIN W5 IOSTANDARD LVCMOS33 } [get_ports { clk_i }]
create_clock -name sys_clk -period 10.000 -waveform {0.000 5.000} [get_ports { clk_i }]

# -----------------------------------------------------------------------------
# # BP_start_stop
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports { Start_Stop_btn }]

# -----------------------------------------------------------------------------
# # reset button
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports { btn_L }]

# -----------------------------------------------------------------------------
# # Display digit enable
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports { display_en }]


##Sch name = JB7 = Moteur gauche -
set_property PACKAGE_PIN A15 [get_ports MotorLeft_pos]
set_property IOSTANDARD LVCMOS33 [get_ports MotorLeft_pos]
##Sch name = JB8 = Moteur gauche +
set_property PACKAGE_PIN A17 [get_ports MotorLeft_neg]
set_property IOSTANDARD LVCMOS33 [get_ports MotorLeft_neg]

##Sch name = JC9 => => Moteur droit-
set_property PACKAGE_PIN P17 [get_ports MotorRight_pos]
set_property IOSTANDARD LVCMOS33 [get_ports MotorRight_pos]
##Sch name = JC10 => Moteur droit +
set_property PACKAGE_PIN R18 [get_ports MotorRight_neg]
set_property IOSTANDARD LVCMOS33 [get_ports MotorRight_neg ]

# detector right
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports { SensRight}]
# detector left
set_property -dict { PACKAGE_PIN B16 IOSTANDARD LVCMOS33 } [get_ports { SensLeft }]

##7 segment display
# Bus 'seg' (7 bits)
set_property -dict { PACKAGE_PIN W7 IOSTANDARD LVCMOS33 } [get_ports { seg[0] }]
set_property -dict { PACKAGE_PIN W6 IOSTANDARD LVCMOS33 } [get_ports { seg[1] }]
set_property -dict { PACKAGE_PIN U8 IOSTANDARD LVCMOS33 } [get_ports { seg[2] }]
set_property -dict { PACKAGE_PIN V8 IOSTANDARD LVCMOS33 } [get_ports { seg[3] }]
set_property -dict { PACKAGE_PIN U5 IOSTANDARD LVCMOS33 } [get_ports { seg[4] }]
set_property -dict { PACKAGE_PIN V5 IOSTANDARD LVCMOS33 } [get_ports { seg[5] }]
set_property -dict { PACKAGE_PIN U7 IOSTANDARD LVCMOS33 } [get_ports { seg[6] }]

# Bus 'an' (4 bits)
set_property -dict { PACKAGE_PIN U2 IOSTANDARD LVCMOS33 } [get_ports { an[0] }]
set_property -dict { PACKAGE_PIN U4 IOSTANDARD LVCMOS33 } [get_ports { an[1] }]
set_property -dict { PACKAGE_PIN V4 IOSTANDARD LVCMOS33 } [get_ports { an[2] }]
set_property -dict { PACKAGE_PIN W4 IOSTANDARD LVCMOS33 } [get_ports { an[3] }]