An Open Source FPGA Litecoin (scrypt) miner

This code is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

Project includes code from https://github.com/progranism/Open-Source-FPGA-Bitcoin-Miner
Scrypt algorithm is based on https://github.com/ckolivas/cgminer/blob/master/scrypt.c
Discussion is at https://forum.litecoin.net/index.php/topic,5162.0.html

Special thanks to fpgaminer for the original bitcoin mining code, teknohog for his
LX150 code, also OrphanedGland, udif, TheSeven, makomk, and newMeat1 as credited on
the fpgaminer bitcoin thread https://bitcointalk.org/index.php?topic=9047.0 and ngzhang
for his Icarus/Lancelot boards and github.

The scrypt algorithm is implemented using on-chip FPGA RAM, so should be portable to any
FPGA large enough to support 1024kBit of RAM (512kBit with interpolation, eg DE0-Nano).
External RAM support could be added, but requires the relevant RAM controller for the
board. Performance will be limited by RAM bandwidth.

The code is proof of concept, further optimisation is required (only a small performance
gain is to be expected though). Internal (pll derived) clock is only 25MHz, limited by
the salsa_core. Further pipelining would increase this, but gives no performance gain
since the scrypt algorithm is essentially serial. RAM is also clocked at this speed, a
faster clock would help improve performance a little (and is essential for external RAM)
at the expense of complexity.

Multiple cores are best implemented using the 512kBit scratchpad as the slower individual
throughput is more than compensated by doubling the number of cores supported. MULTICORE
is now the default. This only affects nonce handling so its safe to use with singe cores
which will simply scan a more limited range (the top nibble is fixed at 0). To revert to
the previous behaviour set the NOMULTICORE macro (but ONLY if using a single core).

Contents
--------
DE2-115-Single  Single full scratchpad core, this is the simplest implementation.

DE0-Nano        Uses interpolation as the full scratchpad does not fit (this is the
                same as LOOKUP_GAP=2 in GPU). Test results ...
                1.16 kHash/sec at 25Mhz (this is Fmax at 85C/Slow model)
                2.09 kHash/sec at 45Mhz
                Fmax is 25MHz, so anything greater may not work reliably on your device.
                BEWARE the onboard psu regulators run HOT to VERY HOT. You may fry them!

experimental    New code, not all fully working.

ICARUS-LX150    A Xilinx LX150 multicore port for ngzhang's Icarus/Lancelot boards.

scripts         Mining scripts.

source          Verilog source code.

Ztex and Cairnsmore CM1
-----------------------
Ports for the Ztex 1.15y and Cairnsmore CM1 quad boards are available in the experimental
folder. Both achieve around 60kHash/sec (total for all four FPGA devices) using a single
core and 16 threads (identical to the current ICARUS-LX150 code). A customised version of
cgminer 3.1.1 must be used (see experimental/Ztex-1-15y/cgminer-3.1.1 which supports both
boards). Bitstreams are linked in the respective READMEs.

Usage
-----
The Altera ports (DE0-Nano) require installation of Quartus II software. For MS Windows
set mining pool connection details by editing scripts/config.tcl then run scripts/mine.bat
This uses getwork protocol and timeouts may occur. There are some configuration switches
in mine.tcl, eg it can run in test mode which sends historical block headers to the fpga
with known nonce results. Use of a stratum proxy server is recommended.