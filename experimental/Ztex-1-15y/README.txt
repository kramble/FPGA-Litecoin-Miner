Litecoin miner Ztex 1.15y port

This is at an early stage but a single core experimental bitstream is available at
https://www.dropbox.com/s/5wduy7sys81vgjw/ztex_ufm1_15y1-ltc-v03b-1core-proto76-ucf-15-fmax-25.bit
Its slow, only around 30kHash/sec at 128MHz but will improve in future builds.

You will need the patched version of cgminer-3.1.1 (see README in folder)

WARNING This is experimental code which may DAMAGE YOUR ZTEX BOARD.
Use at your own risk and monitor the board for overheating (automatic shutdown is
disabled due to problems compiling the 2nd PLL which has currently been omitted).
