/* salsa_slowsixteen.v
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

// Latency 16 clock cycles, approx 20nS propagation delay (SLOW!)

input clk;
// input feedback;
input [511:0]B;
input [511:0]Bx;
// output reg [511:0]Bo;	// Output is registered
output [511:0]Bo;			// Output is async
output [511:0]X0out;		// Becomes new X0
output [9:0] Xaddr;
wire [9:0] xa1, xa2, xa3, xa4, ya1, ya2, ya3, ya4;

reg [511:0]x1d1, x1d1a;
reg [511:0]x1d2, x1d2a;
reg [511:0]x1d3, x1d3a;
reg [511:0]x1d4, x1d4a;

reg [511:0]Xod1, Xod1a;
reg [511:0]Xod2, Xod2a;
reg [511:0]Xod3, Xod3a;
reg [511:0]Xod4, X0out;

reg [511:0]xxd1, xxd1a;
reg [511:0]xxd2, xxd2a;
reg [511:0]xxd3, xxd3a;
reg [511:0]xxd4, xxd4a;

reg [511:0]yyd1, yyd1a;
reg [511:0]yyd2, yyd2a;
reg [511:0]yyd3, yyd3a;
reg [511:0]yyd4, yyd4a;

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

assign Xaddr = yyd4[9:0] + ya4;

genvar i;
generate
	for (i = 0; i < 16; i = i + 1) begin : XX
		// Initial XOR. NB this adds to the propagation delay of the first salsa, may want register it.
		assign xx[`IDX(i)] = B[`IDX(i)] ^ Bx[`IDX(i)];
		assign Xo[`IDX(i)] = xxd4a[`IDX(i)] + xr[`IDX(i)];
		assign yy[`IDX(i)] = x1d4a[`IDX(i)] ^ Xo[`IDX(i)];
		assign Bo[`IDX(i)] = yyd4a[`IDX(i)] + yr[`IDX(i)];	// Async output
	end
endgenerate

always @ (posedge clk)
begin
	x1d1 <= Bx;
	x1d1a <= x1d1;
	x1d2 <= x1d1a;
	x1d2a <= x1d2;
	x1d3 <= x1d2a;
	x1d3a <= x1d3;
	x1d4 <= x1d3a;
	x1d4a <= x1d4;
	Xod1 <= Xo;
	Xod1a <= Xod1;
	Xod2 <= Xod1a;
	Xod2a <= Xod2;
	Xod3 <= Xod2a;
	Xod3a <= Xod3;
	Xod4 <= Xod3a;
	X0out <= Xod4;	// We output this to become new X0

	xxd1 <= xx;
	xxd1a <= xxd1;
	xxd2 <= xxd1a;
	xxd2a <= xxd2;
	xxd3 <= xxd2a;
	xxd3a <= xxd3;
	xxd4 <= xxd3a;
	xxd4a <= xxd4;

	yyd1 <= yy;
	yyd1a <= yyd1;
	yyd2 <= yyd1a;
	yyd2a <= yyd2;
	yyd3 <= yyd2a;
	yyd3a <= yyd3;
	yyd4 <= yyd3a;
	yyd4a <= yyd4;

end

endmodule

module salsa_core (clk, xx, out, Xaddr);

input clk;
input [511:0]xx;
output reg [511:0]out;		// Output is registered
output [9:0] Xaddr;			// Address output unregistered

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

reg [31:0]c00d;			// Column results registered
reg [31:0]c01d;
reg [31:0]c02d;
reg [31:0]c03d;
reg [31:0]c04d;
reg [31:0]c05d;
reg [31:0]c06d;
reg [31:0]c07d;
reg [31:0]c08d;
reg [31:0]c09d;
reg [31:0]c10d;
reg [31:0]c11d;
reg [31:0]c12d;
reg [31:0]c13d;
reg [31:0]c14d;
reg [31:0]c15d;

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

assign r01s = c00d + c03d;
assign r01 = c01d ^ { r01s[24:0], r01s[31:25] };
assign r06s = c05d + c04d;
assign r06 = c06d ^ { r06s[24:0], r06s[31:25] };
assign r11s = c10d + c09d;
assign r11 = c11d ^ { r11s[24:0], r11s[31:25] };
assign r12s = c15d + c14d;
assign r12 = c12d ^ { r12s[24:0], r12s[31:25] };

assign r02s = r01 + c00d;
assign r02 = c02d ^ { r02s[22:0], r02s[31:23] };
assign r07s = r06 + c05d;
assign r07 = c07d ^ { r07s[22:0], r07s[31:23] };
assign r08s = r11 + c10d;
assign r08 = c08d ^ { r08s[22:0], r08s[31:23] };
assign r13s = r12 + c15d;
assign r13 = c13d ^ { r13s[22:0], r13s[31:23] };

assign r03s = r02 + r01;
assign r03 = c03d ^ { r03s[18:0], r03s[31:19] };
assign r04s = r07 + r06;
assign r04 = c04d ^ { r04s[18:0], r04s[31:19] };
assign r09s = r08 + r11;
assign r09 = c09d ^ { r09s[18:0], r09s[31:19] };
assign r14s = r13 + r12;
assign r14 = c14d ^ { r14s[18:0], r14s[31:19] };

assign r00s = r03 + r02;
assign r00 = c00d ^ { r00s[13:0], r00s[31:14] };
assign r05s = r04 + r07;
assign r05 = c05d ^ { r05s[13:0], r05s[31:14] };
assign r10s = r09 + r08;
assign r10 = c10d ^ { r10s[13:0], r10s[31:14] };
assign r15s = r14 + r13;
assign r15 = c15d ^ { r15s[13:0], r15s[31:14] };

wire [511:0]xo;			// Rename row results
assign xo = { r15, r14, r13, r12, r11, r10, r09, r08, r07, r06, r05, r04, r03, r02, r01, r00 };

assign Xaddr = xo[9:0];	// Unregistered output

always @ (posedge clk)
begin
	c00d <= c00;
	c01d <= c01;
	c02d <= c02;
	c03d <= c03;
	c04d <= c04;
	c05d <= c05;
	c06d <= c06;
	c07d <= c07;
	c08d <= c08;
	c09d <= c09;
	c10d <= c10;
	c11d <= c11;
	c12d <= c12;
	c13d <= c13;
	c14d <= c14;
	c15d <= c15;
	out <= xo;		// Registered output
end

endmodule
