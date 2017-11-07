# f32c SoC

The optional hardware on CPU bus allows for farily complete system,
main feature include:

    Video 2D acceleration: windows, sprites, textmode, scroll, blitter, DMA, output HDMI/VGA/Composite
    Floating point vector processor: 3 FLOPs/clock, A=B+-*/C, 8 vectors, 2048 length, DMA, 32-bit 
    Sound: 16-bit stereo DMA PCM (WAV)
    Polyphonic synthesizer 128-voice, 24-bit (tonewheel organ emulation)
    Audio output to digital (SPDIF 48kHz/24-bit) and analog (stereo jack PWM)
    SDR FM 88-108 MHz transmitter: stereo and RDS
    SDR ASK 433.92 MHz transmitter: for remote controllers
    PID controller: 4 DC motors with encoders
    Timer: phase accumulator, input trigger and capture, PWM output, interrupts
    GPIO with interrupts
    SPI multi-channel for Flash, SD card etc
    RS232 Serial

All SoC components are optional, each is carefully optimized
to consume minimum silicon resources and has rich set of internal
parameters to choose from. Compiled f32c SoC system can range from 
minimal (serial port) to full featured.
