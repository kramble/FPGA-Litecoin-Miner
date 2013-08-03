// Testbench for ltcminer_icarus.v

`timescale 1ns/1ps

module test_ltcminer ();

	reg clk = 1'b0;
	
	// Not sending serial data, so running with default zero's for the data1..3 regs.
	// tx_hash=553a4b69b43913a61b42013ce210f713eaa7332e48cda1bdf3b93b10161d0876 at 187,990 nS and
	// final_hash (if SIM is defined) at 188,000 nS with golden_nonce_match flag NOT set since it is
	// not a diff=32 share. To test golden_nonce, just tweak the target eg 31'hffffffff will match everything
	
	wire RxD = 1;
	wire TxD;
	wire extminer_rxd = 0;
	wire extminer_txd;
	wire [3:0] dip = 0;
	wire [3:0] led;
	
	ltcminer_icarus uut (clk, RxD, TxD, led, extminer_rxd, extminer_txd, dip);

	reg [31:0] cycle = 32'd0;

	initial begin
		clk = 0;
		
		while(1)
		begin
			#5 clk = 1; #5 clk = 0;
		end
	end

	always @ (posedge clk)
	begin
		cycle <= cycle + 32'd1;
	end

endmodule

