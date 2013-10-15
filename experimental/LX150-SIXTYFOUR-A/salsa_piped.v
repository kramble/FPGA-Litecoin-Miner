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

module salsa (clk, B, Bx, Bo, X0out, Xaddr);

// Latency 9 clock cycles (4 col steps + 4 row + 1 sync), hence 4 salsa iterations in 36 cycles

input clk;
input [511:0]B;
input [511:0]Bx;
output [511:0]Bo;		// Output is async
output [511:0]X0out;	// Becomes new X0
output [9:0]Xaddr;		// Address

wire [9:0] xa1, xa2, xa3, xa4, ya1, ya2, ya3, ya4;

reg [511:0]x1d1, x1d1a, x1d1b, x1d1c, x1d1d, x1d1e, x1d1f, x1d1g;
reg [511:0]x1d2, x1d2a, x1d2b, x1d2c, x1d2d, x1d2e, x1d2f, x1d2g;
reg [511:0]x1d3, x1d3a, x1d3b, x1d3c, x1d3d, x1d3e, x1d3f, x1d3g;
reg [511:0]x1d4, x1d4a, x1d4b, x1d4c, x1d4d, x1d4e, x1d4f, x1d4g;

reg [511:0]Xod1, Xod1a, Xod1b, Xod1c, Xod1d, Xod1e, Xod1f, Xod1g;
reg [511:0]Xod2, Xod2a, Xod2b, Xod2c, Xod2d, Xod2e, Xod2f, Xod2g;
reg [511:0]Xod3, Xod3a, Xod3b, Xod3c, Xod3d, Xod3e, Xod3f, Xod3g;
reg [511:0]Xod4, Xod4a, Xod4b, Xod4c, Xod4d, Xod4e, Xod4f, X0out;

reg [511:0]xxd1, xxd1a, xxd1b, xxd1c, xxd1d, xxd1e, xxd1f, xxd1g;
reg [511:0]xxd2, xxd2a, xxd2b, xxd2c, xxd2d, xxd2e, xxd2f, xxd2g;
reg [511:0]xxd3, xxd3a, xxd3b, xxd3c, xxd3d, xxd3e, xxd3f, xxd3g;
reg [511:0]xxd4, xxd4a, xxd4b, xxd4c, xxd4d, xxd4e, xxd4f, xxd4g;

reg [511:0]yyd1, yyd1a, yyd1b, yyd1c, yyd1d, yyd1e, yyd1f, yyd1g;
reg [511:0]yyd2, yyd2a, yyd2b, yyd2c, yyd2d, yyd2e, yyd2f, yyd2g;
reg [511:0]yyd3, yyd3a, yyd3b, yyd3c, yyd3d, yyd3e, yyd3f, yyd3g;
reg [511:0]yyd4, yyd4a, yyd4b, yyd4c, yyd4d, yyd4e, yyd4f, yyd4g;

wire [511:0]xx;			// Initial xor
wire [511:0]x1;			// Salasa core outputs
wire [511:0]x2;
wire [511:0]x3;
wire [511:0]xr;
wire [511:0]Xo;

// Four salsa iterations. NB use registered salsa_core so 4 clock cycles.
salsa_core salsax1 (clk, xx, x1, xa1);
salsa_core salsax2 (clk, x1, x2, xa2);
salsa_core salsax3 (clk, x2, x3, xa3);
salsa_core salsax4 (clk, x3, xr, xa4);

wire [511:0]yy;			// Initial xor
wire [511:0]y1;			// Salasa core outputs
wire [511:0]y2;
wire [511:0]y3;
wire [511:0]yr;

// Four salsa iterations. NB use registered salsa_core so 4 clock cycles.
salsa_core salsay1 (clk, yy, y1, ya1);
salsa_core salsay2 (clk, y1, y2, ya2);
salsa_core salsay3 (clk, y2, y3, ya3);
salsa_core salsay4 (clk, y3, yr, ya4);

assign Xaddr = yyd4f[9:0] + ya4;

genvar i;
generate
	for (i = 0; i < 16; i = i + 1) begin : XX
		// Initial XOR. NB this adds to the propagation delay of the first salsa, may want register it.
		assign xx[`IDX(i)] = B[`IDX(i)] ^ Bx[`IDX(i)];
		assign Xo[`IDX(i)] = xxd4g[`IDX(i)] + xr[`IDX(i)];
		assign yy[`IDX(i)] = x1d4g[`IDX(i)] ^ Xo[`IDX(i)];
		assign Bo[`IDX(i)] = yyd4g[`IDX(i)] + yr[`IDX(i)];	// Async output
	end
endgenerate

always @ (posedge clk)
begin
	x1d1 <= Bx;
	x1d1a <= x1d1;
	x1d1b <= x1d1a;
	x1d1c <= x1d1b;
	x1d1d <= x1d1c;
	x1d1e <= x1d1d;
	x1d1f <= x1d1e;
	x1d1g <= x1d1f;

	x1d2 <= x1d1g;
	x1d2a <= x1d2;
	x1d2b <= x1d2a;
	x1d2c <= x1d2b;
	x1d2d <= x1d2c;
	x1d2e <= x1d2d;
	x1d2f <= x1d2e;
	x1d2g <= x1d2f;

	x1d3 <= x1d2g;
	x1d3a <= x1d3;
	x1d3b <= x1d3a;
	x1d3c <= x1d3b;
	x1d3d <= x1d3c;
	x1d3e <= x1d3d;
	x1d3f <= x1d3e;
	x1d3g <= x1d3f;

	x1d4 <= x1d3g;
	x1d4a <= x1d4;
	x1d4b <= x1d4a;
	x1d4c <= x1d4b;
	x1d4d <= x1d4c;
	x1d4e <= x1d4d;
	x1d4f <= x1d4e;
	x1d4g <= x1d4f;

	Xod1 <= Xo;
	Xod1a <= Xod1;
	Xod1b <= Xod1a;
	Xod1c <= Xod1b;
	Xod1d <= Xod1c;
	Xod1e <= Xod1d;
	Xod1f <= Xod1e;
	Xod1g <= Xod1f;

	Xod2 <= Xod1g;
	Xod2a <= Xod2;
	Xod2b <= Xod2a;
	Xod2c <= Xod2b;
	Xod2d <= Xod2c;
	Xod2e <= Xod2d;
	Xod2f <= Xod2e;
	Xod2g <= Xod2f;

	Xod3 <= Xod2g;
	Xod3a <= Xod3;
	Xod3b <= Xod3a;
	Xod3c <= Xod3b;
	Xod3d <= Xod3c;
	Xod3e <= Xod3d;
	Xod3f <= Xod3e;
	Xod3g <= Xod3f;

	Xod4 <= Xod3g;
	Xod4a <= Xod4;
	Xod4b <= Xod4a;
	Xod4c <= Xod4b;
	Xod4d <= Xod4c;
	Xod4e <= Xod4d;
	Xod4f <= Xod4e;
	X0out <= Xod4f;

	xxd1 <= xx;
	xxd1a <= xxd1;
	xxd1b <= xxd1a;
	xxd1c <= xxd1b;
	xxd1d <= xxd1c;
	xxd1e <= xxd1d;
	xxd1f <= xxd1e;
	xxd1g <= xxd1f;

	xxd2 <= xxd1g;
	xxd2a <= xxd2;
	xxd2b <= xxd2a;
	xxd2c <= xxd2b;
	xxd2d <= xxd2c;
	xxd2e <= xxd2d;
	xxd2f <= xxd2e;
	xxd2g <= xxd2f;

	xxd3 <= xxd2g;
	xxd3a <= xxd3;
	xxd3b <= xxd3a;
	xxd3c <= xxd3b;
	xxd3d <= xxd3c;
	xxd3e <= xxd3d;
	xxd3f <= xxd3e;
	xxd3g <= xxd3f;

	xxd4 <= xxd3g;
	xxd4a <= xxd4;
	xxd4b <= xxd4a;
	xxd4c <= xxd4b;
	xxd4d <= xxd4c;
	xxd4e <= xxd4d;
	xxd4f <= xxd4e;
	xxd4g <= xxd4f;

	yyd1 <= yy;
	yyd1a <= yyd1;
	yyd1b <= yyd1a;
	yyd1c <= yyd1b;
	yyd1d <= yyd1c;
	yyd1e <= yyd1d;
	yyd1f <= yyd1e;
	yyd1g <= yyd1f;

	yyd2 <= yyd1g;
	yyd2a <= yyd2;
	yyd2b <= yyd2a;
	yyd2c <= yyd2b;
	yyd2d <= yyd2c;
	yyd2e <= yyd2d;
	yyd2f <= yyd2e;
	yyd2g <= yyd2f;

	yyd3 <= yyd2g;
	yyd3a <= yyd3;
	yyd3b <= yyd3a;
	yyd3c <= yyd3b;
	yyd3d <= yyd3c;
	yyd3e <= yyd3d;
	yyd3f <= yyd3e;
	yyd3g <= yyd3f;

	yyd4 <= yyd3g;
	yyd4a <= yyd4;
	yyd4b <= yyd4a;
	yyd4c <= yyd4b;
	yyd4d <= yyd4c;
	yyd4e <= yyd4d;
	yyd4f <= yyd4e;
	yyd4g <= yyd4f;

end

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
