LX150_SPLIT

Splits the pbkdf and salsa engines into separates modules and implements a serial
shift register protocol for communication to reduce routing of wide buses.

Uses the original salsa.v.

Further work is needed to allow multiple salsa engines to be served from a single pbkdf
engine. However this is an interim design leading on to the pipelined LX150_EIGHT (and
perhaps even LX150_SIXTYFOUR) which will require deep interpolation and likely only a
single core will fit onto a LX150, so its not a priority right now.