`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// New Serial Core
// For Enterpoint Cairnsmore1 Icarus Derived Bitstream
// By Paul Mumby
// Licensed Under GNU GPL V3
//////////////////////////////////////////////////////////////////////////////////
module serial_core #(parameter CLOCK=25000000, BAUD=57600, SAMPLE_POINT=8)(
	clk,
	rx,
	tx,
	rx_ready,
	tx_ready,
	data1,
	data2,
	data3,
	word,
	tx_busy,
	rx_busy
	);

	// IO Declaration
	//===================================================
	input clk;
	input rx;
	output tx;
	output rx_ready;
	input tx_ready;	
   output [255:0] data1;
   output [255:0] data2;
   output [127:0] data3;
	input [31:0] word;
	output tx_busy;
	output rx_busy;
	
	//Wire & Register Declaration
	//===================================================
	reg uart_tx_ready = 0;
	wire uart_rx_ready;
	wire uart_tx_busy;
	wire uart_rx_busy;
	wire uart_error;
	reg [7:0] uart_tx_byte;
	wire [7:0] uart_rx_byte;
   reg [3:0] tx_mux_state = 4'b0000;
	reg [31:0] tx_word_copy;
`ifdef SIM
	// 76 byte protocol excludes nonce
reg [607:0] rx_input_buffer = {
			96'h7e71441b141fe951b2b0c7df,
			256'hc791d4646240fc2a2d1b80900020a24dc501ef1599fc48ed6cbac920af755756,
			256'h18e7b1e8eaf0b62a90d1942ea64d250357e9a09c063a47827c57b44e01000000
			};
`else
   reg [607:0] rx_input_buffer;
`endif

	//Module Instantiation
	//===================================================
	wire unused_rx_error;
	
	uart #(.CLOCK(CLOCK),.BAUD(BAUD),.SAMPLE_POINT(SAMPLE_POINT)) UART_CORE (
		.clk(clk),
		.rx_pin(rx),
		.tx_pin(tx),
		.tx_start(uart_tx_ready),
		.rx_data_ready(uart_rx_ready),
		.rx_busy(uart_rx_busy),
		.tx_busy(uart_tx_busy),
		.tx_byte(uart_tx_byte),
		.rx_byte(uart_rx_byte),
		.rx_error(unused_rx_error)
		);

	//Assignments
	//===================================================
   assign tx_busy = (|tx_mux_state);
`ifdef SIM
	// 76 byte protocol excludes nonce
	assign data3 = { 32'h0000318f, rx_input_buffer[607:512] };	// Load test nonce (match at ~1042uS)
`else
	assign data3 = { 32'd0, rx_input_buffer[607:512] };			// Load zero nonce
`endif
   assign data2 = rx_input_buffer[511:256];
   assign data1 = rx_input_buffer[255:0];
   assign rx_ready = uart_rx_ready;

	//Logic
	//===================================================
	
	//TX Handler
	always @(posedge clk)
	begin
		if (!tx_busy && tx_ready)
		  begin
			  tx_mux_state <= 4'b1000;
			  tx_word_copy <= word;
		  end  
		else if (tx_mux_state[3] && ~tx_mux_state[0] && !uart_tx_busy)
		  begin
			  uart_tx_ready <= 1;
			  tx_mux_state <= tx_mux_state + 1;
			  uart_tx_byte <= tx_word_copy[31:24];
			  tx_word_copy <= (tx_word_copy << 8);
		  end
		else if (tx_mux_state[3] && tx_mux_state[0])
		  begin
			  uart_tx_ready <= 0;
			  if (!uart_tx_busy) tx_mux_state <= tx_mux_state + 1;
		  end
	end
	
	//RX Handler
	always @(posedge clk)
	begin
		if(uart_rx_ready)
			begin
				rx_input_buffer <= rx_input_buffer << 8;
				rx_input_buffer[7:0] <= uart_rx_byte;
			end
		else
			rx_input_buffer <= rx_input_buffer;
	end
	

endmodule
