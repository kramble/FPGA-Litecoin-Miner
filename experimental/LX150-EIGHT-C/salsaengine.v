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

// NB HALFRAM no longer applies, configure via parameters ADDRBITS, THREADS

// Bracket this config option in SIM so we don't accidentally leave it set in a live build
`ifdef SIM
`define ONETHREAD	// Start one thread only (for SIMULATION less confusing and faster startup)
`endif

`timescale 1ns/1ps

module salsaengine (hash_clk, reset, din, dout, shift, start, busy, result );

	input hash_clk;
	input reset;	// NB pbkdf_clk domain (need a long reset (at least THREADS+4) to initialize correctly, this is done in pbkdfengine (15 cycles)
	input din;
	input shift;
	input start;	// NB pbkdf_clk domain
	output busy;
	output reg result = 1'b0;
	output dout;
	
	// Configure ADDRBITS to allocate RAM for core (automatically sets LOOKAHEAD_GAP)
	// NB do not use ADDRBITS > 13 for THREADS=8 since this corresponds to more than a full scratchpad

	// These settings are now overriden in ltcminer_icarus.v determined by LOCAL_MINERS ...
	// parameter ADDRBITS = 13;	// 8MBit RAM allocated to core, full scratchpad (will not fit LX150)
	parameter ADDRBITS = 12;	// 4MBit RAM allocated to core, half scratchpad
	// parameter ADDRBITS = 11;	// 2MBit RAM allocated to core, quarter scratchpad
	// parameter ADDRBITS = 10;	// 1MBit RAM allocated to core, eighth scratchpad

	// Do not change THREADS - this must match the salsa pipeline (code is untested for other values)
	parameter THREADS = 8;		// NB Phase has THREADS+1 cycles

	function integer clog2;		// Courtesy of razorfishsl, replaces $clog2()
		input integer value;
		begin
		value = value-1;
		for (clog2=0; value>0; clog2=clog2+1)
		value = value>>1;
		end
	endfunction

	parameter THREADS_BITS = clog2(THREADS);
	
	// Workaround for range-reversal error in inactive code when ADDRBITS=13
	parameter ADDRBITSX = (ADDRBITS == 13) ? ADDRBITS-1 : ADDRBITS;

	reg [THREADS_BITS:0]phase = 0;
	reg [THREADS_BITS:0]phase_d = THREADS+1;
	reg reset_d=0, fsmreset=0, start_d=0, fsmstart=0;

	always @ (posedge hash_clk)		// Phase control and sync
	begin
		phase <= (phase == THREADS+1) ? 0 : phase + 1;
		phase_d <= phase;
		reset_d <= reset;			// Synchronise to hash_clk domain
		fsmreset <= reset_d;
		start_d <= start;
		fsmstart <= start_d;
	end

	// Salsa Mix FSM (handles both loading of the scratchpad ROM and the subsequent processing)

	parameter XSnull = 0, XSload = 1, XSmix = 2, XSram = 4;			// One-hot since these map directly to mux contrls
	reg [2:0] XCtl = XSnull;

	parameter R_IDLE=0, R_START=1, R_WRITE=2, R_MIX=4, R_INT=8;		// Try explicit one-hot [HMMM synthesyzer changes to this gray]
	reg [3:0] mstate = R_IDLE;
	reg [10:0] cycle = 11'd0;
	reg [5:0] mcount = 5'd0;	// Salsa latency
	reg doneROM = 1'd0;			// Yes ROM, as its referred thus in the salsa docs
	reg mixfeedback = 1'b0;
	reg mixfeedback_d = 1'b0;	// Fudge
	reg mixfeedback_d2 = 1'b0;	// Fudge
	reg addrsourceMix = 1'b0;
	reg addrsourceMix_d = 1'b0;
	reg addrsourceMix_d2 = 1'b0;
	reg addrsourceSave = 1'b0;
	reg mixspecial = 1'b0;
	reg xoren = 1'b1;
	reg [THREADS_BITS+1:0] intcycles = 0;	// Number of interpolation cycles required ... How many do we need? Say THREADS_BITS+1

	wire [511:0] Xmix;
	reg [511:0] X0;
	reg [511:0] X1;
	reg [511:0] X0_d;
	reg [511:0] X1_d;
	wire [511:0] X0in;
	wire [511:0] X1in;
	wire [511:0] X0out;
	wire [511:0] X1out;
	reg [1023:0] salsaShiftReg;
	reg [31:0] nonce_sr;			// In series with salsaShiftReg
	assign dout = salsaShiftReg[1023];

	reg [511:0] Xmix_d;
	reg [511:0] X1out_d;
	reg [511:0] Xmix_d2;
	reg [511:0] X1out_d2;

	// sstate is implemented in block ram
	reg [THREADS_BITS+38:0] sstate [THREADS-1:0];		// NB initialized via a long reset (see pbkdfengine)
	wire [3:0] mstate_in;
	wire [10:0] cycle_in;
	wire [5:0] mcount_in;
	wire [9:0] writeaddr_in;
	wire doneROM_in;
	wire mixfeedback_in;
	wire addrsourceMix_in;
	wire addrsourceSave_in;
	wire mixspecial_in;
	wire [THREADS_BITS+1:0] intcycles_in;				// How many do we need? Say THREADS_BITS+1

	reg [31:0] snonce [THREADS-1:0];					// Nonce store. Note bidirectional loading below, this will either implement
														// as registers or dual-port ram, so do NOT integrate with sstate.
	
	// NB no busy_in or result_in as these flag are NOT saved on a per-thread basis

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

	// NB writeaddr is cycle counter in R_WRITE so use full size regardless of RAM size
	(* S = "TRUE" *) reg [9:0] writeaddr = 10'd0;

	// TODO Delayed writeaddr adjusted for ADDRBITS (need to move the bit slicing from wr_addr assignment)
	// reg [ADDRBITS-THREADS_BITS:0] writeaddr_d1 = 0;

	(* S = "TRUE" *) reg [9:0] writeaddr_d1 = 10'd0;
	(* S = "TRUE" *) reg [9:0] writeaddr_d2 = 10'd0;
	(* S = "TRUE" *) reg [9:0] writeaddr_d3 = 10'd0;
	(* S = "TRUE" *) reg [9:0] writeaddr_d4 = 10'd0;
	
	// ALTRAM Max is 256 bit width, so use four
	// Ram is registered on inputs vis ram_addr, ram_din and ram_wren
	// Output is unregistered, OLD data on write (less delay than NEW??)
	
	wire [9:0] Xaddr;
	(* S = "TRUE" *) reg [9:0] Xaddr_d;	// Perhaps use Xmix directly
	wire [ADDRBITS-1:0]rd_addr;
	wire [ADDRBITS-1:0]wr_addr1;
	wire [ADDRBITS-1:0]wr_addr2;
	wire [ADDRBITS-1:0]wr_addr3;
	wire [ADDRBITS-1:0]wr_addr4;
	/*
	reg [ADDRBITS-1:0]wr_addr1_d;
	reg [ADDRBITS-1:0]wr_addr2_d;
	reg [ADDRBITS-1:0]wr_addr3_d;
	reg [ADDRBITS-1:0]wr_addr4_d;
	*/

	wire [255:0]ram1_din;
	wire [255:0]ram1_dout;
	wire [255:0]ram2_din;
	wire [255:0]ram2_dout;
	wire [255:0]ram3_din;
	wire [255:0]ram3_dout;
	wire [255:0]ram4_din;
	wire [255:0]ram4_dout;
	wire [1023:0]ramout;

	(* S = "TRUE" *) reg ram_wren = 1'b0;
	(* S = "TRUE" *) reg ram_wren_d = 1'b0;
	(* S = "TRUE" *) reg ram_wren_d2 = 1'b0;
	wire ram_clk;
	assign ram_clk = hash_clk;	// Uses same clock as hasher for now
	
	// Top ram address is reserved for X0Save/X1save, so adjust
	
	wire [15:0] memtop = 16'hfffe;	// One less than the top memory location (per THREAD bank)
	
	wire [ADDRBITS-THREADS_BITS-1:0] adj_addr;
	(* S = "TRUE" *) reg [ADDRBITS-THREADS_BITS-1:0] adj_addr_d;

	if (ADDRBITS < 13)
		assign adj_addr = (Xaddr[9:13-ADDRBITS] == memtop[9:13-ADDRBITS]) ?
							memtop[ADDRBITS-THREADS_BITS-1:0] : Xaddr[9:13-ADDRBITS];
	else
		assign adj_addr = Xaddr;
	
	wire [THREADS_BITS-1:0] phase_addr;
	(* S = "TRUE" *) reg [THREADS_BITS-1:0] phase_addr_d1;
	(* S = "TRUE" *) reg [THREADS_BITS-1:0] phase_addr_d2;
	(* S = "TRUE" *) reg [THREADS_BITS-1:0] phase_addr_d3;
	(* S = "TRUE" *) reg [THREADS_BITS-1:0] phase_addr_d4;
	
	assign phase_addr = phase[THREADS_BITS-1:0];
	// TODO remove the +1 and just derive wr_addr from phase instead of phase_d2 ?? Maybe this won't work so adj it instead)
	assign rd_addr = { phase_addr+1, addrsourceSave_in ? memtop[ADDRBITS-THREADS_BITS:1] : adj_addr_d };	// LSB are ignored
	
	assign wr_addr1 = { phase_addr_d1, writeaddr_d1[9:13-ADDRBITS] };
	assign wr_addr2 = { phase_addr_d2, writeaddr_d2[9:13-ADDRBITS] };
	assign wr_addr3 = { phase_addr_d3, writeaddr_d3[9:13-ADDRBITS] };
	assign wr_addr4 = { phase_addr_d4, writeaddr_d4[9:13-ADDRBITS] };

	// Duplicate address to reduce fanout (its a ridiculous kludge, but seems to be the approved method)
	
	(* S = "TRUE" *) reg [ADDRBITS-1:0] rd_addr_z_1 = 0;
	(* S = "TRUE" *) reg [ADDRBITS-1:0] rd_addr_z_2 = 0;
	(* S = "TRUE" *) reg [ADDRBITS-1:0] rd_addr_z_3 = 0;
	(* S = "TRUE" *) reg [ADDRBITS-1:0] rd_addr_z_4 = 0;
	(* S = "TRUE" *) wire [ADDRBITS-1:0] rd_addr1 = rd_addr | rd_addr_z_1;
	(* S = "TRUE" *) wire [ADDRBITS-1:0] rd_addr2 = rd_addr | rd_addr_z_2;
	(* S = "TRUE" *) wire [ADDRBITS-1:0] rd_addr3 = rd_addr | rd_addr_z_3;
	(* S = "TRUE" *) wire [ADDRBITS-1:0] rd_addr4 = rd_addr | rd_addr_z_4;
	
	// NB wr_addr is now further registered inside ram
	ram # (.ADDRBITS(ADDRBITS)) ram1_blk (rd_addr1, wr_addr1, ram_clk, ram1_din, ram_wren_d2, ram1_dout);
	ram # (.ADDRBITS(ADDRBITS)) ram2_blk (rd_addr2, wr_addr2, ram_clk, ram2_din, ram_wren_d2, ram2_dout);
	ram # (.ADDRBITS(ADDRBITS)) ram3_blk (rd_addr3, wr_addr3, ram_clk, ram3_din, ram_wren_d2, ram3_dout);
	ram # (.ADDRBITS(ADDRBITS)) ram4_blk (rd_addr4, wr_addr4, ram_clk, ram4_din, ram_wren_d2, ram4_dout);
	assign ramout = { ram4_dout, ram3_dout, ram2_dout, ram1_dout };	// Unregistered output
	assign { ram4_din, ram3_din, ram2_din, ram1_din } = addrsourceMix_d2 ? { Xmix_d2, X1out_d2} : { X1_d, X0_d} ;	// Registered input

	// Salsa unit
	
	salsa salsa_blk (hash_clk, mixfeedback_d, X0, X1, Xmix, X0out, X1out, Xaddr);

	// Main multiplexer
	wire [511:0] Zbits;
	assign Zbits = {512{xoren}};		// xoren enables xor from ram (else we load from ram)
	
	// With luck the synthesizer will interpret this correctly as one-hot control (TODO use explicit signal bits eg Xctl[0] for XSload)
	assign X0in = (XCtl==XSmix) ? X1out : (XCtl==XSram) ? ((mixspecial ? X1out : X0out) & Zbits) ^ ramout[511:0] : (XCtl==XSload) ? X[511:0] : X0out;
	assign X1in = (XCtl==XSmix) ? Xmix : (XCtl==XSram) ? ((mixspecial ? Xmix : X1out) & Zbits) ^ ramout[1023:512] : (XCtl==XSload) ? X[1023:512] : X1out;
	
	// Salsa FSM - TODO may want to move this into a separate function (for floorplanning), see hashvariant-C

	// Hold separate state for each thread (a bit of a kludge to avoid rewriting FSM from scratch)
	// NB must ensure shift and result do NOT overlap by carefully controlling timing of start signal
	// NB Phase has THREADS+1 cycles, but we do not save the state for (phase==THREADS) as it is never active

	assign { mstate_in, mcount_in, writeaddr_in, cycle_in, doneROM_in, mixfeedback_in, addrsourceMix_in, addrsourceSave_in, mixspecial_in,  intcycles_in} = (phase == THREADS || phase == THREADS+1) ? 0 : sstate[phase];
	
	// Interface FSM ensures threads start evenly (required for correct salsa FSM operation)

	reg busy_flag = 1'b0;
	
`ifdef ONETHREAD
	// TEST CONTROLLER ... just allow a single thread to run (busy is currently a common flag)
	// NB the thread automatically restarts after it completes, so its a slight misnomer to say it starts once.
	reg start_once = 1'b0;
	wire start_flag;
	assign start_flag = fsmstart & ~start_once;
	assign busy = busy_flag;		// Ack to pbkdfengine
`else
	// NB start_flag only has effect when a thread is at R_IDLE, ie after reset, normally a thread will automatically
	// restart on completion. We need to spread the R_IDLE starts evenly to ensure proper ooperation. NB the pbkdf
	// engine requires busy and result, but this  looks alter itself in the salsa FSM, even though these are global
	// flags. Reset periodically (on loadnonce in pbkdfengine) to ensure it stays in sync.
	reg [15:0] start_count = 0;
	// TODO automatic configuration based on THREADS (currently assumes 8)
	// Each lookup_gap=2 salsa takes on average 9 * (8 * 1024 + 8 * (1024*1.5)) = 184320 clocks
	// so start 8 threads at 184320 / 8 = 23040 clock intervals
	// For lookup_gap=4 use 1024*(4+3+2+1)/4 and for lookup_gap=8 use 1024*(8+..+1)/8 ie 1024*4.5
	parameter START_INTERVAL = ((ADDRBITS == 12) ? 184320 : (ADDRBITS == 11) ? 258048 : 405504)	/ THREADS;
	reg start_flag = 1'b0;
	assign busy = busy_flag;		// Ack to pbkdfengine - this will toggle on transtion through R_START
`endif

	always @ (posedge hash_clk)
	begin
		X0 <= X0in;
		X1 <= X1in;
		X1_d <= X1;
		X0_d <= X0;
		
		adj_addr_d <= adj_addr;

		if (phase_d != THREADS && phase_d != THREADS+1)
			sstate[phase_d] <= fsmreset ? 0 : { mstate, mcount, writeaddr, cycle, doneROM, mixfeedback, addrsourceMix,
												addrsourceSave, mixspecial, intcycles };
		mstate <= mstate_in;		// Set defaults (overridden below as necessary)
		mcount <= mcount_in;
		writeaddr <= writeaddr_in;
		cycle <= cycle_in;
		intcycles <= intcycles_in;
		doneROM <= doneROM_in;
		mixfeedback <= mixfeedback_in;
		addrsourceMix <= addrsourceMix_in;
		addrsourceSave <= addrsourceSave_in;
		mixspecial <= mixspecial_in;
		
		mixfeedback_d <= mixfeedback;	// Fudge
		mixfeedback_d2 <= mixfeedback_d;	// Fudge
		addrsourceMix_d <= addrsourceMix;
		addrsourceMix_d2 <= addrsourceMix_d;
		ram_wren_d <= ram_wren;
		ram_wren_d2 <= ram_wren_d;

		// TODO move the address slicing from wr_addr to here
		writeaddr_d1 <= addrsourceMix ? memtop[10:1] : writeaddr;
		writeaddr_d2 <= addrsourceMix ? memtop[10:1] : writeaddr;
		writeaddr_d3 <= addrsourceMix ? memtop[10:1] : writeaddr;
		writeaddr_d4 <= addrsourceMix ? memtop[10:1] : writeaddr;

		// Now INSIDE ram
		//wr_addr1_d <= wr_addr1;
		//wr_addr2_d <= wr_addr2;
		//wr_addr3_d <= wr_addr3;
		//wr_addr4_d <= wr_addr4;

		phase_addr_d1 <= phase;
		phase_addr_d2 <= phase;
		phase_addr_d3 <= phase;
		phase_addr_d4 <= phase;

		// Duplicate address to reduce fanout (its a ridiculous kludge, but seems to be the approved method)
		rd_addr_z_1 <= {ADDRBITS{fsmreset}};
		rd_addr_z_2 <= {ADDRBITS{fsmreset}};
		rd_addr_z_3 <= {ADDRBITS{fsmreset}};
		rd_addr_z_4 <= {ADDRBITS{fsmreset}};
		
		Xmix_d <= Xmix;
		Xmix_d2 <= Xmix_d;
		X1out_d <= X1out;
		X1out_d2 <= X1out_d;
		Xaddr_d <= Xaddr;			// Perhaps use Xmix directly

		XCtl <= XSnull;				// Default states
		addrsourceSave <= 0;
		ram_wren <= 0;
		xoren <= 1;
		
		// Interface FSM ensures threads start evenly (required for correct salsa FSM operation)
		`ifdef ONETHREAD
		if (fsmstart && phase!=THREADS && phase!=THREADS+1)
			start_once <= 1'b1;
		if (fsmreset)
			start_once <= 1'b0;
		`else
		start_count <= start_count + 1;
		// start_flag <= 1'b0;			// Done below when we transition out of R_IDLE
		if (fsmreset || start_count == START_INTERVAL)
		begin
			start_count <= 0;
			if (~fsmreset && fsmstart)
				start_flag <= 1'b1;
		end
		`endif
		
		// Could use explicit mux for this ...
		if (shift)
		begin
			salsaShiftReg <= { salsaShiftReg[1022:0], nonce_sr[31] };
			nonce_sr <= { nonce_sr[30:0], din};
		end
		else
		if (XCtl==XSload && phase_d != THREADS && phase_d != THREADS+1)		// Set at end of previous hash - this is executed regardless of phase
		begin
			salsaShiftReg <= { Xmix, X1out };	// Simultaneously with XSload
			nonce_sr <= snonce[phase_d];		// NB bidirectional load
			snonce[phase_d] <= nonce_sr;
		end
		
		if (fsmreset == 1'b1)
		begin
			mstate <= R_IDLE;		// This will propagate to all sstate slots as we hold reset for 10 cycles
			busy_flag <= 1'b0;
			result <= 1'b0;
		end
		else
		begin
			case (mstate_in)
				R_IDLE: begin
					// R_IDLE only applies after reset. Normally each thread will reenter at S_START and
					// assumes that input data is waiting (this relies on the threads being started evenly,
					// hence the interface FSM at the top of this file)
					if (phase!=THREADS && phase!=THREADS+1 && start_flag)	// Ensure (phase==THREADS) slot is never active
					begin
						XCtl <= XSload;			// First time only (normally done at end of previous salsa cycle=1023)
						`ifndef ONETHREAD
							start_flag <= 1'b0;
						`endif
						busy_flag <= 1'b0;		// Toggle the busy flag low to ack pbkdfengine (its usually already set
												// since other threads are running)
						mstate <= R_START;
					end
				end
				R_START: begin					// Reentry point after thread completion. ASSUMES new data is ready.
						writeaddr <= 0;
						mcount <= 0;
						cycle <= 0;
						mixfeedback <= 1'b0;
						addrsourceMix <= 1'b0;
						mixspecial <= 1'b0;
						doneROM <= 1'b0;
						busy_flag <= 1'b1;
						result <= 1'b0;
						ram_wren <= 1'b1;		// Initial write cycle
						mstate <= R_WRITE;
					end
				R_WRITE: begin
					mcount <= mcount_in + 6'd1;
					// 8 stages since salsa takes 4 clock cycles. NB This minimises clock cycles, but adds to
					// the propagation delay in the salsa. The alternative of adding a cycle or two of latency to
					// reduce propagation delay is SLOWER due to the extra clocks needed.
					// Write to ROM every 2nd cycle (NB we are writing previous data here)
					// NB One extra cycle is performed after ROM is complete to update X0,X1 to inital state for R_MIX
					if (mcount_in==0)
					begin
						mixfeedback <= 1'b1;
						if (writeaddr_in==1023)
							doneROM <= 1'b1;			// Need to do one more cycle to update X0,X1
						writeaddr <= writeaddr_in + 10'd1;
					end
					if (mcount_in==4 || mcount_in==8)
						mixfeedback <= 1'b1;
					if (mcount_in==3 || mcount_in==7)
					begin
						XCtl <= XSmix;							
						mixfeedback <= 1'b0;
					end
					if (mcount_in==6 && doneROM_in)			// Preset the address source one cycle early
						addrsourceMix <= 1'b1;			// Remains set for duration of R_MIX
					if (mcount_in==7)
					begin
						mcount <= 0;
						if (doneROM_in)
						begin
							mstate <= R_MIX;
							XCtl <= XSram;				// Load from ram next cycle
							mixspecial <= 1'b1;			// Remains true throught R_MIX
							// Need this to cover the case of the initial read being interpolated
							// NB CODE IS REPLICATED IN R_MIX
							if (ADDRBITS < 13)
							begin
								intcycles <= { {THREADS_BITS+12-ADDRBITSX{1'b0}}, Xaddr_d[12-ADDRBITSX:0] };	// Interpolated addresses

								if ( Xaddr_d[9:13-ADDRBITSX] ==  memtop[ADDRBITSX-THREADS_BITS:1] )				// Highest address reserved
									intcycles <= { {THREADS_BITS+11-ADDRBITSX{1'b0}}, 1'b1, Xaddr_d[12-ADDRBITSX:0] };

								if ( (Xaddr_d[9:13-ADDRBITSX] == memtop[ADDRBITSX-THREADS_BITS:1]) || |Xaddr_d[12-ADDRBITSX:0] )
								begin
									addrsourceSave <= 1'b1;			// Setup to save at mcount_in==0 (also does so entering R_IDLE
									ram_wren <= 1'b1;				// after cycle==1023 but of no consequence)
									xoren <= 0;						// Will do direct load from ram, not xor
								end
							end
							// END REPLICATED BLOCK
						end
						else
						begin
							if (ADDRBITS < 13)
								ram_wren <= ~|writeaddr_in[12-ADDRBITSX:0];	// Only write non-interpolated addresses
							else
								ram_wren <= 1'b1;
						end
					end
				end
				R_MIX: begin
					// Entered with mixfeedback == 0 (set at mcount_in==7 above)
					// NB There is an extra step here cf R_WRITE above to read ram data hence 9 not 8 stages.
					// The longest chain is from mixfeedback to ram address input (since XMix is not registered),
					// again as noted above, extra register stages would simply reduce throughput.
					mcount <= mcount_in + 6'd1;
					if (mcount_in==0)
					begin
						mixfeedback <= 1'b1;
						if (intcycles_in != 0)		// Set in previous cycle
							mstate <= R_INT;		// Interpolate
					end

					if (mcount_in==4 || mcount_in==8)
						mixfeedback <= 1'b1;
					if (mcount_in==3 || mcount_in==7)
					begin
						XCtl <= XSmix;							
						mixfeedback <= 1'b0;
					end

					if (mcount_in==7)
					begin
						cycle <= cycle_in + 11'd1;
						mcount <= 0;
						if (cycle_in==1023)
						begin
							busy_flag <= 1'b0;	// Will hold at 0 for 9 clocks until set at R_START
							if (fsmstart)			// Check data input is ready
							begin
								XCtl <= XSload;		// Initial load else we overwrite input NB This is
													// executed on the next cycle, regardless of phase
								// Flag the SHA256 FSM to start final PBKDF2_SHA256_80_128_32
								result <= 1'b1;
								mstate <= R_START;	// Restart immediately
							end
							else
							begin
								mstate <= R_IDLE;	// Wait for start_flag
							end
						end
						else
						begin
							XCtl <= XSram;				// Load from ram next cycle
							// NB CODE IS REPLICATED IN R_WRITE
							if (ADDRBITS < 13)
							begin
								intcycles <= { {THREADS_BITS+12-ADDRBITSX{1'b0}}, Xaddr_d[12-ADDRBITSX:0] };	// Interpolated addresses

								if ( Xaddr_d[9:13-ADDRBITSX] ==  memtop[ADDRBITSX-THREADS_BITS:1] )				// Highest address reserved
									intcycles <= { {THREADS_BITS+11-ADDRBITSX{1'b0}}, 1'b1, Xaddr_d[12-ADDRBITSX:0] };

								if ( (Xaddr_d[9:13-ADDRBITSX] == memtop[ADDRBITSX-THREADS_BITS:1]) || |Xaddr_d[12-ADDRBITSX:0] )
								begin
									addrsourceSave <= 1'b1;			// Setup to save at mcount_in==0 (also does so entering R_IDLE
									ram_wren <= 1'b1;				// after cycle==1023 but of no consequence)
									xoren <= 0;						// Will do direct load from ram, not xor
								end
							end
							// END REPLICATED BLOCK
						end
					end
					
				end

				R_INT: begin
					// Interpolate scratchpad for odd addresses
					// Mcount has already been incremented in R_MIX
					mcount <= mcount_in + 6'd1;
					if (mcount_in==4 || mcount_in==8)
						mixfeedback <= 1'b1;
					if (mcount_in==3 || mcount_in==7)
					begin
						XCtl <= XSmix;							
						mixfeedback <= 1'b0;
					end

					if (mcount_in==6)
						addrsourceSave <= 1'b1;		// Preset to read saved data at mcount_in==8

					if (mcount_in==7)
					begin
						if (intcycles_in==1)
							XCtl <= XSram;			// Setup to XOR from saved X0/X1 in ram at next cycle
					end
					if (mcount_in==8)
					begin
						intcycles <= intcycles_in - 1;
						mcount <= 1;		// Skip 0 since done above
						if (intcycles_in==1)
							mstate <= R_MIX;
						// Else mstate remains at R_INT so we continue interpolating from mcount=1
					end
				end
			endcase
		end
`ifdef SIM
	// Print the final Xmix for each cycle to compare with scrypt.c (debugging)
	if (mstate==R_MIX && mcount==0)
		$display ("phase %d cycle %d Xmix %08x\n", phase, cycle-1, Xmix[511:480]);
`endif
	end	// always @(posedge hash_clk)
endmodule