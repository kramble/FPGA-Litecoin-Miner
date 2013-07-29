/* salsa.v ... yes its crude, I'm not very good at verilog
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

module salsa (clk, feedback, B, Bx, Bo);

// Latency 4 clock cycles, approx 40nS propagation delay (SLOW!), but pipelining
// is pointless as we have nothing else to fill the pipe with, so it actually
// REDUCES the throughput due to the setup/propagation delays of the registers.

input clk;
input feedback;
input [511:0]B;
input [511:0]Bx;
// output reg [511:0]Bo;	// Output is registered
output [511:0]Bo;			// Output is async

wire [511:0]xx;			// Initial xor

/*
// Non-feedback version

wire [511:0]x1;			// Salasa core outputs
wire [511:0]x2;
wire [511:0]x3;
wire [511:0]xr;

// Four salsa iterations. NB use registered salsa_core so 4 clock cycles.
salsa_core salsa1 (clk, xx, x1);
salsa_core salsa2 (clk, x1, x2);
salsa_core salsa3 (clk, x2, x3);
salsa_core salsa4 (clk, x3, xr);
*/

// Feedback version
wire [511:0]xr;
reg [511:0]xrd;
//salsa_core salsa1 (clk, feedback ? xr : xx, xr);	// unregistered xr
salsa_core salsa1 (clk, feedback ? xrd : xx, xr);	// registered xrd

genvar i;
generate
	for (i = 0; i < 16; i = i + 1) begin : XX
		// Initial XOR. NB this adds to the propagation delay of the first salsa, may want register it.
		assign xx[`IDX(i)] = B[`IDX(i)] ^ Bx[`IDX(i)];
		// Final sum. This could is subsumed into the final salsa to save a clock.
//		always @ (posedge clk)
//		begin
//			Bo[`IDX(i)] <= xx[`IDX(i)] + xr[`IDX(i)];
//		end
		assign Bo[`IDX(i)] = xx[`IDX(i)] + xr[`IDX(i)];	// Async output (NB bypasses xrd register)
	end
endgenerate

always @ (posedge clk)
	xrd <= xr;

endmodule

module salsa_core (clk, xx, out);

input clk;
input [511:0]xx;
// output reg [511:0]out;		// Output is registered
output [511:0]out;				// Output is unregistered

// This is clunky due to my lack of verilog skills but it works so elegance can come later

wire [31:0]c00;			// Column results
wire [31:0]c01;
wire [31:0]c02;
wire [31:0]c03;
wire [31:0]c04;
wire [31:0]c05;
wire [31:0]c06;
wire [31:0]c07;
wire [31:0]c08;
wire [31:0]c09;
wire [31:0]c10;
wire [31:0]c11;
wire [31:0]c12;
wire [31:0]c13;
wire [31:0]c14;
wire [31:0]c15;

wire [31:0]r00;			// Row results
wire [31:0]r01;
wire [31:0]r02;
wire [31:0]r03;
wire [31:0]r04;
wire [31:0]r05;
wire [31:0]r06;
wire [31:0]r07;
wire [31:0]r08;
wire [31:0]r09;
wire [31:0]r10;
wire [31:0]r11;
wire [31:0]r12;
wire [31:0]r13;
wire [31:0]r14;
wire [31:0]r15;

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

assign c04s = xx[`IDX(0)] + xx[`IDX(12)];
assign c04 = xx[`IDX(4)] ^ { c04s[24:0], c04s[31:25] };
assign c09s = xx[`IDX(5)] + xx[`IDX(1)];
assign c09 = xx[`IDX(9)] ^ { c09s[24:0], c09s[31:25] };
assign c14s = xx[`IDX(10)] + xx[`IDX(6)];
assign c14 = xx[`IDX(14)] ^ { c14s[24:0], c14s[31:25] };
assign c03s = xx[`IDX(15)] + xx[`IDX(11)];
assign c03 = xx[`IDX(03)] ^ { c03s[24:0], c03s[31:25] };

assign c08s = c04 + xx[`IDX(0)];
assign c08 = xx[`IDX(8)] ^ { c08s[22:0], c08s[31:23] };
assign c13s = c09 + xx[`IDX(5)];
assign c13 = xx[`IDX(13)] ^ { c13s[22:0], c13s[31:23] };
assign c02s = c14 + xx[`IDX(10)];
assign c02 = xx[`IDX(2)] ^ { c02s[22:0], c02s[31:23] };
assign c07s = c03 + xx[`IDX(15)];
assign c07 = xx[`IDX(7)] ^ { c07s[22:0], c07s[31:23] };

assign c12s = c08 + c04;
assign c12 = xx[`IDX(12)] ^ { c12s[18:0], c12s[31:19] };
assign c01s = c13 + c09;
assign c01 = xx[`IDX(1)] ^ { c01s[18:0], c01s[31:19] };
assign c06s = c02 + c14;
assign c06 = xx[`IDX(6)] ^ { c06s[18:0], c06s[31:19] };
assign c11s = c07 + c03;
assign c11 = xx[`IDX(11)] ^ { c11s[18:0], c11s[31:19] };

assign c00s = c12 + c08;
assign c00 = xx[`IDX(0)] ^ { c00s[13:0], c00s[31:14] };
assign c05s = c01 + c13;
assign c05 = xx[`IDX(5)] ^ { c05s[13:0], c05s[31:14] };
assign c10s = c06 + c02;
assign c10 = xx[`IDX(10)] ^ { c10s[13:0], c10s[31:14] };
assign c15s = c11 + c07;
assign c15 = xx[`IDX(15)] ^ { c15s[13:0], c15s[31:14] };

// rows

assign r01s = c00 + c03;
assign r01 = c01 ^ { r01s[24:0], r01s[31:25] };
assign r06s = c05 + c04;
assign r06 = c06 ^ { r06s[24:0], r06s[31:25] };
assign r11s = c10 + c09;
assign r11 = c11 ^ { r11s[24:0], r11s[31:25] };
assign r12s = c15 + c14;
assign r12 = c12 ^ { r12s[24:0], r12s[31:25] };

assign r02s = r01 + c00;
assign r02 = c02 ^ { r02s[22:0], r02s[31:23] };
assign r07s = r06 + c05;
assign r07 = c07 ^ { r07s[22:0], r07s[31:23] };
assign r08s = r11 + c10;
assign r08 = c08 ^ { r08s[22:0], r08s[31:23] };
assign r13s = r12 + c15;
assign r13 = c13 ^ { r13s[22:0], r13s[31:23] };

assign r03s = r02 + r01;
assign r03 = c03 ^ { r03s[18:0], r03s[31:19] };
assign r04s = r07 + r06;
assign r04 = c04 ^ { r04s[18:0], r04s[31:19] };
assign r09s = r08 + r11;
assign r09 = c09 ^ { r09s[18:0], r09s[31:19] };
assign r14s = r13 + r12;
assign r14 = c14 ^ { r14s[18:0], r14s[31:19] };

assign r00s = r03 + r02;
assign r00 = c00 ^ { r00s[13:0], r00s[31:14] };
assign r05s = r04 + r07;
assign r05 = c05 ^ { r05s[13:0], r05s[31:14] };
assign r10s = r09 + r08;
assign r10 = c10 ^ { r10s[13:0], r10s[31:14] };
assign r15s = r14 + r13;
assign r15 = c15 ^ { r15s[13:0], r15s[31:14] };


assign out = { r15, r14, r13, r12, r11, r10, r09, r08, r07, r06, r05, r04, r03, r02, r01, r00 };

// Registered output ...
// wire [511:0]xo;			// Rename row results
// assign xo = { r15, r14, r13, r12, r11, r10, r09, r08, r07, r06, r05, r04, r03, r02, r01, r00 };

// Output is registered, but may want to make it async
// always @ (posedge clk)
//	out <= xo;

endmodule
