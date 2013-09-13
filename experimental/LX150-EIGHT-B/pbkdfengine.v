/* pbkdfengine.v
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

`define ICARUS			// Comment this out when using the altera virtual_wire interface in ltcminer.v
	
`timescale 1ns/1ps

module pbkdfengine
	(hash_clk, pbkdf_clk, data1, data2, data3, target, nonce_msb, nonce_out, golden_nonce_out, golden_nonce_match, loadnonce,
			salsa_din, salsa_dout, salsa_busy, salsa_result, salsa_reset, salsa_start, salsa_shift);

	input hash_clk;			// Just drives shift register
	input pbkdf_clk;
	input [255:0] data1;
	input [255:0] data2;
	input [127:0] data3;
	input [31:0] target;
	input [3:0] nonce_msb;
	output [31:0] nonce_out;
	output [31:0] golden_nonce_out;
	output golden_nonce_match;	// Strobe valid one cycle on a match (needed for serial comms)
	input loadnonce;			// Strobe loads nonce (used for serial interface)

	input salsa_dout;
	output salsa_din;
	input salsa_busy, salsa_result;	// NB hash_clk domain
	output salsa_reset;
	output salsa_start;
	output reg salsa_shift = 1'b0;	// NB hash_clk domain

	reg [3:0]resetcycles = 4'd0;
	reg reset = 1'b0;
	assign salsa_reset = reset;		// Propagate reset to salsaengine

`ifdef WANTCYCLICRESET		
	reg [23:0]cycresetcount = 24'd0;
`endif

	always @ (posedge pbkdf_clk)
	begin
		// Hard code a 15 cycle reset (NB assumes THREADS=8 in salsaengine, else we need more)
		// NB hash_clk is faster than pbkdf_clk so the salsaengine will actually be initialised well before
		// this period ends, but keep to 15 for now as simulation uses equal pbkdf and salsa clock speeds.
		resetcycles <= resetcycles + 1'd1;
		if (resetcycles == 0)
			reset <= 1'b1;
		if (resetcycles == 15)
		begin
			reset <= 1'b0;
			resetcycles <= 15;
		end
`ifdef WANTCYCLICRESET		
		// Cyclical reset every 2_500_000 clocks to ensure salsa pipeline does not drift out of sync
		// This may be unneccessary if we reset every loadnonce
		// Actually it seems to do more harm than good, so disabled
		cycresetcount <= cycresetcount + 1'd1;
		if (cycresetcount == 2_500_000)	// 10 per second at 25MHz (adjust as neccessary)
		begin
			cycresetcount <= 24'd0;
			resetcycles <= 4'd0;
		end
`endif		
		// Reset on loadnonce (the hash results will be junk anyway since data changes, so no loss of shares)
		if (loadnonce)
			resetcycles <= 4'd0;
	end
	
	`ifndef ICARUS
	reg [31:0] nonce_previous_load = 32'hffffffff;	// See note in salsa mix FSM
	`endif

	`ifndef NOMULTICORE
	`ifdef SIM
		reg [27:0] nonce_cnt = 28'h318f;	// Start point for simulation (NB also define SIM in serial.v)
	`else
		reg [27:0] nonce_cnt = 28'd0;		// Multiple cores use different prefix
	`endif
		wire [31:0] nonce;
		assign nonce = { nonce_msb, nonce_cnt };
	`else
		reg [31:0] nonce = 32'd0;			// NB Initially loaded from data3[127:96], see salsa mix FSM
	`endif

	assign nonce_out = nonce;

	reg [31:0] nonce_sr = 32'd0;		// Nonce is shifted to salsaengine for storage/retrieval (hash_clk domain)
	reg [31:0] golden_nonce = 32'd0;
	assign golden_nonce_out = golden_nonce;
	reg golden_nonce_match = 1'b0;
	reg [2:0] nonce_wait = 3'd0;
	
	reg [255:0] rx_state;
	reg [511:0] rx_input;
	wire [255:0] tx_hash;
	reg [255:0] khash = 256'd0;		// Key hash (NB scrypt.c calls this ihash)
	reg [255:0] ihash = 256'd0;		// IPAD hash
	reg [255:0] ohash = 256'd0;		// OPAD hash
	`ifdef SIM
		reg [255:0] final_hash = 256'd0;	// Just for DEBUG, only need top 32 bits in live code.
	`endif
	reg [2:0] blockcnt = 3'd0;		// Takes values 1..5 for block iteration
	reg [1023:0] Xbuf = 1024'd0;	// Shared input/output buffer and shift register (hash_clk domain)
	reg [5:0] cnt = 6'd0;
	wire feedback;
	assign feedback = (cnt != 6'b0);
	assign salsa_din = Xbuf[1023];
	wire [1023:0] MixOutRewire;		// Need to do endian conversion (see the generate below)
	
	// MixOut is little-endian word format to match scrypt.c so convert back to big-endian

	`define IDX(x) (((x)+1)*(32)-1):((x)*(32))
	genvar i;
	generate
	for (i = 0; i < 32; i = i + 1) begin : Xrewire
		wire [31:0] mix;
		assign mix = Xbuf[`IDX(i)];		// NB MixOut now shares Xbuf since shifted in/out
		assign MixOutRewire[`IDX(i)] = { mix[7:0], mix[15:8], mix[23:16], mix[31:24] };
	end
	endgenerate

	// Interface control. This should be OK provided the threads remain evenly spaced (hence we reset on loadnonce)
	
	reg SMixInRdy_state = 1'b0;		// SMix input ready flag (set in SHA256, reset in SMIX)
	reg SMixOutRdy_state = 1'b0;	// SMix output ready flag (set in SMIX, reset in SHA256)
	wire SMixInRdy;
	wire SMixOutRdy;

	reg Set_SMixInRdy = 1'b0;
	reg Clr_SMixOutRdy = 1'b0;

	reg [3:0]salsa_busy_d;			// Sync to pbkdf_clk domain
	reg [3:0]salsa_result_d;

	wire Clr_SMixInRdy;
	assign Clr_SMixInRdy = SMixInRdy_state & salsa_busy_d[2] & ~salsa_busy_d[3];		// Clear on transition to busy
	
	wire Set_SMixOutRdy;
	assign Set_SMixOutRdy = ~SMixOutRdy_state & salsa_result_d[2] & ~salsa_result_d[3];	// Set on transition to result
	
	// Clock crossing flags for shift register control (span pbkdf_clk, hash_clk domains)
	reg [3:0]Xbuf_load_request = 1'b0;
	reg [3:0]shift_request =  1'b0;
	reg [3:0]shift_acknowledge = 1'b0;
	
	always @ (posedge pbkdf_clk)
	begin
		salsa_busy_d[0] <= salsa_busy;			// Sync to pbkdf_clk domain
		salsa_busy_d[3:1] <= salsa_busy_d[2:0];
		salsa_result_d[0] <= salsa_result;
		salsa_result_d[3:1] <= salsa_result_d[2:0];
		
		if (Set_SMixInRdy)
			SMixInRdy_state <= 1'b1;
		if (Clr_SMixInRdy)
			SMixInRdy_state <= 1'b0;	// Clr overrides set
		if (Set_SMixOutRdy)
			SMixOutRdy_state <= 1'b1;
		if (Clr_SMixOutRdy)
			SMixOutRdy_state <= 1'b0;	// Clr overrides set
			
		// CARE there is a race with Set_SMixInRdy, Clr_SMixOutRdy which are set in the FSM
		// Need to assert reset for several cycles to ensure consistency (acutally use 15 since salsaengine needs more)
		if (reset)
		begin							// Reset takes priority
			SMixInRdy_state <= 1'b0;
			SMixOutRdy_state <= 1'b0;
		end
	end
	
	// Achieves identical timing to original version, but probably overkill
	assign SMixInRdy = Clr_SMixInRdy ? 1'b0 : Set_SMixInRdy ? 1'b1 : SMixInRdy_state;
	assign SMixOutRdy = Clr_SMixOutRdy ? 1'b0 : Set_SMixOutRdy ? 1'b1 : SMixOutRdy_state;
	assign salsa_start = SMixInRdy;
		
	// Controller FSM for PBKDF2_SHA256_80_128 (multiple hashes using the sha256_transform)
	// Based on scrypt.c from cgminer (Colin Percival, ArtForz)
		
	parameter	S_IDLE=0,
				S_H1= 1, S_H2= 2, S_H3= 3, S_H4= 4, S_H5= 5, S_H6= 6,	// Initial hash of block header (khash)
				S_I1= 7, S_I2= 8, S_I3= 9, S_I4=10, S_I5=11, S_I6=12,	// IPAD hash (ihash)
				S_O1=13, S_O2=14, S_O3=15,								// OPAD hash (ohash)
				S_B1=16, S_B2=17, S_B3=18, S_B4=19, S_B5=20, S_B6=21,	// Iterate blocks
				S_NONCE=22, S_SHIFT_IN=41, S_SHIFT_OUT=42,				// Direction relative to salsa unit
				// Final PBKDF2_SHA256_80_128_32 (reuses S_H1 to S_H6 for khash, alternatively could piplenine value)
				S_R1=23, S_R2=24, S_R3=25, S_R4=26, S_R5=27, S_R6=28,	// Final PBKDF2_SHA256_80_128_32
				S_R7=29, S_R8=30, S_R9=31, S_R10=32, S_R11=33, S_R12=34,
				S_R13=35, S_R14=36, S_R15=37, S_R16=38, S_R17=39, S_R18=40;
				
	reg [5:0] state = S_IDLE;
	reg mode = 0;	// 0=PBKDF2_SHA256_80_128, 1=PBKDF2_SHA256_80_128_32
	reg start_output = 0;

	always @ (posedge pbkdf_clk)
	begin
		Set_SMixInRdy <= 1'b0;	// Ugly hack, these are overriden below
		Clr_SMixOutRdy <= 1'b0;
		golden_nonce_match <= 1'b0;	// Default to reset

		shift_acknowledge[3:1] <= shift_acknowledge[2:0];	// Clock crossing

		`ifdef ICARUS
		if (loadnonce)				// Separate clock domains means comparison is unsafe
		`else
		if (loadnonce || (nonce_previous_load != data3[127:96]))
		`endif
		begin
			`ifdef NOMULTICORE
				nonce <= data3[127:96];	// Supports loading of initial nonce for test purposes (potentially
										// overriden by the increment below, but this occurs very rarely)
										// This also gives a consistent start point when we send the first work
										// packet (but ONLY the first one since its always zero) when using live data
										// as we initialise nonce_previous_load to ffffffff
			`else
				nonce_cnt <= data3[123:96];	// The 4 msb of nonce are hardwired in MULTICORE mode, so test nonce
											// needs to be <= 0fffffff and will only match in the 0 core
			`endif
			`ifndef ICARUS
			nonce_previous_load <= data3[127:96];
			`endif
		end
		
		if (reset == 1'b1)
		begin
			state <= S_IDLE;
			start_output <= 1'b0;
		end
		else
		begin
			case (state)
				S_IDLE: begin
					if (SMixOutRdy & ~start_output)
					begin
						shift_request[0] <= ~shift_request[0];	// Request shifter to start
						state <= S_SHIFT_OUT;
					end
					else
					begin
						if (start_output ||	// Process output
							!SMixInRdy)		// Process input unless already done
						begin
							start_output <= 1'b0;
							mode <= 1'b0;
							// Both cases use same initial calculaton of khash (its not worth trying to reuse previous khash
							// for the second case as we're not constrained by SHA256 timing)
							rx_state <= 256'h5be0cd191f83d9ab9b05688c510e527fa54ff53a3c6ef372bb67ae856a09e667;
							rx_input <= { data2, data1 };	// Block header is passwd (used as key)
							blockcnt <= 3'd1;
							cnt <= 6'd0;
							if (SMixOutRdy)					// Give preference to output
								mode <= 1'b1;
							state <= S_H1;
						end
					end
				end

				// Hash the block header (result is khash)
				S_H1: begin	// Waiting for result
					cnt <= cnt + 6'd1;
					if (cnt == 6'd63)
					begin
						cnt <= 6'd0;
						state <= S_H2;
					end
				end
				S_H2: begin	// Sync hash
						state <= S_H3;
				end
				S_H3: begin	// Sync hash
						rx_state <= tx_hash;
						// Hash last 16 bytes of header including nonce and padded to 64 bytes with 1, zeros and length
						// NB this sequence is used for both input and final PBKDF2_SHA256, hence switch nonce on mode
						rx_input <= { 384'h000002800000000000000000000000000000000000000000000000000000000000000000000000000000000080000000,
										mode ? nonce_sr : nonce, data3[95:0] };
						state <= S_H4;
				end
				S_H4: begin	// Waiting for result
					cnt <= cnt + 6'd1;
					if (cnt == 6'd63)
					begin
						cnt <= 6'd0;
						state <= S_H5;
					end
				end
				S_H5: begin	// Sync hash
						state <= S_H6;
				end
				S_H6: begin	// Sync hash
						khash <= tx_hash;	// Save for OPAD hash
						// Setup for IPAD hash
						rx_state <= 256'h5be0cd191f83d9ab9b05688c510e527fa54ff53a3c6ef372bb67ae856a09e667;
						rx_input <= { 256'h3636363636363636363636363636363636363636363636363636363636363636 ,
										tx_hash ^ 256'h3636363636363636363636363636363636363636363636363636363636363636 };
						cnt <= 6'd0;
						if (mode)
							state <= S_R1;
						else
							state <= S_I1;
				end

				// IPAD hash
				S_I1: begin	// Waiting for result
					cnt <= cnt + 6'd1;
					if (cnt == 6'd63)
					begin
						cnt <= 6'd0;
						state <= S_I2;
					end
				end
				S_I2: begin	// Sync hash
						state <= S_I3;
				end
				S_I3: begin	// Sync hash
						rx_state <= tx_hash;
						rx_input <= { data2, data1 };	// Passwd (used as message)
						state <= S_I4;
				end
				S_I4: begin	// Waiting for result
					cnt <= cnt + 6'd1;
					if (cnt == 6'd63)
					begin
						cnt <= 6'd0;
						state <= S_I5;
					end
				end
				S_I5: begin	// Sync hash
						state <= S_I6;
				end
				S_I6: begin	// Sync hash
						ihash <= tx_hash;				// Save result
						// Setup for OPAD hash
						rx_state <= 256'h5be0cd191f83d9ab9b05688c510e527fa54ff53a3c6ef372bb67ae856a09e667;
						rx_input <= { 256'h5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c ,
										khash ^ 256'h5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c };
						cnt <= 6'd0;
						state <= S_O1;
				end

				// OPAD hash
				S_O1: begin	// Waiting for result
					cnt <= cnt + 6'd1;
					if (cnt == 6'd63)
					begin
						cnt <= 6'd0;
						state <= S_O2;
					end
				end
				S_O2: begin	// Sync hash
						state <= S_O3;
				end
				S_O3: begin	// Sync hash
						ohash <= tx_hash;				// Save result
						// Setup for block iteration
						rx_state <= ihash;
						// TODO hardwire top 29 bits of blockcnt as zero
						rx_input <= { 352'h000004a000000000000000000000000000000000000000000000000000000000000000000000000080000000,
										29'd0, blockcnt, nonce, data3[95:0] }; // blockcnt is 3 bits, top 29 are hardcoded 0
						blockcnt <= blockcnt + 1'd1;		// Increment for next time
						cnt <= 6'd0;
						state <= S_B1;
				end

				// Block iteration (4 cycles)
				S_B1: begin	// Waiting for result
					cnt <= cnt + 6'd1;
					if (cnt == 6'd63)
					begin
						cnt <= 6'd0;
						state <= S_B2;
					end
				end
				S_B2: begin	// Sync hash
						state <= S_B3;
				end
				S_B3: begin	// Sync hash
						rx_state <= ohash;
						rx_input <= { 256'h0000030000000000000000000000000000000000000000000000000080000000, tx_hash };
						state <= S_B4;
				end
				S_B4: begin	// Waiting for result
					cnt <= cnt + 6'd1;
					if (cnt == 6'd63)
					begin
						cnt <= 6'd0;
						state <= S_B5;
					end
				end
				S_B5: begin	// Sync hash
						state <= S_B6;
				end		
				S_B6: begin
						khash <= tx_hash;		// Save temporarily (for Xbuf)

						Xbuf_load_request[0] <= ~Xbuf_load_request[0];	// NB also loads nonce_sr

						if (blockcnt == 3'd5)
						begin
							nonce_wait <= 3'd7;
							state <= S_NONCE;
						end
						else begin
							// Setup for next block
							rx_state <= ihash;
							rx_input <= { 352'h000004a000000000000000000000000000000000000000000000000000000000000000000000000080000000,
											29'd0, blockcnt, nonce, data3[95:0] }; // blockcnt is 3 bits, top 29 are hardcoded 0
							blockcnt <= blockcnt + 1'd1;		// Increment for next time
							cnt <= 6'd0;
							state <= S_B1;
						end
				end
				S_NONCE: begin
						// Need to delay a few clocks for Xbuf_load_request to complete
						nonce_wait <= nonce_wait - 1'd1;
						if (nonce_wait == 0)
						begin
							`ifndef NOMULTICORE
								nonce_cnt <= nonce_cnt + 1'd1;
							`else
								nonce <= nonce + 1'd1;
							`endif
							shift_request[0] <= ~shift_request[0];
							state <= S_SHIFT_IN;
						end
				
				end
				S_SHIFT_IN: begin							// Shifting from PBKDF2_SHA256 to salsa
						if (shift_acknowledge[3] != shift_acknowledge[2])
						begin
							Set_SMixInRdy <= 1'd1;				// Flag salsa to start
							state <= S_IDLE;
						end
				end
				S_SHIFT_OUT: begin							// Shifting from salsa to PBKDF2_SHA256
						if (shift_acknowledge[3] != shift_acknowledge[2])
						begin
							start_output <= 1'd1;				// Flag self to start
							state <= S_IDLE;
						end
				end
				// Final PBKDF2_SHA256_80_128_32 NB Entered from S_H6 via mode flag
				// Similar to S_I0 but using MixOut as salt and finalblk padding
				S_R1: begin	// Waiting for result
					cnt <= cnt + 6'd1;
					if (cnt == 6'd63)
					begin
						cnt <= 6'd0;
						state <= S_R2;
					end
				end
				S_R2: begin	// Sync hash
						state <= S_R3;
				end
				S_R3: begin	// Sync hash
						rx_state <= tx_hash;
						rx_input <= MixOutRewire[511:0];		// Salt (first block)
						state <= S_R4;
				end
				S_R4: begin	// Waiting for result
					cnt <= cnt + 6'd1;
					if (cnt == 6'd63)
					begin
						cnt <= 6'd0;
						state <= S_R5;
					end
				end
				S_R5: begin	// Sync hash
						state <= S_R6;
				end
				S_R6: begin	// Sync hash
						rx_state <= tx_hash;
						rx_input <= MixOutRewire[1023:512];		// Salt (second block)
						state <= S_R7;
				end
				S_R7: begin	// Waiting for result
					cnt <= cnt + 6'd1;
					if (cnt == 6'd63)
					begin
						cnt <= 6'd0;
						state <= S_R8;
					end
				end
				S_R8: begin	// Sync hash
						state <= S_R9;
				end
				S_R9: begin	// Sync hash
						rx_state <= tx_hash;
						// Final padding
						rx_input <= 512'h00000620000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000001;
						state <= S_R10;
				end
				S_R10: begin	// Waiting for result
					cnt <= cnt + 6'd1;
					if (cnt == 6'd63)
					begin
						cnt <= 6'd0;
						state <= S_R11;
					end
				end
				S_R11: begin	// Sync hash
						state <= S_R12;
				end
				S_R12: begin	// Sync hash
						ihash <= tx_hash;				// Save (reuse ihash)
						// Setup for OPAD hash
						rx_state <= 256'h5be0cd191f83d9ab9b05688c510e527fa54ff53a3c6ef372bb67ae856a09e667;
						rx_input <= { 256'h5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c ,
										khash ^ 256'h5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c };
						cnt <= 6'd0;
						state <= S_R13;
				end
				S_R13: begin	// Waiting for result
					cnt <= cnt + 6'd1;
					if (cnt == 6'd63)
					begin
						cnt <= 6'd0;
						state <= S_R14;
					end
				end
				S_R14: begin	// Sync hash
						state <= S_R15;
				end
				S_R15: begin	// Sync hash
						rx_state <= tx_hash;
						rx_input <= { 256'h0000030000000000000000000000000000000000000000000000000080000000, ihash };
						state <= S_R16;
				end
				S_R16: begin	// Waiting for result
					cnt <= cnt + 6'd1;
					if (cnt == 6'd63)
					begin
						cnt <= 6'd0;
						state <= S_R17;
					end
				end
				S_R17: begin	// Sync hash
						state <= S_R18;
				end
				S_R18: begin	// Sync hash
						// Check for golden nonce in tx_hash
						`ifdef SIM
							final_hash <= tx_hash;		// For debug
						`endif
						// Could optimise target calc ...
						if ( { tx_hash[231:224], tx_hash[239:232], tx_hash[247:240], tx_hash[255:248] } < target)
						begin
							golden_nonce <= nonce_sr;
							golden_nonce_match <= 1'b1;	// Set flag (for one cycle only, see default at top)
						end
						state <= S_IDLE;
						mode <= 1'b0;
						// SMixOutRdy <= 1'b0;	// Original version
						Clr_SMixOutRdy <= 1'b1;	// Ugly hack
				end
			endcase	
		end
	end

	// Shift register control - NB hash_clk domain
	
	reg	[10:0]shift_count = 11'd0;	// hash_clk domain
	
	always @ (posedge hash_clk)
	begin
		if (reset)
		begin
			salsa_shift <= 1'b0;
			shift_count <= 11'd0;
		end

		// Clock crossing logic
		Xbuf_load_request[3:1] <= Xbuf_load_request[2:0];
		if (Xbuf_load_request[3] != Xbuf_load_request[2])
		begin
			// Shift output into X buffer from MSB->LSB
			Xbuf[255:0] <= Xbuf[511:256];
			Xbuf[511:256] <= Xbuf[767:512];
			Xbuf[767:512] <= Xbuf[1023:768];
			Xbuf[1023:768] <= khash;

			nonce_sr <= nonce;	// Loaded several times, but of no consequence
		end
		
		shift_request[3:1] <= shift_request[2:0];
		if (shift_request[3] != shift_request[2])
		begin
			salsa_shift <= 1'b1;
		end

		if (salsa_shift)
		begin
			shift_count <= shift_count + 1'b1;
			Xbuf <= { Xbuf[1022:0], nonce_sr[31] };
			nonce_sr <= { nonce_sr[30:0], salsa_dout };
		end
		
		if (shift_count == 1024+32-1)
		begin
			shift_acknowledge[0] = ~shift_acknowledge[0];
			shift_count <= 0;
			salsa_shift <= 0;
		end
	end

	// Using LOOP=64 to simplify timing (needs slightly modified version of original sha256_transform.v)
	// since pipelining is inappropriate for ltc (we need to rehash same data several times in succession)
	sha256_transform  # (.LOOP(64)) sha256_blk (
		.clk(pbkdf_clk),
		.feedback(feedback),
		.cnt(cnt),
		.rx_state(rx_state),
		.rx_input(rx_input),
		.tx_hash(tx_hash)
	);

endmodule