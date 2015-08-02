# Generate binary RDS message

Text data must be converted to binary
sequence of 13-byte packets (called groups).

Here is simple ansi C commandline tool
that will generate VHDL file with binary.

    Example:
    rdsmsg 0x1234 "TEST1234" -l "LONG MESSAGE..."

Each 13-byte packet updates 2 characters
on main 8-character display "TEST1234" in example.
Position where to overwrite is encoded in the packet.

Some radios may also display "LONG MESSAGE..."
on 64-character display, there each
13-byte packet updates 4 characters.
