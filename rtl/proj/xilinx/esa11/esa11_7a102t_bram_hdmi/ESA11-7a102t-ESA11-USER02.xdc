# BaseBoard = ESA11-7a102t AddOn =  ESA11-USER02

#
#	Buttons	-------------------------------------------------------------------
#
set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVTTL} [get_ports {M_BTN[0]}]
set_property -dict {PACKAGE_PIN H22 IOSTANDARD LVTTL} [get_ports {M_BTN[1]}]
set_property -dict {PACKAGE_PIN H20 IOSTANDARD LVTTL} [get_ports {M_BTN[2]}]
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVTTL} [get_ports {M_BTN[3]}]
set_property -dict {PACKAGE_PIN J14 IOSTANDARD LVTTL} [get_ports {M_BTN[4]}]

#
#	DIP Switch ----------------------------------------------------------------
#
# set_property -dict {PACKAGE_PIN B21 IOSTANDARD LVTTL} [get_ports {M_DIP[0]}]
# set_property -dict {PACKAGE_PIN A21 IOSTANDARD LVTTL} [get_ports {M_DIP[1]}]
# set_property -dict {PACKAGE_PIN B20 IOSTANDARD LVTTL} [get_ports {M_DIP[2]}]
# set_property -dict {PACKAGE_PIN A20 IOSTANDARD LVTTL} [get_ports {M_DIP[3]}]

#
#	Hex-Switch
#
set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVTTL} [get_ports {M_HEX[0]}]
set_property -dict {PACKAGE_PIN E19 IOSTANDARD LVTTL} [get_ports {M_HEX[1]}]
set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVTTL} [get_ports {M_HEX[2]}]
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVTTL} [get_ports {M_HEX[3]}]

#
#	LEDs	-------------------------------------------------------------------
#
set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_LED[0]}]
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_LED[1]}]
set_property -dict {PACKAGE_PIN C22 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_LED[2]}]
set_property -dict {PACKAGE_PIN D21 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_LED[3]}]
set_property -dict {PACKAGE_PIN G16 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_LED[4]}]
set_property -dict {PACKAGE_PIN D17 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_LED[5]}]
set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_LED[6]}]
set_property -dict {PACKAGE_PIN B15 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_LED[7]}]

#
#	EXPMODS -------------------------------------------------------------------
#
set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD0[0]}]
set_property -dict {PACKAGE_PIN K22 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD0[1]}]
set_property -dict {PACKAGE_PIN L16 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD0[2]}]
set_property -dict {PACKAGE_PIN K19 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD0[3]}]
set_property -dict {PACKAGE_PIN M21 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD0[4]}]
set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD0[5]}]
set_property -dict {PACKAGE_PIN N20 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD0[6]}]
set_property -dict {PACKAGE_PIN N22 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD0[7]}]
set_property -dict {PACKAGE_PIN E22 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD1[0]}]
set_property -dict {PACKAGE_PIN F21 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD1[1]}]
set_property -dict {PACKAGE_PIN G21 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD1[2]}]
set_property -dict {PACKAGE_PIN G22 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD1[3]}]
set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD1[4]}]
set_property -dict {PACKAGE_PIN D22 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD1[5]}]
set_property -dict {PACKAGE_PIN J17 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD1[6]}]
set_property -dict {PACKAGE_PIN E21 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD1[7]}]
set_property -dict {PACKAGE_PIN G17 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD2[0]}]
set_property -dict {PACKAGE_PIN G20 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD2[1]}]
set_property -dict {PACKAGE_PIN F19 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD2[2]}]
set_property -dict {PACKAGE_PIN F15 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD2[3]}]
set_property -dict {PACKAGE_PIN H15 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD2[4]}]
set_property -dict {PACKAGE_PIN F14 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD2[5]}]
set_property -dict {PACKAGE_PIN G18 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD2[6]}]
set_property -dict {PACKAGE_PIN F13 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD2[7]}]
set_property -dict {PACKAGE_PIN A13 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD3[0]}]
set_property -dict {PACKAGE_PIN E17 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD3[1]}]
set_property -dict {PACKAGE_PIN C18 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD3[2]}]
set_property -dict {PACKAGE_PIN C17 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD3[3]}]
set_property -dict {PACKAGE_PIN E16 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD3[4]}]
set_property -dict {PACKAGE_PIN B17 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD3[5]}]
set_property -dict {PACKAGE_PIN D16 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD3[6]}]
set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_EXPMOD3[7]}]

#
#	7-segment LEDs ------------------------------------------------------------
#
set_property -dict {PACKAGE_PIN M17 IOSTANDARD LVTTL DRIVE 4} [get_ports M_7SEG_A]
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVTTL DRIVE 4} [get_ports M_7SEG_B]
set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVTTL DRIVE 4} [get_ports M_7SEG_C]
set_property -dict {PACKAGE_PIN L20 IOSTANDARD LVTTL DRIVE 4} [get_ports M_7SEG_D]
set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_7SEG_DIGIT[0]}]
set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_7SEG_DIGIT[1]}]
set_property -dict {PACKAGE_PIN C15 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_7SEG_DIGIT[2]}]
set_property -dict {PACKAGE_PIN B16 IOSTANDARD LVTTL DRIVE 4} [get_ports {M_7SEG_DIGIT[3]}]
set_property -dict {PACKAGE_PIN K21 IOSTANDARD LVTTL DRIVE 4} [get_ports M_7SEG_DP]
set_property -dict {PACKAGE_PIN M18 IOSTANDARD LVTTL DRIVE 4} [get_ports M_7SEG_E]
set_property -dict {PACKAGE_PIN N19 IOSTANDARD LVTTL DRIVE 4} [get_ports M_7SEG_F]
set_property -dict {PACKAGE_PIN M20 IOSTANDARD LVTTL DRIVE 4} [get_ports M_7SEG_G]

#
#	eof
#




