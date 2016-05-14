Bare glue_xram with ram emulation and minimal soc 
(serial and LEDs)

Test for glue_xram using acram.vhd 32-bit RAM driver
with integrated multiport arbiter.

This is a proof-of-concept test to make sure that
on FPGA we can correctly synthesize its own d/i cache 
coherence interfaced to emulated RAM.

Before implementing axi_interconnect with real
DDR3 RAM, this example must work!
