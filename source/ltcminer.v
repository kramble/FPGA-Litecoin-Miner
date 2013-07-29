/* ltcminer.v
*
* Copyright (c) 2013 kramble
* Parts copyright (c) 2011 fpgaminer@bitcoin-mining.com
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

`ifdef NOLEDS
	module ltcminer (osc_clk);		// Version without LEDs for DE2-115
`else
	module ltcminer (osc_clk, LEDS_out);
`endif
	
	parameter SPEED_MHZ = 25;		// Sets PLL hash_clk speed (1MHz resolution)

	input osc_clk;
`ifndef NOLEDS
	output [7:0]LEDS_out;			// Optional progress indicator
`endif

	wire hash_clk;
	`ifndef SIM
		main_pll #(.SPEED_MHZ(SPEED_MHZ)) pll_blk (osc_clk, hash_clk);
	`else
	 	assign hash_clk = osc_clk;
	`endif

// Virtual wire is now done here rather than in hashcore so as to support MULTICORE	

`ifndef SIM
	// 80 byte block header (NB this implimetation does not use midstate)
	reg [255:0] data1 = 256'd0;
	reg [255:0] data2 = 256'd0;
	reg [127:0] data3 = 128'd0;
`else
	// Test data (random, not a real block)
	// reg [255:0] data1 = 256'h1f1e1d1c1b1a191817161514131211100f0e0d0c0b0a09080706050403020100;
	// reg [255:0] data2 = 256'h3f3e3d3c3b3a393837363534333231302f2e2d2c2b2a29282726252423222120;
	// reg [127:0] data3 = 128'h000000004b4a49484746454443424140;	// NB 00000000 is loaded into nonce
	// final_hash=16d170aec022c94d5819933902015545da66245a9af20df542b28759400b5698 (NOT a match)

	// Live test data (MATCH nonce 0000318f)
	reg [255:0] data1 = 256'h18e7b1e8eaf0b62a90d1942ea64d250357e9a09c063a47827c57b44e01000000;
	reg [255:0] data2 = 256'hc791d4646240fc2a2d1b80900020a24dc501ef1599fc48ed6cbac920af755756;
	reg [127:0] data3 = 128'h0000318f7e71441b141fe951b2b0c7df;	// NB 0000318f is loaded into nonce
`endif
	
	// Target ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff070000 (7ff is 2048) will match 2048/4G hashes ie 1/2097152
	reg [31:0] target = 31'h000007ff;	// Default to diff=32 for sane startup, this is overwritten by virtual_wire

	wire [31:0] nonce_out;
	wire [31:0] golden_nonce_out;
	wire golden_nonce_match;			// Unused in JTAG comms but needed for serial comms
	wire [3:0] nonce_msb = 4'd0;		// Only used if MULTICORE is defined
	
	hashcore uut (hash_clk, data1, data2, data3, target, nonce_msb, nonce_out, golden_nonce_out, golden_nonce_match);

	/*
		// Example dual core version (UNTESTED)
		// NB must define MULTICORE to enable nonce_msb, set it in assignments/settings/Verilog HDL Input/HDL Macro
		// or just add to ltcminer.qsf ... set_global_assignment -name VERILOG_MACRO "MULTICORE=1"

		reg [31:0] golden_nonce_out = 31'd0;
		wire [31:0] nonce_out;

		wire [31:0] nonce_out0;
		wire [31:0] golden_nonce_out0;
		wire golden_nonce_match0;
		wire [31:0] nonce_out1;
		wire [31:0] golden_nonce_out1;
		wire golden_nonce_match1;
		
		assign nonce_out = nonce_out0;	// For virtual vire NONC

		hashcore uut1 (hash_clk, data1, data2, data3, target, 4'd0, nonce_out0, golden_nonce_out0, golden_nonce_match0);
		hashcore uut2 (hash_clk, data1, data2, data3, target, 4'd1, nonce_out1, golden_nonce_out1, golden_nonce_match1);

		always @ (posedge hash_clk)
		begin
			// Very simple queue, just latch most recent result
			if (golden_nonce_match0)
				golden_nonce_out <= golden_nonce_out0;
			if (golden_nonce_match1)
				golden_nonce_out <= golden_nonce_out1;
		end
	*/
	
	`ifndef SIM

	//// Virtual Wire Control
	wire [255:0] data1_vw;
	wire [255:0] data2_vw;
	wire [127:0] data3_vw;		// 96 bits actually used, the extra 32 are the nonce, normally all zeros but for
								// testing we can supply a nonce which will be loaded
	wire [31:0] target_vw;		// This depends on the pool, but should be constant once sent

	virtual_wire # (.PROBE_WIDTH(0), .WIDTH(256), .INSTANCE_ID("DAT1")) data1_vw_blk(.probe(), .source(data1_vw));
	virtual_wire # (.PROBE_WIDTH(0), .WIDTH(256), .INSTANCE_ID("DAT2")) data2_vw_blk(.probe(), .source(data2_vw));
	virtual_wire # (.PROBE_WIDTH(0), .WIDTH(128), .INSTANCE_ID("DAT3")) data3_vw_blk(.probe(), .source(data3_vw));
	virtual_wire # (.PROBE_WIDTH(0), .WIDTH(32), .INSTANCE_ID("TARG")) target_vw_blk(.probe(), .source(target_vw));

	always @ (posedge hash_clk)
	begin
		data1 <= data1_vw;
		data2 <= data2_vw;
		data3 <= data3_vw;
		target <= target_vw;
	end

	//// Virtual Wire Output
	
	virtual_wire # (.PROBE_WIDTH(32), .WIDTH(0), .INSTANCE_ID("GNON")) golden_nonce_vw_blk (.probe(golden_nonce_out), .source());
	virtual_wire # (.PROBE_WIDTH(32), .WIDTH(0), .INSTANCE_ID("NONC")) nonce_vw_blk (.probe(nonce_out), .source());

	`endif
	

`ifndef NOLEDS
	assign LEDS_out = nonce_out[15:8];		// Optional LED progress indicator
`endif

endmodule
