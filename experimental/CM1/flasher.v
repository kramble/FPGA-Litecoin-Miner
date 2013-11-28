`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Simple Clock Divider Style Flasher
// Paul Mumby 2012
//////////////////////////////////////////////////////////////////////////////////
module flasher(
		clk,
		flash
	);

	//Parameters:
	//================================================
	
	//Number of bits to divide MSB will be the flash output
	parameter BITS = 24;
								
	//IO Definitions:
	//================================================
	input clk;
	output flash;

	//Register/Wire Definitions:
	//================================================
	reg [BITS-1:0] counter;
	
	//Assignments:
	//================================================
	assign flash = counter[BITS-1];
	
	//Toplevel Logic:
	//================================================
	always @(posedge clk)
		counter <= counter + 1;

endmodule
