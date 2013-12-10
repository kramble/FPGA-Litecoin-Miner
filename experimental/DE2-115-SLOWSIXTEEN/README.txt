This is untested, but simulates OK, so it ought to work after a fashion
(at least for the single core variant).

I'm not entirely happy with the loadnonce behaviour (it really ought to
strobe on loading new data so as to initiate a reset), but this is a bit
tricky as the virtual_wire interface seems to be non-deterministic.

I've left the ICARUS macro defined in pbkdfengine.v as this matches the
working lancelot/ztex/CM1 ports, and since I can't test it live I'm leaving
it alone but this does disable the load nonce test feature. It really ought
to be undefined for altera, perhaps also initiating a reset on the comparison
(nonce_previous_load != data3[127:96]).