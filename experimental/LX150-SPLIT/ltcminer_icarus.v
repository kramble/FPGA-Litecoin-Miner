/* ltcminer_icarus.v copyright kramble 2013
 * Based on https://github.com/teknohog/Open-Source-FPGA-Bitcoin-Miner/tree/master/projects/Xilinx_cluster_cgminer
 * Hub code for a cluster of miners using async links
 * by teknohog
 */

`include "../../source/sha-256-functions.v"
`include "../../source/sha256_transform.v"
`include "../../source/salsa.v"
`include "../../ICARUS-LX150/xilinx_ram.v"
`include "../../ICARUS-LX150/xilinx_pll.v"
`include "../../ICARUS-LX150/uart_receiver.v"
`include "../../ICARUS-LX150/uart_transmitter.v"
`include "../../ICARUS-LX150/serial.v"
`include "../../ICARUS-LX150/serial_hub.v"
`include "../../ICARUS-LX150/hub_core.v"
`include "../../ICARUS-LX150/pwm_fade.v"

module ltcminer_icarus (osc_clk, RxD, TxD, led, extminer_rxd, extminer_txd, dip, TMP_SCL, TMP_SDA, TMP_ALERT);

// NB SPEED_MHZ resolution is 5MHz steps to keep pll divide ratio sensible. Change the divider in xilinx_pll.v if you
// want other steps (1MHz is not sensible as it requires divide 100 which is not in the allowed range 1..32 for DCM_SP)
// TODO dynamic speed adjustment (possibly use top byte of target to set multiplier, this keeps serial interface compatible)
`ifdef SPEED_MHZ
	parameter SPEED_MHZ = `SPEED_MHZ;
`else
	parameter SPEED_MHZ = 25;
`endif

`ifdef SERIAL_CLK
	parameter comm_clk_frequency = `SERIAL_CLK;
`else
	parameter comm_clk_frequency = 12_500_000;		// 100MHz divide 8
`endif

`ifdef BAUD_RATE
	parameter BAUD_RATE = `BAUD_RATE;
`else
	parameter BAUD_RATE = 115_200;
`endif

// kramble - since using separare clocks for uart and hasher, need clock crossing logic
	input osc_clk;
	wire hash_clk, uart_clk;

`ifndef SIM
	main_pll # (.SPEED_MHZ(SPEED_MHZ)) pll_blk (.CLKIN_IN(osc_clk), .CLKFX_OUT(hash_clk), .CLKDV_OUT(uart_clk));
`else
	assign hash_clk = osc_clk;
	assign uart_clk = osc_clk;
`endif
   
// kramble - nonce distribution is crude using top 4 bits of nonce so max LOCAL_MINERS = 8
// teknohog's was more sophisticated, but requires modification of hashcore.v

// Miners on the same FPGA with this hub
`ifdef LOCAL_MINERS
	parameter LOCAL_MINERS = `LOCAL_MINERS;
`else
	parameter LOCAL_MINERS = 1;					// Only ONE core of LX150_FOUR will fit
`endif

// kramble - nonce distribution only works for a single external port 
`ifdef EXT_PORTS
	parameter EXT_PORTS = `EXT_PORTS;
`else
	parameter EXT_PORTS = 1;
`endif

	localparam SLAVES = LOCAL_MINERS + EXT_PORTS;

	input TMP_SCL, TMP_SDA, TMP_ALERT;	// Unused but set to PULLUP so as to avoid turning on the HOT LED
										// TODO implement I2C protocol to talk to temperature sensor chip (TMP101?)
										// and drive FAN speed control output.

	input [3:0]dip;
	wire reset, nonce_chip;
	assign reset = dip[0];			// Not used
	assign nonce_chip = dip[1];		// Distinguishes between the two Icarus FPGA's

	// Work distribution is simply copying to all miners, so no logic
	// needed there, simply copy the RxD.
	input	RxD;
	output	TxD;

	// Results from the input buffers (in serial_hub.v) of each slave
	wire [SLAVES*32-1:0]	slave_nonces;
	wire [SLAVES-1:0]		new_nonces;

	// Using the same transmission code as individual miners from serial.v
	wire		serial_send;
	wire		serial_busy;
	wire [31:0]	golden_nonce;
	serial_transmit #(.comm_clk_frequency(comm_clk_frequency), .baud_rate(BAUD_RATE)) sertx (.clk(uart_clk), .TxD(TxD), .send(serial_send), .busy(serial_busy), .word(golden_nonce));

	hub_core #(.SLAVES(SLAVES)) hc (.uart_clk(uart_clk), .new_nonces(new_nonces), .golden_nonce(golden_nonce), .serial_send(serial_send), .serial_busy(serial_busy), .slave_nonces(slave_nonces));

	// Common workdata input for local miners
	wire [255:0]	data1, data2;
	wire [127:0]	data3;
	wire [31:0]		target;
	// reg [31:0]	targetreg = 32'hffffffff;	// TEST - matches ANYTHING
	reg  [31:0]		targetreg = 32'h000007ff;	// Start at sane value (overwritten by serial_receive)
	wire			rx_done;		// Signals hashcore to reset the nonce
									// NB in my implementation, it loads the nonce from data3 which should be fine as
									// this should be zero, but also supports testing using non-zero nonces.

	// Synchronise across clock domains from uart_clk to hash_clk
	// This probably looks amateurish (mea maxima culpa, novice verilogger at work), but should be OK
	reg rx_done_toggle = 1'b0;		// uart_clk domain
	always @ (posedge uart_clk)
		rx_done_toggle <= rx_done_toggle ^ rx_done;

	reg rx_done_toggle_d1 = 1'b0;	// hash_clk domain
	reg rx_done_toggle_d2 = 1'b0;
	reg rx_done_toggle_d3 = 1'b0;
	
	wire loadnonce;
	assign loadnonce = rx_done_toggle_d3 ^ rx_done_toggle_d2;

	always @ (posedge hash_clk)
	begin
		rx_done_toggle_d1 <= rx_done_toggle;
		rx_done_toggle_d2 <= rx_done_toggle_d1;
		rx_done_toggle_d3 <= rx_done_toggle_d2;
		if (loadnonce)
			targetreg <= target;
	end
	// End of clock domain sync

	serial_receive #(.comm_clk_frequency(comm_clk_frequency), .baud_rate(BAUD_RATE)) serrx (.clk(uart_clk), .RxD(RxD), .data1(data1),
						.data2(data2), .data3(data3), .target(target), .rx_done(rx_done));

	// Local miners now directly connected
	generate
		genvar i;
		for (i = 0; i < LOCAL_MINERS; i = i + 1)
		begin: for_local_miners
			wire [31:0] nonce_out;	// Not used
			wire [2:0] nonce_core = i;
			wire gn_match;
			
			wire salsa_din, salsa_dout, salsa_busy, salsa_result, salsa_reset, salsa_start, salsa_shift;

			// Currently one pbkdfengine per salsaengine - TODO share the pbkdfengine for several salsaengines
			pbkdfengine P (.hash_clk(hash_clk), .data1(data1), .data2(data2), .data3(data3), .target(targetreg),
				.nonce_msb({nonce_chip, nonce_core}), .nonce_out(nonce_out), .golden_nonce_out(slave_nonces[i*32+31:i*32]),
				.golden_nonce_match(gn_match), .loadnonce(loadnonce),
				.salsa_din(salsa_din), .salsa_dout(salsa_dout), .salsa_busy(salsa_busy), .salsa_result(salsa_result),
				.salsa_reset(salsa_reset), .salsa_start(salsa_start), .salsa_shift(salsa_shift));

			salsaengine S (.hash_clk(hash_clk), .reset(salsa_reset), .din(salsa_din), .dout(salsa_dout), .shift(salsa_shift),
				.start(salsa_start), .busy(salsa_busy), .result(salsa_result) );
					
			// Synchronise across clock domains from hash_clk to uart_clk for: assign new_nonces[i] = gn_match;
			reg gn_match_toggle = 1'b0;		// hash_clk domain
			always @ (posedge hash_clk)
				gn_match_toggle <= gn_match_toggle ^ gn_match;

			reg gn_match_toggle_d1 = 1'b0;	// uart_clk domain
			reg gn_match_toggle_d2 = 1'b0;
			reg gn_match_toggle_d3 = 1'b0;

			assign new_nonces[i] = gn_match_toggle_d3 ^ gn_match_toggle_d2;

			always @ (posedge uart_clk)
			begin
				gn_match_toggle_d1 <= gn_match_toggle;
				gn_match_toggle_d2 <= gn_match_toggle_d1;
				gn_match_toggle_d3 <= gn_match_toggle_d2;
			end
			// End of clock domain sync
		end // for
	endgenerate

	// External miner ports, results appended to the same
	// slave_nonces/new_nonces as local ones
	output [EXT_PORTS-1:0] extminer_txd;
	input [EXT_PORTS-1:0]  extminer_rxd;
	assign extminer_txd = {EXT_PORTS{RxD}};

	generate
		genvar j;
		for (j = LOCAL_MINERS; j < SLAVES; j = j + 1)
		begin: for_ports
			slave_receive #(.comm_clk_frequency(comm_clk_frequency), .baud_rate(BAUD_RATE)) slrx (.clk(uart_clk), .RxD(extminer_rxd[j-LOCAL_MINERS]), .nonce(slave_nonces[j*32+31:j*32]), .new_nonce(new_nonces[j]));
		end
	endgenerate

	output [3:0] led;
	assign led[1] = ~RxD;
	assign led[2] = ~TxD;
	assign led[3] = ~ (TMP_SCL | TMP_SDA | TMP_ALERT);	// IDLE LED - held low (the TMP pins are PULLUP, this is a fudge to
														// avoid warning about unused inputs)

	// Light up only from locally found nonces, not ext_port results
	pwm_fade pf (.clk(uart_clk), .trigger(|new_nonces[LOCAL_MINERS-1:0]), .drive(led[0]));
   
endmodule
