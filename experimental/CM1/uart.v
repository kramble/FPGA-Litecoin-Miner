`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// UART Module
// Paul Mumby 2012
//////////////////////////////////////////////////////////////////////////////////
module uart(
		clk,
		rx_pin,
		tx_pin,
		rx_byte,
		tx_byte,
		rx_data_ready,
		tx_start,
		rx_busy,
		tx_busy,
		rx_error
	);

	//Parameters:
	//================================================
	parameter CLOCK = 25000000; 	//Overridden by parent 
	parameter BAUD = 9600;			//Overridden by parent
	parameter SAMPLE_POINT = 8;	//Overridden by parent
	
	//IO Definitions:
	//================================================
	input clk;
	input rx_pin;
	output tx_pin;
	output [7:0] rx_byte;
	input [7:0] tx_byte;
	output rx_data_ready;
	input tx_start;
	output rx_busy;
	output tx_busy;
	output rx_error;
	
	//Register/Wire Definitions:
	//================================================
	
	//BUFG Instatiation:
	//================================================
	
	//Module Instantiation:
	//================================================
	uart_tx #(
		.CLOCK(CLOCK),
		.BAUD(BAUD)
	) TXCORE (
		.clk(clk),
		.tx(tx_pin),
		.tx_byte(tx_byte),
		.start(tx_start),
		.busy(tx_busy)
	);

	uart_rx #(
		.CLOCK(CLOCK),
		.BAUD(BAUD),
		.SAMPLE_POINT(SAMPLE_POINT)
	) RXCORE (
		.clk(clk),
		.rx(rx_pin),
		.rx_byte(rx_byte),
		.data_ready(rx_data_ready),
		.busy(rx_busy),
		.error(rx_error)
	);
	
	//Assignments:
	//================================================
	
	//Toplevel Logic:
	//================================================

endmodule
