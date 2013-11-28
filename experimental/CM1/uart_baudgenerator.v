`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Baud Generator Core
// Paul Mumby 2012
// Originally derived from code examples at:
// http://www.fpga4fun.com
//////////////////////////////////////////////////////////////////////////////////

module uart_baudgenerator(
		clk,
		baudtick
	);

	//Parameters:
	//================================================
	parameter CLOCK = 25000000; // 25MHz
	parameter BAUD = 9600;
	parameter ACCWIDTH = 16;
	parameter ROUNDBITS = 5;
	parameter INC = ((BAUD<<(ACCWIDTH-(ROUNDBITS-1)))+(CLOCK>>ROUNDBITS))/(CLOCK>>(ROUNDBITS-1));

	//IO Definitions:
	//================================================
	input clk;
	output baudtick;
	
	//Register/Wire Definitions:
	//================================================
	reg [ACCWIDTH:0] accumulator = 0;
	
	//BUFG Instatiation:
	//================================================
	
	//Module Instantiation:
	//================================================
	
	//Assignments:
	//================================================
	assign baudtick = accumulator[ACCWIDTH];
	
	//Toplevel Logic:
	//================================================
	always @(posedge clk)
		accumulator <= accumulator[ACCWIDTH-1:0] + INC;

endmodule

