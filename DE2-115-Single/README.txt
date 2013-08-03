Single core version for DE2-115 using full sized scratchpad (UNTESTED)

For multipe cores simply replicate hashcore with different nonce_msb values and implement
a golden_nonce queue for results (a simple multiplexer latching on golden_nonce_match
will suffice). An dual core example is provided as a comment in ltcminer.v
Its a little inefficient as the sha256 engine is replicated, but this will be rather
complicated to fix.

It probably best to use half-sized scratchpads for the multicore version as
this doubles the number of cores that can be fitted for a 60% improvement in
throughput (the half cores being 80% as fast as a full scratchpad)
    set_global_assignment -name VERILOG_MACRO "HALFRAM=1"

This note from the previous version of the README is obsolete as multicore is now
enabled by default ...
   For multicore, set the following in ltcminer.qsf ...
       set_global_assignment -name VERILOG_MACRO "MULTICORE=1"
   (Or use the assignments/settings menu in quartus to set it)
Use the NOMULTICORE macro to revert to previous behaviour.

