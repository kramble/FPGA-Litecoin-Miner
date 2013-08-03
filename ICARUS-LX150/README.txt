This is a multicore proof of concept litecoin miner for ngzhang's Icarus board.

It is UNTESTED as I have neither an Icarus board to test on, nor an LX150 Xilinx ISE
license to compile it (but I have simulated and done a test compilation on an LX75).

I targeted this board as it is well documented at https://github.com/ngzhang/Icarus

Originally I used ngzhang's serial interface code as a basis, but due to concerns about
GPL compatability, I currently use teknohog's directly (ngzhang's is based on teknokog's)
https://github.com/teknohog/Open-Source-FPGA-Bitcoin-Miner/tree/master/projects/Xilinx_cluster_cgminer

Set the number of cores in ltcaminer_icarus.v parameter LOCAL_MINERS. Eight cores is the
current maximum, do not use a higher value as the nonce distribution will fail, though
this is easily fixable by increasing the size of nonce_msb. Optionally set the HALFRAM
macro for hashcore.v (either in the synthesis options (advanced) or directly in the
verilog source) so as to use a 512kBit scratchpad (which allows double the number cores
to be fitted).

For simplicity each core has its own PBKDF2_SHA256 engine, but to save LE's this could be
changed to share a common engine (or two, one for input, the other for output) between the
salsa cores. There are also a lot of registers used in the design which is another thing
to look at (perhaps some could be traded for RAM, though these would have to replace a few
of the slots in the mix scratchpad which would complicate the FSM considerably).

A custom driver is needed as we use the full block header, not midstate. This is based on
miner.py from the original fpgaminer xilinx project, modified to send the full 80 bytes of
the block header plus the target so as to support variable difficulty pools (UNTESTED).
