`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// UART TX Module
// Paul Mumby 2012
// Originally derived from code examples at:
// http://www.fpga4fun.com
//////////////////////////////////////////////////////////////////////////////////
module uart_tx(
		clk,			//Communications Clock
		tx,			//Tx IO Pin
		tx_byte,		//Byte to Transmit
		start,		//Start Transmitting Byte
		busy			//Tx Busy Flag
	);

	//Parameters:
	//================================================
	parameter CLOCK = 25000000; 	//Overridden by parent UART core
	parameter BAUD = 9600;			//Overridden by parent UART core

	//IO Definitions:
	//================================================
	input clk;
	wire baudtick;
	output reg tx;
	input [7:0] tx_byte;
	input start;
	output busy;
	
	//Register/Wire Definitions:
	//================================================
	reg [3:0] state = 0;
	reg [7:0] byte_buf;
	reg muxflag;
	wire ready;
		
	//BUFG Instatiation:
	//================================================
	
	//Module Instantiation:
	//================================================
	uart_baudgenerator #(
		.CLOCK(CLOCK),
		.BAUD(BAUD),
		.ROUNDBITS(5)
	) BAUDGEN (
		.clk(clk),
		.baudtick(baudtick)
	);

	//Assignments:
	//================================================
	assign ready = (state==0);
	assign busy = ~ready;
	
	//Toplevel Logic:
	//================================================
	
	//Buffer Logic:
	always @(posedge clk)
		if(ready & start)
			byte_buf <= tx_byte;
	
	//Tx State Machine
	always @(posedge clk)
		case(state)
			4'b0000: if(start) state <= 4'b0001;
			4'b0001: if(baudtick) state <= 4'b0100;
			4'b0100: if(baudtick) state <= 4'b1000;  // start
			4'b1000: if(baudtick) state <= 4'b1001;  // bit 0
			4'b1001: if(baudtick) state <= 4'b1010;  // bit 1
			4'b1010: if(baudtick) state <= 4'b1011;  // bit 2
			4'b1011: if(baudtick) state <= 4'b1100;  // bit 3
			4'b1100: if(baudtick) state <= 4'b1101;  // bit 4
			4'b1101: if(baudtick) state <= 4'b1110;  // bit 5
			4'b1110: if(baudtick) state <= 4'b1111;  // bit 6
			4'b1111: if(baudtick) state <= 4'b0010;  // bit 7
			4'b0010: if(baudtick) state <= 4'b0011;  // stop1
			4'b0011: if(baudtick) state <= 4'b0000;  // stop2
			default: if(baudtick) state <= 4'b0000;		
		endcase

	//Mux Logic
	always @(*)
		case(state[2:0])
			3'd0: muxflag <= byte_buf[0];
			3'd1: muxflag <= byte_buf[1];
			3'd2: muxflag <= byte_buf[2];
			3'd3: muxflag <= byte_buf[3];
			3'd4: muxflag <= byte_buf[4];
			3'd5: muxflag <= byte_buf[5];
			3'd6: muxflag <= byte_buf[6];
			3'd7: muxflag <= byte_buf[7];
		endcase

	//TX IO Drive Logic
	always @(posedge clk)
		tx <= (state<4) | (state[3] & muxflag);

endmodule
