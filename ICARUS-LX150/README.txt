This is a multicore proof of concept litecoin miner for ngzhang's Icarus/Lancelot board.

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
the block header plus the target so as to support variable difficulty pools.

Test results on dual-fpga Lancelot RevB board, using stratum proxy server with askrate of
2 seconds, measured at pool using conversion kHash/sec = (diff_1_shares/hr * 65536 / 3.6M)

Default 2 core, full scratchpad,        25MHz gives  6.2 kHash/sec (1.55kH/s per core)
... NB Theoretical speed should be 1.45kH/s per full scratchpad core, 1.16 for halfram.
HashVariant-C 2 core, full scratchpad,  40MHz gives  8.8 kHash/sec (2.20kH/s per core)
HashVariant-C overclocked (Fmax 47MHz), 60MHz gives 11.8 kHash/sec (2.95kH/s per core)
Somewhat better performance (up to 3.3kH/s per core) has been reported by more expert
Xilinx PlanAhead users.
