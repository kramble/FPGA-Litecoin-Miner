`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Dynamic DCM Controller. Derived from sources from TheSeven at:
// https://github.com/progranism/Open-Source-FPGA-Bitcoin-Miner
// Paul Mumby 2012
//////////////////////////////////////////////////////////////////////////////////
module dcm_controller (
		clk,
		data2,
		midstate,
		start,
		dcm_prog_data,
		dcm_prog_clk,
		dcm_prog_done,
		dcm_prog_en,
		identify
	);

	//Parameters:
	//================================================
	parameter MAXIMUM_MULTIPLIER = 88;
	parameter MINIMUM_MULTIPLIER = 20;
	parameter INITIAL_MULTIPLIER = 60;
	parameter INITIAL_DIVIDER = 10;

	//IO Definitions:
	//================================================
	input clk;
   input [255:0] midstate;
	input [255:0] data2;
	input start;
	input dcm_prog_clk;
	output dcm_prog_data;
	output dcm_prog_en;
	input dcm_prog_done;
	output identify;
	
	//Register/Wire Definitions:
	//================================================
	reg dcm_prog_data = 0;
	reg dcm_prog_en = 0;
	wire [31:0] cmd_trigger_timestamp;
	wire cmd_trigger;
	wire [7:0] cmd_prefix;
	wire [7:0] cmd_id;
	wire [7:0] cmd_data;
	wire [7:0] cmd_validator;
	wire cmd_valid;
	reg busy = 0;
	reg [7:0] cmd_latch_id = 8'd0;
	reg [7:0] cmd_latch_data = 8'd0;
	reg dcm_prog_ready = 0;
	reg [7:0] dcm_multiplier = INITIAL_MULTIPLIER;
	reg [7:0] current_dcm_multiplier = 8'd0;
	reg [4:0] dcm_progstate = 5'd31;
	reg [15:0] dcm_data = 16'd0;
	wire [7:0] dcm_divider_s1;
	wire [7:0] dcm_multiplier_s1;
	reg dcm_prog_ready_b = 0;
	wire dcm_prog_busy;
	reg [7:0] dcm_multiplier_b = 8'd0;
	reg identify = 0;
	reg [2:0] nonce_dip_bits = 3'd0;
	wire [12:0] fsm_state;
	
	//Assignments:
	//================================================
	assign cmd_trigger_timestamp = data2[63:32];
	assign cmd_prefix = data2[231:224];		//data2 byte 29 should always be 10110111 results in xor against 01011010 with id/data
	assign cmd_id = data2[239:232];			//data2 byte 30
	assign cmd_data = data2[247:240];		//data2 byte 31
	assign cmd_validator = data2[255:248];	//data2 byte 32
	assign cmd_trigger = (cmd_trigger_timestamp == 32'hffffffff) && (midstate == 256'd0);
	assign cmd_valid = cmd_validator == (cmd_prefix ^ cmd_id ^ cmd_data ^ 8'b01101101);
	assign dcm_prog_busy = (dcm_progstate != 5'd31);
	assign dcm_divider_s1 = INITIAL_DIVIDER-1;
	assign dcm_multiplier_s1 = dcm_multiplier_b - 8'd1;
	assign fsm_state = {start,cmd_trigger,cmd_valid,busy,dcm_prog_busy,cmd_latch_id};
	
	//Toplevel Logic:
	//================================================
		
	//Main command processor/validation state machine
	always @(posedge clk)
		begin
			casex (fsm_state)
				13'b1110xxxxxxxxx: begin //(start && cmd_trigger && cmd_valid && ~busy)
						//We're not busy, and We've received the start (data in from uart) 
						//and trigger (appropriate malformed packet)
						//And the command passes it's simple validation check
						//So lets decode it, latch the data, and flag busy to handle the command
						cmd_latch_id <= cmd_id;
						cmd_latch_data <= cmd_data;
						busy <= 1; //Flag we're busy										
					end
				13'bxxx1000000000: begin //(busy && cmd_latch_id==8'd0 && ~dcm_prog_busy)
						//COMMAND: Set Clock
						if(cmd_latch_data > MAXIMUM_MULTIPLIER)
							dcm_multiplier <= MAXIMUM_MULTIPLIER;
						else if(cmd_latch_data < MINIMUM_MULTIPLIER)
							dcm_multiplier <= MINIMUM_MULTIPLIER;
						else
							dcm_multiplier <= cmd_latch_data;
						dcm_prog_ready <= 1;
						busy <= 0;
					end
				13'bxxx1x00000001: begin //(busy && cmd_latch_id==8'd1)
						//COMMAND: Identify
						identify <= cmd_latch_data[0]; //Set identify flag to first bit of command data byte.
					end
				13'bxxx1x00000010: begin //(busy && cmd_latch_id==8'd2)
						//COMMAND: Set Nonce_DIP_Bits
						nonce_dip_bits <= cmd_latch_data[2:0]; //Set number of nonce msb bits to take from chip-specific DIP switches
					end			
				default: begin	//else
						dcm_prog_ready <= 0; //stop asserting prog_ready, the programmer has grabbed it by now.
					end
			endcase
		end
		
	//DCM Programming logic
	//Mostly copied from https://github.com/progranism/Open-Source-FPGA-Bitcoin-Miner
	//Adapted to our specific setup
	always @(posedge dcm_prog_clk)
		begin
			//Clock crossing buffers:
			dcm_prog_ready_b <= dcm_prog_ready;
			dcm_multiplier_b <= dcm_multiplier;
			
			if (dcm_multiplier_b != current_dcm_multiplier && dcm_progstate == 5'd31 && dcm_prog_ready_b)
			begin
				current_dcm_multiplier <= dcm_multiplier_b;
				dcm_progstate <= 5'd0;
				// DCM expects D-1 and M-1
				dcm_data <= {dcm_multiplier_s1, dcm_divider_s1};
			end

			if (dcm_progstate == 5'd0) {dcm_prog_en, dcm_prog_data} <= 2'b11;
			if (dcm_progstate == 5'd1) {dcm_prog_en, dcm_prog_data} <= 2'b10;
			if ((dcm_progstate >= 5'd2 && dcm_progstate <= 5'd9) || (dcm_progstate >= 5'd15 && dcm_progstate <= 5'd22))
			begin
				dcm_prog_data <= dcm_data[0];
				dcm_data <= {1'b0, dcm_data[15:1]};
			end

			if (dcm_progstate == 5'd10) {dcm_prog_en, dcm_prog_data} <= 2'b00;
			if (dcm_progstate == 5'd11) {dcm_prog_en, dcm_prog_data} <= 2'b00;
			if (dcm_progstate == 5'd12) {dcm_prog_en, dcm_prog_data} <= 2'b00;

			if (dcm_progstate == 5'd13) {dcm_prog_en, dcm_prog_data} <= 2'b11;
			if (dcm_progstate == 5'd14) {dcm_prog_en, dcm_prog_data} <= 2'b11;

			if (dcm_progstate == 5'd23) {dcm_prog_en, dcm_prog_data} <= 2'b00;
			if (dcm_progstate == 5'd24) {dcm_prog_en, dcm_prog_data} <= 2'b00;
			if (dcm_progstate == 5'd25) {dcm_prog_en, dcm_prog_data} <= 2'b10;
			if (dcm_progstate == 5'd26) {dcm_prog_en, dcm_prog_data} <= 2'b00;

			if (dcm_progstate <= 5'd25) dcm_progstate <= dcm_progstate + 5'd1;

			if (dcm_progstate == 5'd26 && dcm_prog_done)
				dcm_progstate <= 5'd31;
		end
endmodule
