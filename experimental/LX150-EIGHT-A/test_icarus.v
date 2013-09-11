// Testbench for ltcminer_icarus.v

`timescale 1ns/1ps

`ifdef SIM					// Avoids wrong top selected if included in ISE/PlanAhead sources
module test_ltcminer ();

	reg clk = 1'b0;
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
	
	// Running with default zero's for the data1..3 regs.
	// tx_hash=553a4b69b43913a61b42013ce210f713eaa7332e48cda1bdf3b93b10161d0876 at 187,990 nS and
	// final_hash (if SIM is defined) at 188,000 nS with golden_nonce_match flag NOT set since it is
	// not a diff=32 share. To test golden_nonce, just tweak the target eg 31'hffffffff will match everything
	
	// With serial input(at comm_clk_frequency=1_000_000), we get rx_done at t=70,220nS, however there is already a
	// PBKDF2_SHA256_80_128 loaded in Xbuf (for nonce=00000001). The first final_hash at 188,000 nS is corrupted as
	// the input data has changed from all 0's. The Xbuf starts salsa rom at t=188,000 but the nonce is incorrectly
	// taken from the newly loaded data so once salsa in complete it also generates a corrupt final_hash at ~362,000 nS.
	// Nonce is incremented then the newly loaded data starts PBKDF2_SHA256_80_128, so we must supply a nonce 1 less
	// than the expected golden_nonce. The correct PBKDF2_SHA256_80_128 is ready at ~ 197,000 nS. We get final_hash for
	// the corrupted work at ~362,000 nS then our required golden_nonce is at 536,180 nS.
	// This is only really a problem for simulation. With live hashing we just lose 2 nonces every time getwork is
	// loaded, which isn't a big deal.
		
	wire RxD;
	wire TxD;
	wire extminer_rxd = 0;
	wire extminer_txd;
	wire [3:0] dip = 0;
	wire [3:0] led;
	wire TMP_SCL=1, TMP_SDA=1, TMP_ALERT=1;
	
	parameter comm_clk_frequency = 1_000_000;	// Speeds up serial loading enormously rx_done is at t=70,220nS
	parameter baud_rate = 115_200;
	
	ltcminer_icarus #(.comm_clk_frequency(comm_clk_frequency)) uut
		(clk, RxD, TxD, led, extminer_rxd, extminer_txd, dip, TMP_SCL, TMP_SDA, TMP_ALERT);

	// Send serial data - 84 bytes, matches on nonce 318f (included in data)
	// NB starting nonce is 381e NOT 381f (see note above)
	reg [671:0] data = 672'h000007ff0000318e7e71441b141fe951b2b0c7dfc791d4646240fc2a2d1b80900020a24dc501ef1599fc48ed6cbac920af75575618e7b1e8eaf0b62a90d1942ea64d250357e9a09c063a47827c57b44e01000000;
	
	reg			serial_send = 0;
	wire		serial_busy;
	reg [31:0]	data_32 = 0;
	reg [31:0]	start_cycle = 0;

	serial_transmit #(.comm_clk_frequency(comm_clk_frequency), .baud_rate(baud_rate)) sertx (.clk(clk), .TxD(RxD), .send(serial_send), .busy(serial_busy), .word(data_32));

	// TUNE this according to comm_clk_frequency so we send a single getwork (else it gets overwritten with 0's)
	// parameter stop_cycle = 7020;		// For comm_clk_frequency=1_000_000
	parameter stop_cycle = 0;			// Use this to DISABLE sending data
	always @ (posedge clk)
	begin
		serial_send <= 0;				// Default
		// Send data every time tx goes idle (NB the !serial_send is to prevent serial_send
		// going high for two cycles since serial_busy arrives one cycle after serial_send)
		if (cycle > 5 && cycle < stop_cycle && !serial_busy && !serial_send)
		begin
			serial_send <= 1;
			data_32 <= data[671:640];
			data <= { data[639:0], 32'd0 };
			start_cycle <= cycle;		// Remember each start cycle (makes debugging easier)
		end
	end

endmodule
`endif