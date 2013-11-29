/*!
   btcminer -- BTCMiner for ZTEX USB-FPGA Modules: HDL code for ZTEX USB-FPGA Module 1.15b (one double hash pipe)
   Copyright (C) 2012 ZTEX GmbH
   http://www.ztex.de

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License version 3 as
   published by the Free Software Foundation.

   This program is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, see http://www.gnu.org/licenses/.
!*/

module ztex_ufm1_15y1 (fxclk_in, reset, select, clk_reset, pll_stop,  dcm_progclk, dcm_progdata, dcm_progen,  rd_clk, wr_clk, wr_start, read, write);

	input fxclk_in, select, reset, clk_reset, pll_stop, dcm_progclk, dcm_progdata, dcm_progen, rd_clk, wr_clk, wr_start;
	input [7:0] read;
	output [7:0] write;

	function integer clog2;		// Courtesy of razorfishsl, replaces $clog2()
		input integer value;
		begin
		value = value-1;
		for (clog2=0; value>0; clog2=clog2+1)
		value = value>>1;
		end
	endfunction

// Configure cores here since using `ifdef rather than generate (lazy)
//`define DUALCORE					// Comment out for single core (actually performs better)
//`define PROTOCOL80				// Select 80 or 76 byte protocol (NB use 76 for current cgminer)

`ifdef DUALCORE
	localparam LOCAL_MINERS = 2;	// One or two cores (configures ADDRBITS automatically)
`else
	localparam LOCAL_MINERS = 1;	// One or two cores (configures ADDRBITS automatically)
`endif

	localparam ADDRBITS = 12 - clog2(LOCAL_MINERS);	// Automatically selects largest RAM that will fit LX150
	localparam SBITS = 8;		// Shift data path width

`ifdef DUALCORE
	reg  phase = 1'b0;
`endif

	reg [3:0] rd_clk_b, wr_clk_b;
	reg wr_start_b1 = 0, wr_start_b2 = 0, reset_buf = 0, reset_buf_d = 0, clk_reset_buf = 1, pll_stop_buf = 1, select_buf = 0;
	reg dcm_progclk_buf, dcm_progdata_buf, dcm_progen_buf;
	reg [4:0] wr_delay;
	reg [127:0] outbuf;
	reg [7:0] read_buf, write_buf;
	reg [31:0] golden_nonce_a = 32'd0, golden_nonce_b = 32'd0;
	
	wire fxclk, clk, dcm_clk, pll_fb, pll_clk0, dcm_locked, pll_reset;
	wire [2:1] dcm_status;
	wire [31:0] golden_nonce_1, hash_1;
	wire [31:0] golden_nonce_2, hash_2;
	wire [31:0] golden_nonce, nonce_a, hash_a;
	wire gn_match_1, gn_match_2;
	
`define NOPLL		// PLL does not route so workaround uses DCM only
`ifndef SIM
	IBUFG bufg_fxclk (
          .I(fxclk_in),
          .O(fxclk)
        );

`ifndef NOPLL
	BUFG bufg_clk (
          .I(pll_clk0),
          .O(clk)
        );
`else
	BUFGCE bufg_clk (
          .I(dcm_clk),
          .CE(~pll_reset),
          .O(clk)
        );
`endif

		DCM_CLKGEN #(
			.CLKFX_DIVIDE(4),
			.CLKFX_MULTIPLY(16),		// Will be 32 or higher when set dynamically
			// .CLKFXDV_DIVIDE(8),		// NB using CLKFXDV output (original version up to v03)
			.CLKFXDV_DIVIDE(4),			// Single core can run faster, but firmware limit is 248Mhz so double it at v04
										// CARE cgminer clock now needs to be 124MHz or thereabouts instead of 248MHz
			.CLKIN_PERIOD(20.8333)		// 48MHz input
		) 
		dcm0 (
			.CLKIN(fxclk),
			.CLKFXDV(dcm_clk),
			.FREEZEDCM(1'b0),
			.PROGCLK(dcm_progclk_buf),
			.PROGDATA(dcm_progdata_buf),
			.PROGEN(dcm_progen_buf),
			.LOCKED(dcm_locked),
			.STATUS(dcm_status),
			.RST(clk_reset_buf)
		);

`ifndef NOPLL
	PLL_BASE #(
			.BANDWIDTH("LOW"),
			.CLKFBOUT_MULT(4),
			.CLKOUT0_DIVIDE(4),
			.CLKOUT0_DUTY_CYCLE(0.5),
			.CLK_FEEDBACK("CLKFBOUT"), 
			.COMPENSATION("INTERNAL"),
			.DIVCLK_DIVIDE(1),
			.REF_JITTER(0.10),
			.CLKIN_PERIOD(5.2),			// Needed since UCF now constrains clk rather than fxclk
			.RESET_ON_LOSS_OF_LOCK("FALSE")
		)
		pll0 (
			.CLKFBOUT(pll_fb),
			.CLKOUT0(pll_clk0),
			.CLKFBIN(pll_fb),
			.CLKIN(dcm_clk),
			.RST(pll_reset)
		);
`endif

`else
	assign clk = fxclk_in;	// SIM
`endif

	assign write = select ? write_buf : 8'bz;		// This actually does tristate the outputs
	assign pll_reset = pll_stop_buf | ~dcm_locked | clk_reset_buf | dcm_status[2];

`ifdef SIM
		// Test hash - final hash at 672,780ns
`ifdef PROTOCOL80
		// 80 byte protocol includes nonce
		reg [639:0] inbuf_tmp = {
			128'h0000318f7e71441b141fe951b2b0c7df,
			256'hc791d4646240fc2a2d1b80900020a24dc501ef1599fc48ed6cbac920af755756,
			256'h18e7b1e8eaf0b62a90d1942ea64d250357e9a09c063a47827c57b44e01000000
			};
`else
	// 76 byte protocol excludes nonce
		reg [607:0] inbuf_tmp = {
			96'h7e71441b141fe951b2b0c7df,
			256'hc791d4646240fc2a2d1b80900020a24dc501ef1599fc48ed6cbac920af755756,
			256'h18e7b1e8eaf0b62a90d1942ea64d250357e9a09c063a47827c57b44e01000000
			};
`endif				
`else	// SIM
`ifdef PROTOCOL80
		reg [639:0] inbuf_tmp;
`else
		reg [639:0] inbuf_tmp;
`endif				
`endif	// SIM

`ifdef PROTOCOL80
	reg [639:0] inbuf;			// 80 byte protocol
`else
	reg [607:0] inbuf;			// 76 byte protocol
`endif				

	wire [31:0] mod_target = 32'h00007fff;			// Hard coded for diff=2
	wire [255:0] data1 = inbuf[255:0];
	wire [255:0] data2 = inbuf[511:256];

`ifdef PROTOCOL80
	wire [127:0] data3 = inbuf[639:512];
`else
`ifdef SIM
	wire [127:0] data3 = { 32'h0000318f, inbuf[607:512] };
`else
	wire [127:0] data3 = { 32'd0, inbuf[607:512] };
`endif				
`endif		

	// Generate loadnonce strobe for new work (NB this initiates a full engine reset)
	reg loadnonce = 1'b0;	// Strobe generated loading work
	reg loadnonce_d = 1'b0;	// Delay by one since extra register stage inbuf
	
	// NB For now using same clk for both P and S

	wire [31:0] nonce_out_1;
	wire salsa_busy_1, salsa_result_1, salsa_reset_1, salsa_start_1, salsa_shift_1;
	wire [SBITS-1:0] salsa_din_1;
	wire [SBITS-1:0] salsa_dout_1;

	pbkdfengine #(.SBITS(SBITS)) P1
		(.hash_clk(clk), .pbkdf_clk(clk), .data1(data1), .data2(data2), .data3(data3), .target(mod_target),
		.nonce_msb( 4'd0 ), .nonce_out(nonce_out_1), .golden_nonce_out(golden_nonce_1),
		.golden_nonce_match(gn_match_1), .loadnonce(loadnonce_d),
		.salsa_din(salsa_din_1), .salsa_dout(salsa_dout_1), .salsa_busy(salsa_busy_1), .salsa_result(salsa_result_1),
		.salsa_reset(salsa_reset_1), .salsa_start(salsa_start_1), .salsa_shift(salsa_shift_1), .hash_out(hash_1));

	salsaengine #(.ADDRBITS(ADDRBITS), .SBITS(SBITS)) S1
		(.hash_clk(clk), .reset(salsa_reset_1), .din(salsa_din_1), .dout(salsa_dout_1),
		.shift(salsa_shift_1), .start(salsa_start_1), .busy(salsa_busy_1), .result(salsa_result_1) );

`ifdef DUALCORE
	wire [31:0] nonce_out_2;
	wire salsa_busy_2, salsa_result_2, salsa_reset_2, salsa_start_2, salsa_shift_2;
	wire [SBITS-1:0] salsa_din_2;
	wire [SBITS-1:0] salsa_dout_2;

	pbkdfengine #(.SBITS(SBITS)) P2
		(.hash_clk(clk), .pbkdf_clk(clk), .data1(data1), .data2(data2), .data3(data3), .target(mod_target),
		.nonce_msb( 4'd8 ), .nonce_out(nonce_out_2), .golden_nonce_out(golden_nonce_2),
		.golden_nonce_match(gn_match_2), .loadnonce(loadnonce_d),
		.salsa_din(salsa_din_2), .salsa_dout(salsa_dout_2), .salsa_busy(salsa_busy_2), .salsa_result(salsa_result_2),
		.salsa_reset(salsa_reset_2), .salsa_start(salsa_start_2), .salsa_shift(salsa_shift_2), .hash_out(hash_2));

	salsaengine #(.ADDRBITS(ADDRBITS), .SBITS(SBITS)) S2
		(.hash_clk(clk), .reset(salsa_reset_2), .din(salsa_din_2), .dout(salsa_dout_2),
		.shift(salsa_shift_2), .start(salsa_start_2), .busy(salsa_busy_2), .result(salsa_result_2) );

	// Need to alternate between cores to ensure HW error monitoring works correctly in driver_ztex
	// Phase toggles on reset which occurs prior to each new work

	assign nonce_a = phase ? nonce_out_2 : nonce_out_1;
	assign hash_a = phase ? hash_2 : hash_1;
	assign gn_match = gn_match_1 | gn_match_2;
	assign golden_nonce = gn_match_1 ? golden_nonce_1 : golden_nonce_2;
`else
	// Single core
	assign nonce_a = nonce_out_1;
	assign hash_a = hash_1;
	assign gn_match = gn_match_1;
	assign golden_nonce = golden_nonce_1;
`endif
	
	always @ (posedge clk)
	begin
		loadnonce <= 1'b0;								// For pbkdfengine
		loadnonce_d <= loadnonce;						// Delay by one since extra register stage inbuf

		// KRAMBLE not sure I understand this, it does not seem to be conventional clock-crossing as the comparison is the wrong
		// end of the shift register, so perhaps its a de-bounce on the rd_clk (which is sort of clock-crossing too) ??
		if ( (rd_clk_b[3] == rd_clk_b[2]) && (rd_clk_b[2] == rd_clk_b[1]) && (rd_clk_b[1] != rd_clk_b[0]) && select_buf )
		begin
`ifdef PROTOCOL80
		    inbuf_tmp[639:632] <= read_buf;
		    inbuf_tmp[631:0] <= inbuf_tmp[639:8];
`else
		    inbuf_tmp[607:600] <= read_buf;
		    inbuf_tmp[599:0] <= inbuf_tmp[607:8];
`endif
			// Nonce will be loaded (or reset to 0 in 76 byte protocol) every byte since there is no signal
			// that indicates when work is completely loaded (this means hashes generated during loading
			// are invalid, so we also reset golden_nonce_a/b below)
			loadnonce <= 1'b1;							// For pbkdfengine (single clock cycle strobe)
		end
		inbuf <= inbuf_tmp;  // due to TIG's
		    
		if ( wr_start_b1 && wr_start_b2 )
		begin
   		    wr_delay <= 5'd0;
		end else 
		begin
		    wr_delay[0] <= 1'b1;
		    wr_delay[4:1] <= wr_delay[3:0];
		end
		
		if ( ! wr_delay[4] ) 
		begin
   		    outbuf <= { golden_nonce_b, hash_a, nonce_a, golden_nonce_a };
   		end else
   		begin
			// KRAMBLE see note above for rd_clk
		    if ( (wr_clk_b[3] == wr_clk_b[2]) && (wr_clk_b[2] == wr_clk_b[1]) && (wr_clk_b[1] != wr_clk_b[0]) ) 
			outbuf[119:0] <= outbuf[127:8];
   		end

   		if ( reset_buf | loadnonce )					// Also reset on loadnonce since hashes are invalid
   		begin
   		    golden_nonce_a <= 32'd0;
   		    golden_nonce_b <= 32'd0;
   		end else if ( gn_match ) 
   		begin
   		    golden_nonce_b <= golden_nonce_a;
   		    golden_nonce_a <= golden_nonce;
   		end

		read_buf <= read;
		write_buf <= outbuf[7:0];

		rd_clk_b[0] <= rd_clk;
		rd_clk_b[3:1] <= rd_clk_b[2:0];

		wr_clk_b[0] <= wr_clk;
		wr_clk_b[3:1] <= wr_clk_b[2:0];

		wr_start_b1 <= wr_start;
		wr_start_b2 <= wr_start_b1;
		
		select_buf <= select;
		if ( select ) 
		begin
		    reset_buf <= reset;
		end

		reset_buf_d <= reset_buf;
		if (reset_buf_d & ~reset_buf)					// Executes on trailing edge of reset
		begin
`ifdef DUALCORE
			phase <= ~phase;
`endif
		end
	end

	always @ (posedge fxclk)
	begin
		dcm_progclk_buf <= dcm_progclk;
		dcm_progdata_buf <= dcm_progdata;
		dcm_progen_buf <= dcm_progen & select;
		if ( select ) 
		begin
		    clk_reset_buf <= clk_reset;
		    pll_stop_buf <= pll_stop;
		end
	end


endmodule

