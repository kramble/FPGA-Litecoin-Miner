/* salsaengine.v
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

// HALFRAM is slightly lazily implemented as some regs/wires are not commented
// out for the full scratchpad, the synthesizer should remove most of these.

`define HALFRAM		// Select between 1024kBit and 512kBit ram

`timescale 1ns/1ps

module salsaengine (hash_clk, reset, din, dout, shift, start, busy, result );

	input hash_clk, reset, din, shift, start;
	output reg busy = 1'b0;
	output reg result = 1'b0;
	output dout;

	parameter XSnull = 0, XSload = 1, XSmix = 2, XSram = 4;		// one-hot
	reg [2:0] XCtl = XSnull;
	
	// Salsa Mix FSM (handles both loading of the scratchpad ROM and the subsequent processing)

	parameter R_IDLE=0, R_START=1, R_WRITE=2, R_MIX=4, R_INT=8;		// Try explicit one-hot
	reg [3:0] mstate = R_IDLE;
	reg [10:0] cycle = 11'd0;
	reg [5:0] mcount = 5'd0;	// Salsa latency
	reg doneROM = 1'd0;			// Yes ROM, as its referred thus in the salsa docs
	reg mixfeedback = 1'b0;
	reg addrsourceMix = 1'b0;
	reg addrsourceSave = 1'b0;
	reg xoren = 1'b1;
	reg	 [1:0] intcycles = 2'b0;	// Number of interpolation cycles required

	wire [511:0] Xmix;
	reg [511:0] X0;
	reg [511:0] X1;
	wire [511:0] X0in;
	wire [511:0] X1in;
	reg [1023:0] salsaShiftReg;
	assign dout = salsaShiftReg[1023];

	// Convert salsaShiftReg to little-endian word format to match scrypt.c as its easier to debug it
	// this way rather than recoding the SMix salsa to work with original buffer

	wire [1023:0] X;
	`define IDX(x) (((x)+1)*(32)-1):((x)*(32))
	genvar i;
	generate
	for (i = 0; i < 32; i = i + 1) begin : Xrewire
		wire [31:0] tmp;
		assign tmp = salsaShiftReg[`IDX(i)];
		assign X[`IDX(i)] = { tmp[7:0], tmp[15:8], tmp[23:16], tmp[31:24] };
	end
	endgenerate

	// NB writeaddr is cycle counter in R_WRITE so use full size regardless of HALFRAM mode
	reg [9:0] writeaddr = 10'd0;
	
	// ALTRAM Max is 256 bit width, so use four
	// Ram is registered on inputs vis ram_addr, ram_din and ram_wren
	// Output is unregistered, OLD data on write (less delay than NEW??)
	
	`ifdef HALFRAM
		parameter ADDRBITS = 9;
	`else
		parameter ADDRBITS = 10;
	`endif

	wire [ADDRBITS-1:0]ram_addr;
	wire [255:0]ram1_din;
	wire [255:0]ram1_dout;
	wire [255:0]ram2_din;
	wire [255:0]ram2_dout;
	wire [255:0]ram3_din;
	wire [255:0]ram3_dout;
	wire [255:0]ram4_din;
	wire [255:0]ram4_dout;
	wire [1023:0]ramout;

	reg ram_wren = 1'b0;
	wire ram_clk;
	assign ram_clk = hash_clk;	// Uses same clock as hasher for now
	
	`ifdef HALFRAM
		// This is the half scratchpad version
		// Top ram address is reserved for X0Save/X1save, so adjust
		wire [8:0] adj_addr = (Xmix[9:1] == 9'h1ff) ? 9'h1fe : Xmix[9:1];
		assign ram_addr = addrsourceMix ? (addrsourceSave ? 9'h1ff : adj_addr) : writeaddr[9:1];	// LSB is ignored
	`else
		// This is the full scratchpad version
		assign ram_addr = addrsourceMix ? Xmix[9:0] : writeaddr;
	`endif
	ram # (.ADDRBITS(ADDRBITS)) ram1_blk (ram_addr, ram_clk, ram1_din, ram_wren, ram1_dout);
	ram # (.ADDRBITS(ADDRBITS)) ram2_blk (ram_addr, ram_clk, ram2_din, ram_wren, ram2_dout);
	ram # (.ADDRBITS(ADDRBITS)) ram3_blk (ram_addr, ram_clk, ram3_din, ram_wren, ram3_dout);
	ram # (.ADDRBITS(ADDRBITS)) ram4_blk (ram_addr, ram_clk, ram4_din, ram_wren, ram4_dout);
	assign ramout = { ram4_dout, ram3_dout, ram2_dout, ram1_dout };	// Unregistered output
	assign { ram4_din, ram3_din, ram2_din, ram1_din } = { X1, X0} ;	// Registered input

	// Salsa unit
	
	salsa salsa_blk (hash_clk, mixfeedback, X0, X1, Xmix);

	// Main multiplexer
	wire [511:0] Zbits;
	assign Zbits = {512{xoren}};		// xoren enables xor from ram (else we load from ram)
	
	// With luck the synthesizer will interpret this correctly as one-hot control (TODO use explicit signal bits eg Xctl[0] for XSload)
	assign X0in = (XCtl==XSmix) ? X1 : (XCtl==XSram) ? (X0 & Zbits) ^ ramout[511:0] : (XCtl==XSload) ? X[511:0] : X0;
	assign X1in = (XCtl==XSmix) ? Xmix : (XCtl==XSram) ? (X1 & Zbits) ^ ramout[1023:512] : (XCtl==XSload) ? X[1023:512] : X1;
	
	// Salsa FSM - TODO may want to move this into a separate function (for floorplanning), see hashvariant-C
	
	always @ (posedge hash_clk)
	begin
		X0 <= X0in;
		X1 <= X1in;
		
		XCtl <= XSnull;				// Default states
		addrsourceSave <= 0;
		ram_wren <= 0;
		xoren <= 1;
		
		if (shift)
			salsaShiftReg <= { salsaShiftReg[1022:0], din };
		
		if (reset == 1'b1)
		begin
			mstate <= R_IDLE;
			result <= 1'b0;			// Needed else we won't load first input data
		end
		else
		begin
			case (mstate)
				R_IDLE: begin
					writeaddr <= 0;
					mcount <= 0;
					mixfeedback <= 1'b0;
					addrsourceMix <= 1'b0;
					if (start)
					begin
						if (~result)
							XCtl <= XSload;		// First time only (normally done at end of previous salsa cycle=1023)
						doneROM <= 1'b0;
						busy <= 1'b1;
						result <= 1'b0;
						mstate <= R_START;
					end
				end
				R_START: begin
						ram_wren <= 1'b1;		// Initial write cycle
						mstate <= R_WRITE;
					end
				R_WRITE: begin
					mcount <= mcount + 6'd1;
					// 8 stages since salsa takes 4 clock cycles. NB This minimises clock cycles, but adds to
					// the propagation delay in the salsa. The alternative of adding a cycle or two of latency to
					// reduce propagation delay is SLOWER due to the extra clocks needed.
					// Write to ROM every 2nd cycle (NB we are writing previous data here)
					// NB One extra cycle is performed after ROM is complete to update X0,X1 to inital state for R_MIX
					if (mcount==0)
					begin
						mixfeedback <= 1'b1;
						if (writeaddr==1023)
							doneROM <= 1'b1;			// Need to do one more cycle to update X0,X1
						writeaddr <= writeaddr + 10'd1;
					end
					if (mcount==4)
						mixfeedback <= 1'b1;
					if (mcount == 2 || mcount == 6)
						XCtl <= XSmix;							
					if (mcount == 3 || mcount == 7)
						mixfeedback <= 1'b0;
					if (mcount == 6 && doneROM)			// Preset the address source one cycle early
						addrsourceMix <= 1'b1;			// Remains set for duration of R_MIX
					if (mcount == 7)
					begin
						mcount <= 0;
						if (doneROM)
						begin
							cycle <= 0;
							mstate <= R_MIX;
							XCtl <= XSram;				// Load from ram next cycle
							`ifdef HALFRAM
							// Need this to cover the case of the initial read being interpolated
							intcycles <= { 1'b0, Xmix[0] };		// Flag odd addresses (for use in next cycle due to ram latency)
							if ( Xmix[9:1] == 9'h1ff )			// Highest ram address is reserved for X0save, so
								intcycles <= { 1'b1, Xmix[0] };	// need up to 3 interpolations

							if ( (Xmix[9:1] == 9'h1ff) || Xmix[0])
							begin
								addrsourceSave <= 1'b1;			// Setup to save X0/X1 to top location of ram
								ram_wren <= 1'b1;
								xoren <= 0;						// Will do direct load from ram, not xor
							end
							`endif
						end
						else
						begin
							// NB the !doneROM test is superfluous here as its in the else clause of if(doneROM)
							`ifdef HALFRAM
								if (!writeaddr[0])	// Do not write on odd cycles (half scratchpad)
									ram_wren <= 1'b1;			// Since registered we preset this here
							`else
									ram_wren <= 1'b1;
							`endif
						end
					end
				end
				R_MIX: begin
					// Entered with mixfeedback == 0 (set at mcount==7 above)
					// NB There is an extra step here cf R_WRITE above to read ram data hence 9 not 8 stages.
					// The longest chain is from mixfeedback to ram address input (since XMix is not registered),
					// again as noted above, extra register stages would simply reduce throughput.
					mcount <= mcount + 5'd1;
					if (mcount == 0)
					begin
						mixfeedback <= 1'b0;
						`ifdef HALFRAM
							if (intcycles != 0)			// Set in previous cycle
								mstate <= R_INT;	// Interpolate
						`endif
					end
					if (mcount==1 || mcount==5)
						mixfeedback <= 1;
					if (mcount == 3 || mcount == 7)
						XCtl <= XSmix;
					if (mcount == 4 || mcount == 8)
						mixfeedback <= 1'b0;
					if (mcount == 7 && cycle == 1023)
							XCtl <= XSload;			// Initial load is at mcount==8 else we overwrite input
					if (mcount == 8)
					begin
						mcount <= 0;
						cycle <= cycle + 11'd1;
						if (cycle == 1023)
						begin
							// Pipeline the result so we can start processing the next X input
							salsaShiftReg <= { Xmix, X1 };	// Simultaneously do XSload (set at mcount==7)
							// Flag the SHA256 FSM to start final PBKDF2_SHA256_80_128_32
							result <= 1'b1;
							busy <= 1'b0;
							mstate <= R_IDLE;
						end
						else
						begin
							XCtl <= XSram;				// Load from ram next cycle
							`ifdef HALFRAM
							// ALSO do this in final step of R_WRITE
							intcycles <= { 1'b0, Xmix[0] };		// Flag odd addresses (for use in next cycle due to ram latency)
							if ( Xmix[9:1] == 9'h1ff )			// Highest ram address is reserved for X0save, so
								intcycles <= { 1'b1, Xmix[0] };	// need up to 3 interpolations

							if ( (Xmix[9:1] == 9'h1ff) || Xmix[0])
							begin
								addrsourceSave <= 1'b1;			// Setup to save at mcount==0 (also does so entering R_IDLE
								ram_wren <= 1'b1;				// after cycle==1023 but of no consequence)
								xoren <= 0;						// Will do direct load from ram, not xor
							end
							`endif
						end
					end
				end
				`ifdef HALFRAM
				R_INT: begin
					// Interpolate scratchpad for odd addresses
					// Mcount has already been incremented in R_MIX
					mcount <= mcount + 6'd1;
					if (mcount==1 || mcount==5)
						mixfeedback <= 1'b1;
					if (mcount == 3 || mcount == 7)
						XCtl <= XSmix;
					if (mcount == 4 || mcount == 8)
						mixfeedback <= 1'b0;
					if (mcount == 7)
						addrsourceSave <= 1'b1;		// Preset to read saved data at mcount==9
					if (mcount == 8)
					begin
						if (intcycles == 1)
							XCtl <= XSram;			// Setup to XOR from saved X0/X1 in ram at next cycle
					end
					if (mcount == 9)
					begin
						intcycles <= intcycles - 1;
						mcount <= 1;		// Skip 0 since done above
						if (intcycles == 1)
							mstate <= R_MIX;
						// Else mstate remains at R_INT so we continue interpolating from mcount=1
					end
				end
				`endif
			endcase
		end
`ifdef SIM
	// Print the final Xmix for each cycle to compare with scrypt.c (debugging)
	if (mstate == R_MIX && mcount == 8)
		$display ("cycle %d Xmix %08x\n", cycle, Xmix[511:480]);
`endif
	end	// always @(posedge hash_clk)
endmodule