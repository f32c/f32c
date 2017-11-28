# f32c core

Here's the core of f32c CPU. 
pipeline.vhd is the most complex part which
gives true speed to the the processor. 

The bus behaviour is coming from the pipeline
and understanding its signaling is important
in order to make a SOC that will connect to f32c bus.

# bus signaling

The memory access is done using 32-bit synchronous
bus with simple signaling and tight timing.

Usually f32c uses multiport RAM arbiter which
has signal bus towards physical RAM and multiple
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

# non-deterministic cases

The only supported behaviour of bus master is that from
the moment it sets "adddress_strobe" to 1, it is no longer
allowed to change anything on the bus neither to give up
from the transfer before "data_ready" becomes 1.

If bus state is changed during read cycle (before "data_ready"
becomes 1), the bus content will be sampled after random number
of clocks, depending on activity on other ports.

If bus state is changed during write cycle (before "data_ready"
becomes 1), the bus content will be sampled in the clock
cycle previuos to the cycle when "data_ready" becomes 1.

# cache

There is separate instruction and data cache.
For f32c bootloader to work, cache must support
coherence between data and instruction cache.

Also the cache, as it is implemented now for
simplicity instruction fetch cycle must complete
(receive ready) before changing address for next
fetch. 

If there is read cycle with cache miss, cache will
start fetching data from slow RAM
If address is changed before read cycle is complete, 
cache will pull old data from RAM and store in a
new (wrong) address, which leads to corruption.

So once address strobe is asserted to the cache,
don't change address until ready signal is received.

# cache coherence

Self modifying code needs cache coherence.

When bootloader receives new compiled code over the serial port, 
before jumping to new (self-modified) code, it will try to flush 
instruction cache using asm cache instructions which use a separate
cpu signal line which starts write cycle of 0 to instruction cache 
data valid bits. After that jump to new code can work.

The instruction-cache and data-cache could be implemented differently
e.g. using vendor specific modules which assure
automatic coherence so this flush instruction will be a NOP with
cache flush signal line disconnected.
