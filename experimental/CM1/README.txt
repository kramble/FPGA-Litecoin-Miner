Litecoin miner Cainsmore CM1 port

WARNING This is experimental code which may DAMAGE YOUR CAINSMORE BOARD.
Use at your own risk.

This code is derived from the HashVoodoo FPGA Bitcoin Miner Project
https://github.com/pmumby/hashvoodoo-fpga-bitcoin-miner

Licensed under GPL. My thanks to Paul Mumby (Glasswalker), makomk and TheSeven.

NB This port requires the Hashvoodo controller firmware available at
https://github.com/pmumby/hashvoodoo-fpga-bitcoin-miner/downloads
Use hashvoodoo_controller_25.bit from any of the later releases, NOT the 08_04_2012.

A single core experimental bitstream is available at ...
https://www.dropbox.com/s/dxv1rj1d3rjmmzq/hashvoodoo-ltc-v03a-1core-fmax-39.bit

This runs at around 200MHz (use --cainsmore-clock to override the default 175MHz) giving approx
40kHash/sec total at the pool (ignore the cgminer stats as they are currently complete garbage).

Faster version https://www.dropbox.com/s/08ccjjvmfgmxcbi/hashvoodoo-ltc-v03ab-1core-fmax-49.bit
This will run at around 250MHz or more giving perhaps 55kHash/sec.

A dual core bitstream is not yet available (I'm still trying to get the xilinx ISE it to route it,
though the single core version above is probably just as effective).

You will need the patched version of cgminer-3.1.1 from
https://github.com/kramble/FPGA-Litecoin-Miner/tree/master/experimental/Ztex-1-15y/cgminer-3.1.1

NB The cgminer folder location is a bit unfortunate being under ztex, I'll look to moving it when
the code is promoted from experimental.

