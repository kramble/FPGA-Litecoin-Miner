Litecoin miner Ztex 1.15y port

This is at an early stage but a single core experimental bitstream is available at
https://www.dropbox.com/s/5wduy7sys81vgjw/ztex_ufm1_15y1-ltc-v03b-1core-proto76-ucf-15-fmax-25.bit
Its slow, only around 30kHash/sec at 128MHz but will improve in future builds.

Dual core build at ...
https://www.dropbox.com/s/lojanv7yg24yq89/ztex_ufm1_15y1-ltc-v03b-2core-proto76-ucf-15-fmax-31.bit
At 180MHz this achieves around 55kHash/sec pool speed, cgminer reports 29kHash/sec which is half
of the actual speed as the second core is not included in the stats (shares ARE submitted though).

Faster single core build at ...
https://www.dropbox.com/s/l1w0flfqs4q1xm8/ztex_ufm1_15y1-ltc-v04-1core-ucf-46-fmax-46.bit
This performs slightly better than the dual core build as the higher internal clock speed more
than makes up for the single core. NB this has a different DCM clock divider, so clock it at
around 132MHz for roughly 60kHash/sec at the pool.

NB Devices vary so your maximum clock speed may be different to mine. Some HW errors are to be
expected but a high error rate indicates excessive clock speed, especially if no shares are being
sucessfully submitted.

You will need the patched version of cgminer-3.1.1 (see README in folder)

WARNING This is experimental code which may DAMAGE YOUR ZTEX BOARD.
Use at your own risk and monitor the board for overheating (automatic shutdown is disabled due to
problems compiling the 2nd PLL which has currently been omitted).
