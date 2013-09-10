LX150-EIGHT-A

Eight threads running through a fully pipelined salsa (though we still roll it
four times and repeat for the block mix). Automatically sets the LOOKAHEAD_GAP
to 2,4, or 8 depending on the number of cores selected.

This needs to run at > 100MHz to match the original 25MHz unpipelined code
however its currently limited to 75MHz or thereabouts, so performance is poor.
With some work on fanout (the RAM address is particularily slow and may need
an additional pipeline stage) and a separate clock for the pbkdfengine, it could
perhaps go significantly faster. This will be tried in LX150-EIGHT-B since the
separate clocking scheme is a major change.

The code is still rather buggy. There is a 10% loss of shares which is possibly
down to the periodic reset on loadnonce, which is required to keep the pipeline
in sync as thread execution time is variable.