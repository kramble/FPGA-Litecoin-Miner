Experimental hashing cores.

These currently target the DE0-Nano board (Cyclone IV 22kLE) as that is what I have, but
I may include some tests on my Xilinx LX9 homebrew board (not that I expect to be able to
fit a sensible scrypt hashing core on this tiny device, though a severly cut down version
might be possible).

I have several goals here ...

1. Reduce LE count to enable more cores to be fitted. This is easiest for registers which
are currently used with abandon, but this may not help much as registers come essentially
"free" with the CLB's, though hashvariant-A has had some success in reducing the total LE.

2. Investigate pipelining options for the salsa block. I can't see how this will help the
overall throughput (in fact I expect it will REDUCE it due to setup/hold overheads on the
registers). However it may be possible to push two or more hashing operations concurrently
through the one salsa block which may be useful in increasing the throughput of a single
core (though this will be constrained by the need for reduced scratchpad sizes to fit the
concurrent hashes into ram).

3. Use of onboard SDRAM on the DE0-Nano. Initial calculations show a lower throughput than
the internal ram (due to a 16 bit data path at 166MHz), but if sufficient free LE resource
are available, an additional core could supplement the core using onchip RAM. It will
need a rather complex interface (needing to use burst-mode to maximise speed), so it will
be a rather more advanced project, but at least we don't need to worry about doing refresh
as each hash is completed well within the refresh timeout limits.

Contents
--------

hashvariant-A.v    Uses RAM to reduce register count by eliminating X0Save, X1Save