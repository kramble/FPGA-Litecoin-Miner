`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// UART RX Module
// Paul Mumby 2012
// Originally derived from code examples at:
// http://www.fpga4fun.com
//////////////////////////////////////////////////////////////////////////////////
module uart_rx(
		clk,			//Communications Clock
		rx,			//Tx IO Pin
		rx_byte,		//Byte to Transmit
		data_ready,		//Start Transmitting Byte
		busy,			//Tx Busy Flag
		error
	);

	//Parameters:
	//================================================
	parameter CLOCK = 25000000; 	//Overridden by parent UART core
	parameter BAUD = 9600;			//Overridden by parent UART core
	parameter SAMPLE_POINT = 8;	//Overridden by parent

	//IO Definitions:
	//================================================
	input clk;
	wire baudtick;
	input rx;
	output reg [7:0] rx_byte;
	output reg data_ready;
	output busy;
	output reg error;
	
	//Register/Wire Definitions:
	//================================================
	reg [1:0] rx_sync;
	reg [1:0] rx_counter;
	reg rx_bit;
	reg [3:0] state;
	reg [3:0] bit_spacing;
	reg [4:0] data_gap;
	reg rx_buf1, rx_buf2;
	wire next_bit;
	wire rx_n;
	
	//BUFG Instatiation:
	//================================================
	
	//Module Instantiation:
	//================================================
	uart_baudgenerator #(
		.CLOCK(CLOCK),
		.BAUD(BAUD*8),	//Oversampled
		.ROUNDBITS(8)	//Higher frequency requires more rounding
	) BAUDGEN (
		.clk(clk),
		.baudtick(baudtick)
	);

	//Assignments:
	//================================================
	
	//Inverted rx for stability:
	assign rx_n = ~rx_buf2;
	//Note: value below for bit_spacing check, defines where data sampling occurs
	assign next_bit = (bit_spacing==SAMPLE_POINT);
	//Gap Detection:
	assign busy = ~data_gap[4];
	
	//Toplevel Logic:
	//================================================
	
	//Double Buffering
	always @(posedge clk)
		begin
			rx_buf1 <= rx;
			rx_buf2 <= rx_buf1;
		end
	
	//Oversampling & Sync of RX Input to clock
	always @(posedge clk)
		if(baudtick)
			rx_sync <= {rx_sync[0], rx_n};
	
	//RX Line Noise Filter
	always @(posedge clk)
		if(baudtick)
			begin
				if(rx_sync[1] && rx_counter!=2'b11)
					rx_counter <= rx_counter + 2'h1;
				if(~rx_sync[1] && rx_counter!=2'b00)
					rx_counter <= rx_counter - 2'h1;
				if(rx_counter==2'b00)
					rx_bit <= 1'b0;
				else if(rx_counter==2'b11)
					rx_bit <= 1'b1;
			end
	
	//RX State Machine
	always @(posedge clk)
		if(baudtick)
			case(state)
				4'b0000: if(rx_bit) state <= 4'b1000; // start bit found?
				4'b1000: if(next_bit) state <= 4'b1001; // bit 0
				4'b1001: if(next_bit) state <= 4'b1010; // bit 1
				4'b1010: if(next_bit) state <= 4'b1011; // bit 2
				4'b1011: if(next_bit) state <= 4'b1100; // bit 3
				4'b1100: if(next_bit) state <= 4'b1101; // bit 4
				4'b1101: if(next_bit) state <= 4'b1110; // bit 5
				4'b1110: if(next_bit) state <= 4'b1111; // bit 6
				4'b1111: if(next_bit) state <= 4'b0001; // bit 7
				4'b0001: if(next_bit) state <= 4'b0000; // stop bit
				default: state <= 4'b0000;
			endcase
	
	//Bit Spacing Detection
	always @(posedge clk)
		if(state==0)
			bit_spacing <= 4'b0000;
		else if(baudtick)
			bit_spacing <= {bit_spacing[2:0] + 4'b0001} | {bit_spacing[3], 3'b000};

	//Shift Register
	always @(posedge clk)
		if(baudtick && next_bit && state[3]) 
			rx_byte <= {~rx_bit, rx_byte[7:1]};
	
	//Data Ready & Error Detection
	always @(posedge clk)
		begin
			data_ready <= (baudtick && next_bit && state==4'b0001 && ~rx_bit);  // ready only if the stop bit is received
			error <= (baudtick && next_bit && state==4'b0001 && rx_bit);  // error if no stop bit received
		end
	
	//Idle Detection
	always @(posedge clk)
		if(state!=0)
			data_gap <= 5'h00;
		else if(baudtick & ~data_gap[4])
			data_gap <= data_gap + 5'h01;
	
endmodule
