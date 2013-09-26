LX150-EIGHT-C

Eight threads running through a fully pipelined salsa (though we still roll it
four times and repeat for the block mix). Automatically sets the LOOKAHEAD_GAP
to 2,4, or 8 depending on the number of cores selected.

This version has a 10 stage pipeline (compared to 9 in LX150-EIGHT-B) to
reduce RAM address propagation delay.
