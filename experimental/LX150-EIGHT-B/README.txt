LX150-EIGHT-B

Eight threads running through a fully pipelined salsa (though we still roll it
four times and repeat for the block mix). Automatically sets the LOOKAHEAD_GAP
to 2,4, or 8 depending on the number of cores selected.

LX150-EIGHT-B improves on LX150-EIGHT-A by having separate clock domains for
pbkdfengine and salsaengine. It also implements a dynamic clocking scheme using
DCM_CLKGEN, though treat this with caution as it can lock up occasionally (the
code needs some work, I'm not even sure which clock edge I should be using).

This needs to run at > 100MHz to match the original 25MHz unpipelined code,
which it comes close to achieving. Further work on fanout (the RAM address is
particularily slow and may need an additional pipeline stage) could help.

The code is still rather buggy. There is a 5% to 10% loss of shares which is
possibly down to the periodic reset on loadnonce, which is required to keep the
pipeline in sync as thread execution time is variable.

The original ltcminer.py driver will work, but to take advantage of the dyn_pll
use ltcminer-dynclock.py and ltcminer-test-dynclock.py, simply run these with
the clock speed (in MHZ) as a command line argument, eg.
python ltcminer-dynclock.py 75

NB There is a hard coded SPEED_LIMIT in ltcminer_icarus.v that sets the max
value for clock. Any attempt to exceed this is silently ignored (currently set
at 100MHz, increase it at your own risk - check for overheating/overcurrent).
Low values (less than 25MHz) are also prohibited as there is a tendancy for
the DCM to lock up (currently only reprogramming can reset it as I have not
implemented a watchdog yet).

The current version flashes the TxD led in time with the clock to give some
feedback that the dynamic configuration is working. You can turn this off by
commenting out the `define FLASHCLOCK line at the bottom of ltcminer_icarus.v
NB The counter resets on loadnonce (to keep the leds in sync, as it just looks
messy otherwise), so if your askrate is fast and the clock slow, then the leds
may not light at all (until you stop the mining script).