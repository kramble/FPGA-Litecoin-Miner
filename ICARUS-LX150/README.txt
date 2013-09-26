This is a multicore proof of concept litecoin miner for ngzhang's Icarus/Lancelot board.

I targeted this board as it is well documented at https://github.com/ngzhang/Icarus

Originally I used ngzhang's serial interface code as a basis, but due to concerns about
GPL compatability, I currently use teknohog's directly (ngzhang's is based on teknokog's)
https://github.com/teknohog/Open-Source-FPGA-Bitcoin-Miner/tree/master/projects/Xilinx_cluster_cgminer

The current version is based on experimental/LX150-SLOWSIXTEEN-A

Set the number of cores in ltcaminer_icarus.v parameter LOCAL_MINERS. Eight cores is the
current maximum, do not use a higher value as the nonce distribution will fail. NB The
current code will only build with a maximum of two cores due to resource usage.

A custom driver is needed as we use the full block header, not midstate. This is based on
miner.py from the original fpgaminer xilinx project, modified to send the full 80 bytes of
the block header plus the target so as to support variable difficulty pools. This is
provided in MiningSoftware, see MiningSoftware/README.txt for details. Note that the
clockrate is set at runtime. By default this is 25MHz, you should increase this until
the error rate becomes unacceptable. 50MHz was achievable with my lancelot board.

The project was built in PlanAhead version 14.4 (windows, 32 bits) using the following
modified synthesis settings (strategy defined in Tools/Options) ...

register balancing = yes
register duplication = yes (already in default)
resource sharing = no
equivalent register removal = no

Device is xc6slx150-fgg484-2 (speed grade 2). A lot of warnings are produced (sorry!)

A bitstream is provided on dropbox, see ../bitstream.txt. A xilinx platform cable plus an
installation of the Impact software will be needed to upload the bitstream.

Test results on dual-fpga Lancelot RevB board, using stratum proxy server with askrate of
2 seconds, measured at pool using conversion kHash/sec = (diff_1_shares/hr * 65536 / 3.6M)
At 50MHz (set dynamically) lancelot hashrate 33kHash/sec (16 per LX150, 8 per core).
