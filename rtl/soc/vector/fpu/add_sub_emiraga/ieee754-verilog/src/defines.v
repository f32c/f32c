
`define TOTALBITS 32 //number of bits in representation of a number
`define SIGN_LEN 1 //sign of a number needs 1 bit
`define EXPO_LEN 8 //length of exponent part
`define SIGNIF_LEN 23 // mantissa or significand of a number
`define GUARD_BITS 3 //additional bits added to make addition/subtraction more precise
`define ROUND_EVEN 3'b100

`define LASTBIT `TOTALBITS - 1
`define FIRSTBIT 0
`define EXPO_LASTBIT `LASTBIT - `SIGN_LEN
`define EXPO_FIRSTBIT `EXPO_LASTBIT - `EXPO_LEN + 1
`define SIGNIF_LASTBIT `SIGNIF_LEN - 1
`define SIGNIF_FIRSTBIT 0

`define WIDTH_NUMBER [`LASTBIT:`FIRSTBIT]

`define WIDTH_SIGNIF [`SIGNIF_LEN:-`GUARD_BITS]
`define WLEN_SIGNIF `SIGNIF_LEN + `GUARD_BITS + 1

`define WIDTH_SIGNIF_PART [`SIGNIF_LEN-1:0]
`define WIDTH_EXPO [`EXPO_LEN-1:0]

`define EXPO_ONES 8'b11111111
