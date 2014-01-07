Experimental hashing cores.

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

Contents (chronological order)
------------------------------
NB These are LX150 Icarus/Lancelot ports (apart from the later entries for Ztex/CM1 etc)

hashvariant-A.v    Uses RAM to reduce register count by eliminating X0Save, X1Save

hashvariant-B.v    Pipelined 2x clock speed (NOT interleaving hashes). NB performance is
                   halved due to the need for 2 clocks per salsa-mix. Uses salsa-B.v
				   
hashvariant-C.v    As B, but pushes two hashes simultaneously through the pipeline. Also
                   uses salsa-B.v NB This is a prototype design, the hash scheduling FSM
                   is totally INSANE (a tribute to NASA's skycrane perhaps).

LX150-SPLIT        Separates the pbkdf and salsa engines into separate modules linked by
                   a one bit serial bus to reduce routing congestion. This will form the
                   basis of ongoing work on further pipelining of the salsa.

LX150-EIGHT-A      Fully pipelined salsa with 8 threads. Slow and somewhat buggy (see
                   the README). Major rework is required, will use -B, -C suffixes.
 
LX150-EIGHT-B      Separate clock domains for pbkbd and salsa, dynamic clock speed (yay)!

LX150-EIGHT-C      Ten stage pipeline (still only 8 threads). Not usefully faster.

LX150-SLOWEIGHT-A  A return to the original slow clocked salsa core, but now with eight
                   threads. This gets just under 10kHash/sec per LX150 though only one
                   core sucessfully routes (there is sufficient LUT resource for a
                   second, but the router cannot route it, perhaps a more aggressive
                   planahead scheme will work).

LX150-SLOWSIXTEEN-A Added a pipeline stage between column and row operations. Sixteen
                   threads, and this time a second core does fit. Clocks at 50Mhz (the
                   default is 25MHz, so increase it at runtime via the mining script)
                   giving aroung 16khash/sec per LX150 (33khash/sec total for Lancelot).

LX150-SIXTYFOUR-A  Included for completeness, its performance is quite poor.

ZTEX               Old NON-working code for ztex 1.15b - DO NOT USE

Ztex-1.15y         Working Ztex 1.15y port plus subfolder for cgminer 3.1.1

CM1                Working Carinsmore CM1 port (use same cgminer as Ztex-1.15y above)

DE2-115-SLOWSIXTEEN Experimental port (untested) requested by forum user Dork and
                   intended as a bridge to a Cyclone V SOCKit port.

The later versions (LX150-EIGHT onwards) are built in PlanAhead version 14.4 (32 bits)
using the following modified synthesis settings (strategy defined in Tools/Options) ...

register balancing = yes
register duplication = yes (already in default)
resource sharing = no
equivalent register removal = no

The constraint on hash_clk is VERY lax at 10MHz to facilitate a quick build. You will
need to increase this for a better FMAX, in conjunction with tuning the implementation
strategy (for example try setting different values for the tables option -t).

The Ztex-1.15y requires special build instructions, see the README.