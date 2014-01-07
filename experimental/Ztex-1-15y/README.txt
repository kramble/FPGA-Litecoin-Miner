Litecoin miner Ztex 1.15y port

A single core experimental bitstream is available at ...
https://www.dropbox.com/s/l1w0flfqs4q1xm8/ztex_ufm1_15y1-ltc-v04-1core-ucf-46-fmax-46.bit

This performs slightly better than the dual core build as the higher internal clock speed more
than makes up for the single core. NB this has a different DCM clock divider, so clock it at
around 132MHz for roughly 60kHash/sec at the pool.

NB Devices vary so your maximum clock speed may be different to mine. A significant number of per
device HW errors are to be expected due to the way the cgminer ztex driver reports them, however
the overall HW error rate should be low (its a different metric). A high overall HW error rate
indicates excessive clock speed, especially if no shares are being sucessfully submitted.

You will need the patched version of cgminer-3.1.1 (see README in folder)

WARNING This is experimental code which may DAMAGE YOUR ZTEX BOARD.
Use at your own risk and monitor the board for overheating (automatic shutdown is disabled due to
problems compiling the 2nd PLL which has currently been omitted).

Build Notes
The following bitgen parameter is essential else only three devices will load the bitstream
-g UnusedPin:Pullnone
(see http://wiki.ztex.de/doku.php?id=en:ztex_boards:ztex_fpga_boards:porting_to_1_15y)

The bitstreams were built using ISE 14.4 in PlanAhead with the following non-default parameters
equivalent register removal = no
register balancing = yes
register duplication = yes (already in default)
resource sharing = no

Tweak the tables setting for best result (I used -t 4 for the most recent single core build).