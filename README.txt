FPGA Litecoin (scrypt) miner ... just for the LOLs, the performance is atrocious!

This code is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

Project includes code from https://github.com/progranism/Open-Source-FPGA-Bitcoin-Miner
Scrypt algorithm is based on https://github.com/ckolivas/cgminer/blob/master/scrypt.c

The scrypt algorithm is implimented using on-chip FPGA RAM, so should be portable to any
FPGA large enough to support 1024kBit of RAM (512kBit with interpolation, eg DE0-Nano).
External RAM support could be added, but requires the relevant RAM controller for the
board. Performance will be limited by RAM bandwidth.

The code is proof of concept, further optimisation is required (only a small performance
gain is to be expected though). Internal (pll derived) clock is only 25MHz, limited by
the salsa_core. Further pipelining would increase this, but gives no performance gain
since the scrypt algorithm is essentially serial. RAM is also clocked at this speed, a
faster clock would help improve performance a little (and is essential for external RAM)
at the expense of complexity.

Contents
--------
DE2-115-Single	Single core, this is the simplest implimentation. NOT TESTED as I do
				not have a DE2_115 a board. Should be trivial to add multiple cores.

DE0-Nano		Uses interpolation as the full scratchpad does not fit, which adds
				complexity and reduces speed. TESTED and WORKS at 0.94 KHash/sec.

scripts			Mining scripts.

source			Verilog source code.

A Xilinx LX150 port will be forthcoming fairly soon.

Usage
-----
The Altera ports (DE0-Nano) require installation of Quartus II software. For MS Windows
set mining pool connection details by editing scripts/config.tcl then run scripts/mine.bat