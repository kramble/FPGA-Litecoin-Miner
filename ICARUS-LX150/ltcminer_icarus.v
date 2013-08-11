/* ltcminer_icarus.v copyright kramble 2013
 * Based on https://github.com/teknohog/Open-Source-FPGA-Bitcoin-Miner/tree/master/projects/Xilinx_cluster_cgminer
 * Hub code for a cluster of miners using async links
 * by teknohog
 */

`include "../source/sha-256-functions.v"
`include "../source/sha256_transform.v"
`include "../source/salsa.v"
`include "../source/hashcore.v"

module ltcminer_icarus (osc_clk, RxD, TxD, led, extminer_rxd, extminer_txd, dip);

// NB SPEED_MHZ resolution is 5MHz steps to keep pll divide ratio sensible
// You can change this in xilinx_pll.v but take care always to use valid integer
// division ratios else the comm_clk_frequency parameter may be incorrectly set.
`ifdef SPEED_MHZ
	parameter SPEED_MHZ = `SPEED_MHZ;
`else
	parameter SPEED_MHZ = 25;
`endif

//`ifdef SERIAL_CLK
//	parameter comm_clk_frequency = `SERIAL_CLK;
//`else
//	parameter comm_clk_frequency = 100_000_000;
//`endif

	parameter comm_clk_frequency = SPEED_MHZ * 1_000_000;

`ifdef BAUD_RATE
	parameter BAUD_RATE = `BAUD_RATE;
`else
	parameter BAUD_RATE = 115_200;
`endif

// kramble - now using same clock for uart and hashcore
	input osc_clk;
	wire hash_clk, uart_clk;

`ifndef SIM
	main_pll # (.SPEED_MHZ(SPEED_MHZ)) pll_blk (.CLKIN_IN(osc_clk), .CLKFX_OUT(hash_clk));
	assign uart_clk = hash_clk;
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
	parameter LOCAL_MINERS = 2;
`endif

// kramble - nonce distribution only works for a single external port 
`ifdef EXT_PORTS
	parameter EXT_PORTS = `EXT_PORTS;
`else
	parameter EXT_PORTS = 1;
`endif

	localparam SLAVES = LOCAL_MINERS + EXT_PORTS;

	// wire [LOCAL_MINERS-1:0] localminer_rxd;	// REMOVE

	input [3:0]dip;
	wire reset, nonce_chip;
	assign reset = dip[0];			// Not used
	assign nonce_chip = dip[1];		// Distinguishes between the two Icarus FPGA's

	// Work distribution is simply copying to all miners, so no logic
	// needed there, simply copy the RxD.
	input 	     RxD;

	output TxD;

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

   always @ (posedge hash_clk)
   begin
	if (rx_done)
		targetreg <= target;
   end
								
	serial_receive #(.comm_clk_frequency(comm_clk_frequency), .baud_rate(BAUD_RATE)) serrx (.clk(uart_clk), .RxD(RxD), .data1(data1), .data2(data2),
			.data3(data3), .target(target), .rx_done(rx_done));

   // Local miners now directly connected
   generate
      genvar 	     i;
      for (i = 0; i < LOCAL_MINERS; i = i + 1)
	begin: for_local_miners
	   wire [31:0] nonce_out;	// Not used
	   wire [2:0] nonce_core = i;
	   hashcore M (.hash_clk(hash_clk), .data1(data1), .data2(data2), .data3(data3), .target(targetreg),
					.nonce_msb({nonce_chip, nonce_core}), .nonce_out(nonce_out), .golden_nonce_out(slave_nonces[i*32+31:i*32]),
					.golden_nonce_match(new_nonces[i]), .loadnonce(rx_done));
	end
   endgenerate

   // External miner ports, results appended to the same
   // slave_nonces/new_nonces as local ones
   output [EXT_PORTS-1:0] extminer_txd;
   input [EXT_PORTS-1:0]  extminer_rxd;
   assign extminer_txd = {EXT_PORTS{RxD}};
      
   generate
      genvar 		  j;
      for (j = LOCAL_MINERS; j < SLAVES; j = j + 1)
	begin: for_ports
   	   slave_receive #(.comm_clk_frequency(comm_clk_frequency), .baud_rate(BAUD_RATE)) slrx (.clk(uart_clk), .RxD(extminer_rxd[j-LOCAL_MINERS]), .nonce(slave_nonces[j*32+31:j*32]), .new_nonce(new_nonces[j]));
	end
   endgenerate

   output [3:0] led;
   //assign led[0] = |golden_nonce;
   assign led[1] = ~RxD;
   assign led[2] = ~TxD;
   assign led[3] = 1'b1;

   // Light up only from locally found nonces, not ext_port results
   pwm_fade pf (.clk(uart_clk), .trigger(|new_nonces[LOCAL_MINERS-1:0]), .drive(led[0]));
   
endmodule
