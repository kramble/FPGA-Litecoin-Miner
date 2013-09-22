/*!
   btcminer -- BTCMiner for ZTEX USB-FPGA Modules: HDL code for ZTEX USB-FPGA Module 1.15b (one double hash pipe)
   Copyright (C) 2011 ZTEX GmbH
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

module ztex_ufm1_15b1 (fxclk_in, reset, pll_stop,  dcm_progclk, dcm_progdata, dcm_progen,  rd_clk, wr_clk, wr_start, read, write);

	input fxclk_in, reset, pll_stop, dcm_progclk, dcm_progdata, dcm_progen, rd_clk, wr_clk, wr_start;
	input [7:0] read;
	output [7:0] write;

	reg [3:0] rd_clk_b, wr_clk_b;
	reg wr_start_b1, wr_start_b2, reset_buf;
	reg dcm_progclk_buf, dcm_progdata_buf, dcm_progen_buf;
	reg [4:0] wr_delay;
	reg [671:0] inbuf, inbuf_tmp;
	reg [95:0] outbuf;
	reg [7:0] read_buf, write_buf;
	
	wire fxclk, clk, dcm_clk, pll_fb, pll_clk0, dcm_locked, pll_reset;
	wire [31:0] golden_nonce, nonce2, hash2;

	wire [255:0]	data1, data2;
	wire [127:0]	data3;
	wire [31:0]		target;

	assign			target = inbuf[671:640];
	assign			data3 = inbuf[639:512];
	assign			data2 = inbuf[511:256];
	assign			data1 = inbuf[255:0];
	
	wire			gn_match;				// Just needed for hashcore connection
	wire			loadnonce;

	assign			loadnonce = 1'b0;		// This should be fine, alternatively try...
	// assign		loadnonce = reset_buf;	// You will need `define ICARUS in hashcore.v

	assign			hash2 = 32'd0;			// Alternatively output final_hash[255:224] from hachcore

	// Since this is a single core, you may want to `define NOMULTICORE in hashcore.v
	hashcore M (.hash_clk(clk), .data1(data1), .data2(data2), .data3(data3), .target(target),
					.nonce_msb(4'd0), .nonce_out(nonce2), .golden_nonce_out(golden_nonce),
					.golden_nonce_match(gn_match), .loadnonce(loadnonce));

	BUFG bufg_fxclk (
          .I(fxclk_in),
          .O(fxclk)
        );

	BUFG bufg_clk (
          .I(pll_clk0),
          .O(clk)
        );

        DCM_CLKGEN #(
		  .CLKFX_DIVIDE(6),
          .CLKFX_MULTIPLY(20),		// Gives nominal 160MHz clkfx for 48MHz clk_in
          .CLKFXDV_DIVIDE(2),
		  .CLKIN_PERIOD(20.8)		// Added to avoid critical warning (48MHz)
	) 
	dcm0 (
    	  .CLKIN(fxclk),
          .CLKFX(dcm_clk),
          .FREEZEDCM(1'b0),
          .PROGCLK(dcm_progclk_buf),
          .PROGDATA(dcm_progdata_buf),
          .PROGEN(dcm_progen_buf),
          .LOCKED(dcm_locked),
          .RST(1'b0)
	);

	PLL_BASE #(
    	    .BANDWIDTH("LOW"),
    	    .CLKFBOUT_MULT(5),
    	    .CLKOUT0_DIVIDE(32),		// To give 25MHz clk (160 * 5 / 32)
    	    .CLKOUT0_DUTY_CYCLE(0.5),
    	    .CLK_FEEDBACK("CLKFBOUT"), 
    	    .COMPENSATION("DCM2PLL"),
	    .DIVCLK_DIVIDE(1),
    	    .REF_JITTER(0.05),
	    .RESET_ON_LOSS_OF_LOCK("FALSE"),
		.CLKIN_PERIOD(6.25)			// Added to avoid critical warning (160Mhz)
       )
       pll0 (
    	    .CLKFBOUT(pll_fb),
	    .CLKOUT0(pll_clk0),
	    .CLKFBIN(pll_fb),
	    .CLKIN(dcm_clk),
	    .RST(pll_reset)
	);

	assign write = write_buf;
	assign pll_reset = pll_stop | ~dcm_locked;
	
	always @ (posedge clk)
	begin
    		if ( (rd_clk_b[3] == rd_clk_b[2]) && (rd_clk_b[2] == rd_clk_b[1]) && (rd_clk_b[1] != rd_clk_b[0]) )
		begin
		    inbuf_tmp[671:664] <= read_buf;			// NB changed from 351 in original
		    inbuf_tmp[663:0] <= inbuf_tmp[671:8];
		end;
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
   		    outbuf <= { hash2, nonce2, golden_nonce };
   		end else
   		begin
		    if ( (wr_clk_b[3] == wr_clk_b[2]) && (wr_clk_b[2] == wr_clk_b[1]) && (wr_clk_b[1] != wr_clk_b[0]) ) 
			outbuf[87:0] <= outbuf[95:8];
   		end

		read_buf <= read;
		write_buf <= outbuf[7:0];

		rd_clk_b[0] <= rd_clk;
		rd_clk_b[3:1] <= rd_clk_b[2:0];

		wr_clk_b[0] <= wr_clk;
		wr_clk_b[3:1] <= wr_clk_b[2:0];

		wr_start_b1 <= wr_start;
		wr_start_b2 <= wr_start_b1;

		
		reset_buf <= reset;
	end

	always @ (posedge fxclk)
	begin
		dcm_progclk_buf <= dcm_progclk;
		dcm_progdata_buf <= dcm_progdata;
		dcm_progen_buf <= dcm_progen;
	end


endmodule

