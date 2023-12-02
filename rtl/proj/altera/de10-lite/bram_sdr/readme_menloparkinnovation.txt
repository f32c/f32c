
Software Defined Radio Project.

03/03/2019

FPGA RTL core for Direct Digital Synthesis (DDS) of radio signals.

Started from F32C FM RDS SoC, but goal is to provide a SDR transmitter
for short wave (Ham Radio) beacon and communications purposes.

FM RDS will remain an option that can be enabled/disabled by CPU
core software.

It is intended to cover the long wave beacon bands in addition to
the short wave Ham radio frequencies (1.8 - 30Mhz).

Note: See "Radio Emissions Notes:" at the bottom of the page.

The first modulation options are:

 - CW/morse code and on/off ham radio digital modes for all frequencies.

 - FM for all frequencies, but only legal on 29Mhz band of ham radio.

 - AM modulation using PWM into the filter circuit for ham short wave
   (1.8-30Mhz).

   16X oversampling will be used to generate the PWM so the maximum
   frequency would be the 250Mhz synthesis clock / 16 or 15.625Mhz.

   It may be possible to increase the synthesis clock, or use a lower
   8X oversampling to cover up to 30Mhz. Though lower frequencies and
   the ham 20 meter band are the primary targets.

   Note: 16X oversampling may not be required if pulse trains
   are turned on/off and the time constants in the outboard
   filter are taken into account to generate the amplitude moduled
   envelope.

 - AM modulation for AM broadcast band (BCB).

Additional future goals:

 - Digital generation of SSB signals for ham short wave use.

 - Digital generation of advanced ham radio digital modes which
   use an SSB carrier as the baseline.

 - Drive a D/A converter for "narrow band" SDR generation which
   would require an analog based "up converter" with a software controlled
   PLL. This would be required if the dynamic range of the PWM generated
   amplitude moduled signals is in-adequate, especially at the higher
   frequency range in the shortwave band.

Receiver:

Currrently this is transmit only. Receive could be a different project
or eventually integrated.

Receive could take the form of:

1) "narrow band" SDR using external front end mixer/down converter and
   software controlled Phase Locked Loop (PLL).

   An audio frequency range A/D converter works well with this approach,
   though higher quality (96Khz or better) allow better spectrum scope
   bandwidths.

   An Elecraft KX3 with I+Q outputs can be used for prototyping as it
   has this front end hardware.

2) "wide band" SDR using a high speed A/D converter to directly convert
   radio signals to a high speed stream for Digital Down Conversion (DDC).

   Currently eEvaluating options of which one to use for prototyping
   and experiments. There are high speed A/D's available for FPGA prototype
   boards, or modular boards in the ham radio experimenters community.

System Interface/Control Software:

The system interface is register level integrated with the F32C
MIPS/RISC-V "soft core" directly implemented on the FPGA. This
soft core runs MIPS/RISC-V instructions produced by the open source
GCC compilers, and is integrated in the Arduino IDE by the FPGAArduino
project.

This provides hard real time, predictable software performance in
the software interface communicating with the "hardware blocks"
implemented on the FPGA.

On boards that support it such as the DE10-Nano, register level
integration with Linux running on the on-FPGA ARM A9 cores
will be supported. This allows "soft realtime" to be performed
on the Linux cores for replacement of SDR software that typically
runs on a PC or Android phone. It also opens up internet/web
and IoT/Cloud communications and control scenarions.
Note that Linux on the ARM cores may communicate with either
the hardware, or software running on the MIPS/RISC-V real
time soft core. A board such as the DE10-Nano can integrate
the entire SDR radio stack.

Radio Emissions Notes:

Note: In all cases the DDS generated output signal must be
filtered for legal use on any radio frequency or license. Otherwise
it may cause harmful interference due to the "impure" radio signal
it generates by the technique. DDS signal generation techniques
*ALWAYS REQUIRE* the minimum of a low pass filter for the proper
frequency range to clean up the emitted radio spectrum to be within
legally defined limits. Even if you hold a "ham" license, or
are broading casting under a countries "low power transmitter"
rules, you must have a spectrally "clean" signal to conform.

It is highly recommended to examine any signals you intend to
broadcast outside of the lab with a calibrated spectrum analyzer.
Remember even licensed (United States) amateur radio operaters
are responsible for the proper performance of their equipment.

Note: Broadcasting on ham radio frequencies requires a valid
ham radio license for the country you are physically present in.

Broadcast on other frequencies is strictly regulated, and the rules
for which frequencies, power levels, and modes vary by country
and world region.  *** YOU ARE RESPONSIBLE FOR LEGAL USE ***.

Even connecting up a short wire for "lab use only" may cause harmful
interference and violate regulations of generation of radio energy.
It is your responsibility to legally conform. Even if it means building
a "faraday cage" for your testing.

Note: An old, undamaged, unplugged, microwave oven works with the door
closed. Test it by putting your cell phone inside and calling your self
from another. This is not 100% reliable unless you test yourself
with a calibrated spectrum analyzer.

Emissions Power Levels:

For example, in the US small unlicensed transmitters are allowed within
certain power levels, and spectral purity. In the case of the FM RDS
mode the math is as follows:

 - LVTTL signal driving 3.3V into a 50 ohm antenna:
  3.3V / 50 ohms == 0.066 or 66 milliamps.
  3.3V * 0.66 == 0.2178 watts, or 217 mw. This exceeds US 100mw limits.

  A 26 inch piece of wire at 107.9Mhz is a 1/4 low impedance and between
  50-75 ohms.

  But, the FPGA pins are current limited. The above figure would occur if
  you used an external high current I/O driver, which is not the case for
  a direct wire antenna connection to the GPIO port pins on the DE10-Lite.

  The 3.3V LVTTL FPGA pin setting on the MAX10 FPGA is limited to 8ma according to
  https://www.intel.com/content/dam/www/programmable/us/en/pdfs/literature/hb/max-10/ug_m10_gpio.pdf
  on page 18.

  3.3V * 0.008 == 0.0264 watts, or 26.4 mw. This falls under the 100mw US limit.

  Note: On the data sheet the 3.0V LVTTL driver can be configured for 16ma:

  3.0V * 0.016 == 0.048 watts, or 48 mw. More power, but also under the limit.
  
  Note: Yes, I am ignoring the impedance mismatch between the port
  and the 50 ohm antenna which would result in a less efficient radiation.
  But then again, a "random length" of wire could have these impedances
  depending on conditions.

  3.3V / .008 == 412.5 ohms.
  
  3.0V / .016 == 187.5 ohms.

  Note: yes, I am ignoring complex impedance and using resistance as a
  "back of the envelope" magnitude calculation. If you are concerned
  about actual values you likely have access to the proper impedance
  bridge and the knowledge to use it :-)

