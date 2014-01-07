Litecoin miner Cairnsmore CM1 port

WARNING This is experimental code which may DAMAGE YOUR CAIRNSMORE BOARD.
Use at your own risk.

This code is derived from the HashVoodoo FPGA Bitcoin Miner Project
https://github.com/pmumby/hashvoodoo-fpga-bitcoin-miner

Licensed under GPL. My thanks to Paul Mumby (Glasswalker), makomk and TheSeven.

NB This port requires the Hashvoodo controller firmware available at
https://github.com/pmumby/hashvoodoo-fpga-bitcoin-miner/downloads
Use hashvoodoo_controller_25.bit from any of the later releases, NOT the 08_04_2012.

A single core experimental bitstream is available at ...
https://www.dropbox.com/s/08ccjjvmfgmxcbi/hashvoodoo-ltc-v03ab-1core-fmax-49.bit

This runs at up to 250MHz (use --cainsmore-clock to override the default 175MHz) giving approx
60kHash/sec total at the pool (ignore the cgminer stats as they are currently complete garbage).
NB Note the typo --cainsmore-clock rather than --cairnsmore-clock. This is not yet fixed in the
cgminer code, so take care with the spelling, sorry).

A dual core bitstream is not yet available (I'm still trying to get the xilinx ISE it to route it,
though the single core version above is probably just as effective).

You will need the patched version of cgminer-3.1.1 from
https://github.com/kramble/FPGA-Litecoin-Miner/tree/master/experimental/Ztex-1-15y/cgminer-3.1.1

NB The cgminer folder location is a bit unfortunate being under ztex, I'll look to moving it when
the code is promoted from experimental.

