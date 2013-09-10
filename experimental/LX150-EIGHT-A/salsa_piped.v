/* salsa_piped.v ... fully registered salsa core (column and row results regs)
*
* Copyright (c) 2013 kramble
* Derived from scrypt.c Copyright 2009 Colin Percival, 2011 ArtForz
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
* 
*/

`timescale 1ns/1ps

`define IDX(x) (((x)+1)*(32)-1):((x)*(32))

module salsa (clk, feedback, B, Bx, Bo, X0out, X1out, Xaddr);

// Latency 9 clock cycles (4 col steps + 4 row + 1 sync), hence 4 salsa iterations in 36 cycles

input clk;
input feedback;
input [511:0]B;
input [511:0]Bx;
output [511:0]Bo;
output [511:0]X0out;	// Pipelined B
output [511:0]X1out;	// Pipelined Bx
output [9:0]Xaddr;		// Address

wire [511:0]xx;			// Initial xor
wire [511:0]xxd8;		// Delayed 8 cycles

wire [511:0]xr;			// Output of salsa core
reg [511:0]xrd;			// Feedback (9th latency step to maintain sync with ram access)

wire [9:0]addr;			// Address from salsa
reg [9:0]xxd7_addr;

// X0/X1 delays ... just to check timing, probably need to use a ram location to reduce routing congestion

reg [511:0]x0d1;
reg [511:0]x0d2;
reg [511:0]x0d3;
reg [511:0]x0d4;
reg [511:0]x0d5;
reg [511:0]x0d6;
reg [511:0]x0d7;
reg [511:0]x0d8;

reg [511:0]x1d1;
reg [511:0]x1d2;
reg [511:0]x1d3;
reg [511:0]x1d4;
reg [511:0]x1d5;
reg [511:0]x1d6;
reg [511:0]x1d7;
reg [511:0]x1d8;

assign X0out = x0d8;
assign X1out = x1d8;

salsa_core salsa1 (clk, feedback ? xrd : xx, xr, addr);

always @ (posedge clk)
begin
	xrd <= xr;

	x0d1 <= B;
	x0d2 <= x0d1;
	x0d3 <= x0d2;
	x0d4 <= x0d3;
	x0d5 <= x0d4;
	x0d6 <= x0d5;
	x0d7 <= x0d6;
	x0d8 <= x0d7;
	
	x1d1 <= Bx;
	x1d2 <= x1d1;
	x1d3 <= x1d2;
	x1d4 <= x1d3;
	x1d5 <= x1d4;
	x1d6 <= x1d5;
	x1d7 <= x1d6;
	x1d8 <= x1d7;
	
	xxd7_addr <= x0d6[9:0] ^ x1d6[9:0];
end
	
genvar i;
generate
	for (i = 0; i < 16; i = i + 1) begin : XX
		// Initial XOR. NB this adds to the propagation delay of the first salsa, may want register it.
		assign xx[`IDX(i)] = B[`IDX(i)] ^ Bx[`IDX(i)];
		assign xxd8[`IDX(i)] = x0d8[`IDX(i)] ^ x1d8[`IDX(i)];		// Could do one cycle early (in reg) to save an xor delay
		// Final sum. NB Ouptut is at 8 cycle latency.
		assign Bo[`IDX(i)] = xxd8[`IDX(i)] + xr[`IDX(i)];
	end
endgenerate

assign Xaddr = xxd7_addr + addr;

endmodule

module salsa_core (clk, x, out, addr);

input clk;
input [511:0]x;
output [511:0]out;
output [9:0]addr;

// This is clunky due to my lack of verilog skills but it works so elegance can come later
// ... actually its now gotten quite ridiculous, see KLUDGE below

// Aliases for inputs

wire [31:0] x00;
wire [31:0] x01;
wire [31:0] x02;
wire [31:0] x03;
wire [31:0] x04;
wire [31:0] x05;
wire [31:0] x06;
wire [31:0] x07;
wire [31:0] x08;
wire [31:0] x09;
wire [31:0] x10;
wire [31:0] x11;
wire [31:0] x12;
wire [31:0] x13;
wire [31:0] x14;
wire [31:0] x15;

assign x00 = x[`IDX(0)];
assign x01 = x[`IDX(1)];
assign x02 = x[`IDX(2)];
assign x03 = x[`IDX(3)];
assign x04 = x[`IDX(4)];
assign x05 = x[`IDX(5)];
assign x06 = x[`IDX(6)];
assign x07 = x[`IDX(7)];
assign x08 = x[`IDX(8)];
assign x09 = x[`IDX(9)];
assign x10 = x[`IDX(10)];
assign x11 = x[`IDX(11)];
assign x12 = x[`IDX(12)];
assign x13 = x[`IDX(13)];
assign x14 = x[`IDX(14)];
assign x15 = x[`IDX(15)];

// Column & Row Results (yup, I wrote a program to generate these) ...
// Not all of these are used, but let the synthesizer take care of that for now
// TODO prune the unused ones, may be important with certain synth settings

// BEGIN KLUDGE
`include "sgen.inc"			// .inc so it does not accidentally get compiled separately as .v
// END KLUDGE

wire [31:0]c00s;			// Column sums
wire [31:0]c01s;
wire [31:0]c02s;
wire [31:0]c03s;
wire [31:0]c04s;
wire [31:0]c05s;
wire [31:0]c06s;
wire [31:0]c07s;
wire [31:0]c08s;
wire [31:0]c09s;
wire [31:0]c10s;
wire [31:0]c11s;
wire [31:0]c12s;
wire [31:0]c13s;
wire [31:0]c14s;
wire [31:0]c15s;

wire [31:0]r00s;			// Row sums
wire [31:0]r01s;
wire [31:0]r02s;
wire [31:0]r03s;
wire [31:0]r04s;
wire [31:0]r05s;
wire [31:0]r06s;
wire [31:0]r07s;
wire [31:0]r08s;
wire [31:0]r09s;
wire [31:0]r10s;
wire [31:0]r11s;
wire [31:0]r12s;
wire [31:0]r13s;
wire [31:0]r14s;
wire [31:0]r15s;

wire [31:0]r00sx;

/* From scrypt.c

#define R(a,b) (((a) << (b)) | ((a) >> (32 - (b))))
	for (i = 0; i < 8; i += 2) {
		// Operate on columns
		x04 ^= R(x00+x12, 7);	x09 ^= R(x05+x01, 7);	x14 ^= R(x10+x06, 7);	x03 ^= R(x15+x11, 7);
		x08 ^= R(x04+x00, 9);	x13 ^= R(x09+x05, 9);	x02 ^= R(x14+x10, 9);	x07 ^= R(x03+x15, 9);
		x12 ^= R(x08+x04,13);	x01 ^= R(x13+x09,13);	x06 ^= R(x02+x14,13);	x11 ^= R(x07+x03,13);
		x00 ^= R(x12+x08,18);	x05 ^= R(x01+x13,18);	x10 ^= R(x06+x02,18);	x15 ^= R(x11+x07,18);

		// Operate on rows
		x01 ^= R(x00+x03, 7);	x06 ^= R(x05+x04, 7);	x11 ^= R(x10+x09, 7);	x12 ^= R(x15+x14, 7);
		x02 ^= R(x01+x00, 9);	x07 ^= R(x06+x05, 9);	x08 ^= R(x11+x10, 9);	x13 ^= R(x12+x15, 9);
		x03 ^= R(x02+x01,13);	x04 ^= R(x07+x06,13);	x09 ^= R(x08+x11,13);	x14 ^= R(x13+x12,13);
		x00 ^= R(x03+x02,18);	x05 ^= R(x04+x07,18);	x10 ^= R(x09+x08,18);	x15 ^= R(x14+x13,18);
	}
*/

// cols

assign c04s = x00 + x12;
assign c09s = x05 + x01;
assign c14s = x10 + x06;
assign c03s = x15 + x11;

assign c08s = c04 + x00d1;
assign c13s = c09 + x05d1;
assign c02s = c14 + x10d1;
assign c07s = c03 + x15d1;

assign c12s = c08 + c04d1;
assign c01s = c13 + c09d1;
assign c06s = c02 + c14d1;
assign c11s = c07 + c03d1;

assign c00s = c12 + c08d1;
assign c05s = c01 + c13d1;
assign c10s = c06 + c02d1;
assign c15s = c11 + c07d1;

// rows

assign r01s = c00 + c03d3;
assign r06s = c05 + c04d3;
assign r11s = c10 + c09d3;
assign r12s = c15 + c14d3;

assign r02s = r01 + c00d1;
assign r07s = r06 + c05d1;
assign r08s = r11 + c10d1;
assign r13s = r12 + c15d1;

assign r03s = r02 + r01d1;
assign r04s = r07 + r06d1;
assign r09s = r08 + r11d1;
assign r14s = r13 + r12d1;

assign r00s = r03 + r02d1;
assign r05s = r04 + r07d1;
assign r10s = r09 + r08d1;
assign r15s = r14 + r13d1;

// Hack to bring out address one cycle earlier
assign r00sx = c00d3 ^ { r00s[13:0], r00s[31:14] };
assign addr = r00sx[9:0];

assign out = { r15, r14d1, r13d2, r12d3, r11d3, r10, r09d1, r08d2, r07d2, r06d3, r05, r04d1, r03d1, r02d2, r01d3, r00 };

always @ (posedge clk)
begin
	c04 <= x04 ^ { c04s[24:0], c04s[31:25] };
	c09 <= x09 ^ { c09s[24:0], c09s[31:25] };
	c14 <= x14 ^ { c14s[24:0], c14s[31:25] };
	c03 <= x03 ^ { c03s[24:0], c03s[31:25] };

	c08 <= x08d1 ^ { c08s[22:0], c08s[31:23] };
	c13 <= x13d1 ^ { c13s[22:0], c13s[31:23] };
	c02 <= x02d1 ^ { c02s[22:0], c02s[31:23] };
	c07 <= x07d1 ^ { c07s[22:0], c07s[31:23] };

	c12 <= x12d2 ^ { c12s[18:0], c12s[31:19] };
	c01 <= x01d2 ^ { c01s[18:0], c01s[31:19] };
	c06 <= x06d2 ^ { c06s[18:0], c06s[31:19] };
	c11 <= x11d2 ^ { c11s[18:0], c11s[31:19] };

	c00 <= x00d3 ^ { c00s[13:0], c00s[31:14] };
	c05 <= x05d3 ^ { c05s[13:0], c05s[31:14] };
	c10 <= x10d3 ^ { c10s[13:0], c10s[31:14] };
	c15 <= x15d3 ^ { c15s[13:0], c15s[31:14] };

	r01 <= c01d1 ^ { r01s[24:0], r01s[31:25] };
	r06 <= c06d1 ^ { r06s[24:0], r06s[31:25] };
	r11 <= c11d1 ^ { r11s[24:0], r11s[31:25] };
	r12 <= c12d1 ^ { r12s[24:0], r12s[31:25] };

	r02 <= c02d3 ^ { r02s[22:0], r02s[31:23] };
	r07 <= c07d3 ^ { r07s[22:0], r07s[31:23] };
	r08 <= c08d3 ^ { r08s[22:0], r08s[31:23] };
	r13 <= c13d3 ^ { r13s[22:0], r13s[31:23] };

	r03 <= c03d5 ^ { r03s[18:0], r03s[31:19] };
	r04 <= c04d5 ^ { r04s[18:0], r04s[31:19] };
	r09 <= c09d5 ^ { r09s[18:0], r09s[31:19] };
	r14 <= c14d5 ^ { r14s[18:0], r14s[31:19] };

	// r00 <= c00d3 ^ { r00s[13:0], r00s[31:14] };
	r00 <= r00sx;
	r05 <= c05d3 ^ { r05s[13:0], r05s[31:14] };
	r10 <= c10d3 ^ { r10s[13:0], r10s[31:14] };
	r15 <= c15d3 ^ { r15s[13:0], r15s[31:14] };
end
endmodule
