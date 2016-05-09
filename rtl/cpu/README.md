# f32c core

Here's the core of f32c CPU. 
pipeline.vhd is the most complex part which
gives true speed to the the processor. 

The bus behaviour is coming from the pipeline
and understanding its signaling is important
in order to make a SOC that will connect to f32c bus.

# f32c bus signaling

The memory access is done using 32-bit synchronous
bus with simple signaling and tight timing.

Usually f32c uses multiport RAM arbiter which
has signal bus towards phyisical RAM and multiple
ports for CPU and SOC like video or DMA.

Valid data "live" on the wire during a single data
ready clock cycle. Exactly in time when ready
signal is high, data have to be sampled.

    dmem_addr_strobe: std_logic;
Strobe is memory cycle request signal.
Master must set strobe to logic 1 and hold it until
it receives ready signal

    dmem_data_ready: std_logic;
The ready signal will become logic 1 during a single CPU 
clock cycle and exactly at that time instance data
can be read from the bus (if doing read cycle).

Ready signal and valid data will not wait on the bus 
indefinitely!

If doing write cycle, appearance of logic 1 during a
single clock cycle indicates completion of the write cycle.

After data_ready becomes logic 1, in the next CPU clock cycle 
address_strobe must be set to logic 0 otherwise a
new write cycle will be started.

    dmem_write: std_logic;
Write signal logic 1 defines that it will be a write cycle.
Write signal logic 0 is read cycle.

    dmem_byte_sel: std_logic_vector(3 downto 0);
select which byte of 32-bit word should be written.
"1000" will write MSB, "0001" will write LSB for example.
For read I'm not sure :), this is maybe NOP because it 
will always read full 32 bits.

    dmem_addr: std_logic_vector(31 downto 2);
Memory address. 2 LSB address bits don't appear on outside
bus because f32c does 32-bit aligned memory transfers only.

    dmem_data_in: std_logic_vector(31 downto 0);
    dmem_data_out: std_logic_vector(31 downto 0);
Input and output of 32-bit data are routed separately,
f32c never does 3-state bus transfers.
