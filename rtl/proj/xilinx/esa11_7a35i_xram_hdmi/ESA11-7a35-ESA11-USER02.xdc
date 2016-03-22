# BaseBoard = ESA11-7a35 AddOn =  ESA11-USER02

#
#	Buttons -------------------------------------------------------------------
#
#set_property PACKAGE_PIN U5 [get_ports M_BTN[0]]
set_property PACKAGE_PIN U7 [get_ports M_BTN[0]]
set_property IOSTANDARD LVTTL  [get_ports M_BTN[0]]
set_property PULLUP TRUE [get_ports M_BTN[0]]
set_property DRIVE 4  [get_ports M_BTN[0]]

set_property PACKAGE_PIN U6 [get_ports M_BTN[1]]
set_property IOSTANDARD LVTTL  [get_ports M_BTN[1]]
set_property PULLUP TRUE [get_ports M_BTN[1]]
set_property DRIVE 4  [get_ports M_BTN[1]]

set_property PACKAGE_PIN T6 [get_ports M_BTN[2]]
set_property IOSTANDARD LVTTL  [get_ports M_BTN[2]]
set_property PULLUP TRUE [get_ports M_BTN[2]]
set_property DRIVE 4  [get_ports M_BTN[2]]

#set_property PACKAGE_PIN U7 [get_ports M_BTN[3]]
set_property PACKAGE_PIN R6 [get_ports M_BTN[3]]
set_property IOSTANDARD LVTTL  [get_ports M_BTN[3]]
set_property PULLUP TRUE [get_ports M_BTN[3]]
set_property DRIVE 4  [get_ports M_BTN[3]]

#set_property PACKAGE_PIN R6 [get_ports M_BTN[4]]
#set_property PACKAGE_PIN U7 [get_ports M_BTN[4]]
set_property PACKAGE_PIN U5 [get_ports M_BTN[4]]
set_property IOSTANDARD LVTTL  [get_ports M_BTN[4]]
set_property PULLUP TRUE [get_ports M_BTN[4]]
set_property DRIVE 4  [get_ports M_BTN[4]]

#
#	Hex-Switch ----------------------------------------------------------------
#
set_property PACKAGE_PIN V17 [get_ports M_HEX[0]]
set_property IOSTANDARD LVTTL  [get_ports M_HEX[0]]
set_property DRIVE 4  [get_ports M_HEX[0]]

set_property PACKAGE_PIN R17 [get_ports M_HEX[1]]
set_property IOSTANDARD LVTTL  [get_ports M_HEX[1]]
set_property DRIVE 4  [get_ports M_HEX[1]]

set_property PACKAGE_PIN AA19 [get_ports M_HEX[2]]
set_property IOSTANDARD LVTTL  [get_ports M_HEX[2]]
set_property DRIVE 4  [get_ports M_HEX[2]]

set_property PACKAGE_PIN AA20 [get_ports M_HEX[3]]
set_property IOSTANDARD LVTTL  [get_ports M_HEX[3]]
set_property DRIVE 4  [get_ports M_HEX[3]]

#
#	LEDs ----------------------------------------------------------------------
#
set_property PACKAGE_PIN AB1 [get_ports M_LED[0]]
set_property IOSTANDARD LVTTL  [get_ports M_LED[0]]
set_property DRIVE 4  [get_ports M_LED[0]]

set_property PACKAGE_PIN AA1 [get_ports M_LED[1]]
set_property IOSTANDARD LVTTL  [get_ports M_LED[1]]
set_property DRIVE 4  [get_ports M_LED[1]]

set_property PACKAGE_PIN V9 [get_ports M_LED[2]]
set_property IOSTANDARD LVTTL  [get_ports M_LED[2]]
set_property DRIVE 4  [get_ports M_LED[2]]

set_property PACKAGE_PIN W9 [get_ports M_LED[3]]
set_property IOSTANDARD LVTTL  [get_ports M_LED[3]]
set_property DRIVE 4  [get_ports M_LED[3]]

set_property PACKAGE_PIN P14 [get_ports M_LED[4]]
set_property IOSTANDARD LVTTL  [get_ports M_LED[4]]
set_property DRIVE 4  [get_ports M_LED[4]]

set_property PACKAGE_PIN P15 [get_ports M_LED[5]]
set_property IOSTANDARD LVTTL  [get_ports M_LED[5]]
set_property DRIVE 4  [get_ports M_LED[5]]

set_property PACKAGE_PIN P20 [get_ports M_LED[6]]
set_property IOSTANDARD LVTTL  [get_ports M_LED[6]]
set_property DRIVE 4  [get_ports M_LED[6]]

set_property PACKAGE_PIN P21 [get_ports M_LED[7]]
set_property IOSTANDARD LVTTL  [get_ports M_LED[7]]
set_property DRIVE 4  [get_ports M_LED[7]]

#
#	DIP Switch ---------------------------------------------------------------
#
# set_property PACKAGE_PIN Y22 [get_ports M_DIP[0]]
# set_property IOSTANDARD LVTTL  [get_ports M_DIP[0]]
# set_property DRIVE 4  [get_ports M_DIP[0]]

# set_property PACKAGE_PIN V19 [get_ports M_DIP[1]]
# set_property IOSTANDARD LVTTL  [get_ports M_DIP[1]]
# set_property DRIVE 4  [get_ports M_DIP[1]]

# set_property PACKAGE_PIN W21 [get_ports M_DIP[2]]
# set_property IOSTANDARD LVTTL  [get_ports M_DIP[2]]
# set_property DRIVE 4  [get_ports M_DIP[2]]

# set_property PACKAGE_PIN W22 [get_ports M_DIP[3]]
# set_property IOSTANDARD LVTTL  [get_ports M_DIP[3]]
# set_property DRIVE 4  [get_ports M_DIP[3]]

#
#	EXPMODs -------------------------------------------------------------------
#
set_property PACKAGE_PIN Y4 [get_ports M_EXPMOD0[0]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD0[0]]
set_property DRIVE 4  [get_ports M_EXPMOD0[0]]

set_property PACKAGE_PIN AA8 [get_ports M_EXPMOD0[1]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD0[1]]
set_property DRIVE 4  [get_ports M_EXPMOD0[1]]

set_property PACKAGE_PIN R3 [get_ports M_EXPMOD0[2]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD0[2]]
set_property DRIVE 4  [get_ports M_EXPMOD0[2]]

set_property PACKAGE_PIN W4 [get_ports M_EXPMOD0[3]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD0[3]]
set_property DRIVE 4  [get_ports M_EXPMOD0[3]]

set_property PACKAGE_PIN W2 [get_ports M_EXPMOD0[4]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD0[4]]
set_property DRIVE 4  [get_ports M_EXPMOD0[4]]

set_property PACKAGE_PIN Y3 [get_ports M_EXPMOD0[5]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD0[5]]
set_property DRIVE 4  [get_ports M_EXPMOD0[5]]

set_property PACKAGE_PIN V4 [get_ports M_EXPMOD0[6]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD0[6]]
set_property DRIVE 4  [get_ports M_EXPMOD0[6]]

set_property PACKAGE_PIN R2 [get_ports M_EXPMOD0[7]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD0[7]]
set_property DRIVE 4  [get_ports M_EXPMOD0[7]]

set_property PACKAGE_PIN W7 [get_ports M_EXPMOD1[0]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD1[0]]
set_property DRIVE 4  [get_ports M_EXPMOD1[0]]

set_property PACKAGE_PIN Y7 [get_ports M_EXPMOD1[1]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD1[1]]
set_property DRIVE 4  [get_ports M_EXPMOD1[1]]

set_property PACKAGE_PIN W6 [get_ports M_EXPMOD1[2]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD1[2]]
set_property DRIVE 4  [get_ports M_EXPMOD1[2]]

set_property PACKAGE_PIN Y6 [get_ports M_EXPMOD1[3]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD1[3]]
set_property DRIVE 4  [get_ports M_EXPMOD1[3]]

set_property PACKAGE_PIN W5 [get_ports M_EXPMOD1[4]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD1[4]]
set_property DRIVE 4  [get_ports M_EXPMOD1[4]]

set_property PACKAGE_PIN Y9 [get_ports M_EXPMOD1[5]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD1[5]]
set_property DRIVE 4  [get_ports M_EXPMOD1[5]]

set_property PACKAGE_PIN T3 [get_ports M_EXPMOD1[6]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD1[6]]
set_property DRIVE 4  [get_ports M_EXPMOD1[6]]

set_property PACKAGE_PIN V8 [get_ports M_EXPMOD1[7]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD1[7]]
set_property DRIVE 4  [get_ports M_EXPMOD1[7]]

set_property PACKAGE_PIN P16 [get_ports M_EXPMOD2[0]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD2[0]]
set_property DRIVE 4  [get_ports M_EXPMOD2[0]]

set_property PACKAGE_PIN U17 [get_ports M_EXPMOD2[1]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD2[1]]
set_property DRIVE 4  [get_ports M_EXPMOD2[1]]

set_property PACKAGE_PIN AA18 [get_ports M_EXPMOD2[2]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD2[2]]
set_property DRIVE 4  [get_ports M_EXPMOD2[2]]

set_property PACKAGE_PIN W17 [get_ports M_EXPMOD2[3]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD2[3]]
set_property DRIVE 4  [get_ports M_EXPMOD2[3]]

set_property PACKAGE_PIN R16 [get_ports M_EXPMOD2[4]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD2[4]]
set_property DRIVE 4  [get_ports M_EXPMOD2[4]]

set_property PACKAGE_PIN AB18 [get_ports M_EXPMOD2[5]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD2[5]]
set_property DRIVE 4  [get_ports M_EXPMOD2[5]]

set_property PACKAGE_PIN R14 [get_ports M_EXPMOD2[6]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD2[6]]
set_property DRIVE 4  [get_ports M_EXPMOD2[6]]

set_property PACKAGE_PIN AB20 [get_ports M_EXPMOD2[7]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD2[7]]
set_property DRIVE 4  [get_ports M_EXPMOD2[7]]

set_property PACKAGE_PIN V18 [get_ports M_EXPMOD3[0]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD3[0]]
set_property DRIVE 4  [get_ports M_EXPMOD3[0]]

set_property PACKAGE_PIN AA21 [get_ports M_EXPMOD3[1]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD3[1]]
set_property DRIVE 4  [get_ports M_EXPMOD3[1]]

set_property PACKAGE_PIN U18 [get_ports M_EXPMOD3[2]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD3[2]]
set_property DRIVE 4  [get_ports M_EXPMOD3[2]]

set_property PACKAGE_PIN T18 [get_ports M_EXPMOD3[3]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD3[3]]
set_property DRIVE 4  [get_ports M_EXPMOD3[3]]

set_property PACKAGE_PIN P17 [get_ports M_EXPMOD3[4]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD3[4]]
set_property DRIVE 4  [get_ports M_EXPMOD3[4]]

set_property PACKAGE_PIN U20 [get_ports M_EXPMOD3[5]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD3[5]]
set_property DRIVE 4  [get_ports M_EXPMOD3[5]]

set_property PACKAGE_PIN R19 [get_ports M_EXPMOD3[6]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD3[6]]
set_property DRIVE 4  [get_ports M_EXPMOD3[6]]

set_property PACKAGE_PIN N17 [get_ports M_EXPMOD3[7]]
set_property IOSTANDARD LVTTL  [get_ports M_EXPMOD3[7]]
set_property DRIVE 4  [get_ports M_EXPMOD3[7]]

#
#	Spare ---------------------------------------------------------------------
#
# set_property PACKAGE_PIN P19 [get_ports V_IN_A]
# set_property IOSTANDARD LVTTL  [get_ports V_IN_A]
# set_property DRIVE 4  [get_ports V_IN_A]

# set_property PACKAGE_PIN V7 [get_ports V_IN_B]
# set_property IOSTANDARD LVTTL  [get_ports V_IN_B]
# set_property DRIVE 4  [get_ports V_IN_B]

#
#	7-Segment LEDs-------------------------------------------------------------
#
set_property PACKAGE_PIN Y2 [get_ports M_7SEG_A]
set_property IOSTANDARD LVTTL  [get_ports M_7SEG_A]
set_property DRIVE 4  [get_ports M_7SEG_A]

set_property PACKAGE_PIN AA3 [get_ports M_7SEG_B]
set_property IOSTANDARD LVTTL  [get_ports M_7SEG_B]
set_property DRIVE 4  [get_ports M_7SEG_B]

set_property PACKAGE_PIN AA4 [get_ports M_7SEG_C]
set_property IOSTANDARD LVTTL  [get_ports M_7SEG_C]
set_property DRIVE 4  [get_ports M_7SEG_C]

set_property PACKAGE_PIN AA5 [get_ports M_7SEG_D]
set_property IOSTANDARD LVTTL  [get_ports M_7SEG_D]
set_property DRIVE 4  [get_ports M_7SEG_D]

set_property PACKAGE_PIN R21 [get_ports M_7SEG_DIGIT[0]]
set_property IOSTANDARD LVTTL  [get_ports M_7SEG_DIGIT[0]]
set_property DRIVE 4  [get_ports M_7SEG_DIGIT[0]]

set_property PACKAGE_PIN T20 [get_ports M_7SEG_DIGIT[1]]
set_property IOSTANDARD LVTTL  [get_ports M_7SEG_DIGIT[1]]
set_property DRIVE 4  [get_ports M_7SEG_DIGIT[1]]

set_property PACKAGE_PIN T21 [get_ports M_7SEG_DIGIT[2]]
set_property IOSTANDARD LVTTL  [get_ports M_7SEG_DIGIT[2]]
set_property DRIVE 4  [get_ports M_7SEG_DIGIT[2]]

set_property PACKAGE_PIN U22 [get_ports M_7SEG_DIGIT[3]]
set_property IOSTANDARD LVTTL  [get_ports M_7SEG_DIGIT[3]]
set_property DRIVE 4  [get_ports M_7SEG_DIGIT[3]]

set_property PACKAGE_PIN AB5 [get_ports M_7SEG_DP]
set_property IOSTANDARD LVTTL  [get_ports M_7SEG_DP]
set_property DRIVE 4  [get_ports M_7SEG_DP]

set_property PACKAGE_PIN AB6 [get_ports M_7SEG_E]
set_property IOSTANDARD LVTTL  [get_ports M_7SEG_E]
set_property DRIVE 4  [get_ports M_7SEG_E]

set_property PACKAGE_PIN AB2 [get_ports M_7SEG_F]
set_property IOSTANDARD LVTTL  [get_ports M_7SEG_F]
set_property DRIVE 4  [get_ports M_7SEG_F]

set_property PACKAGE_PIN AB3 [get_ports M_7SEG_G]
set_property IOSTANDARD LVTTL  [get_ports M_7SEG_G]
set_property DRIVE 4  [get_ports M_7SEG_G]
