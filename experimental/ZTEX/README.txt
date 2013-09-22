ZTEX port based on http://www.ztex.de/btcminer/ZtexBTCMiner-121126.tar.bz2

NB This is UNTESTED code uploaded for discussion with vpereira and intended
for a ZTEX1.15b board with a spartan LX75 device.

See https://github.com/vpereira/FPGA-Litecoin-Miner/tree/master/ZTEX1.15b

Use with the following ...

source/hashcore.v
source/salsa.v
source/sha256_transform.v
source/sha-256-functions.v
ICARUS-LX150/xilinx_ram.v

Package is CSG-484 (NOT the FGG-484 used in ICARUS/LANCELOT) xc6slx-75-csg484-3
NB there is also an xa6slx (automotive version). Do not confuse them.

Several changes were required to remove Critical Warnings in implementation ...

Removed NET "clk_reset" from ztex_ufm1_15.ucf
Added CLKIN_PERIOD for DCM_CLKGEN and PLL_BASE (calculated for 48MHz oscillator)

I also amended the ucf TS_fxclk_in to 20.8ns to avoid NGBuild warnings, though
it may be better to amend the CLKIN_PERIOD instead (this was the second try
at getting these right as my first one set the DCM_CLKGEN output frequency
directly to 25MHz which then broke the PLL_BASE due to VCO being out of range).
... ADDENDUM, we still get a warning, but now its about 6.24nS not matching
6.25nS so I think this can safely be ignored.

Utilization is around 20% LUT and 34% RAM on LX75, so multiple cores should
easily fit but will require a golden_nonce queue. The scheme used for the
altera virtual_wire port in source/ltcminer.v would probably work OK (its a
variation on technohog's hub_core). FMax is reported as 26.2MHz.
