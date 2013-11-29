`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// HashVoodoo Top Module
// Paul Mumby 2012
//////////////////////////////////////////////////////////////////////////////////
module HASHVOODOO (
		clk_p, 
		clk_n, 
		clk_comm, 
		RxD, 
		TxD, 
		led, 
		dip, 
		reset_a, 
		reset_b, 
		reset_select
	);

	function integer clog2;		// Courtesy of razorfishsl, replaces $clog2()
		input integer value;
		begin
		value = value-1;
		for (clog2=0; value>0; clog2=clog2+1)
		value = value>>1;
		end
	endfunction

	//Parameters:
	//================================================
	parameter CLOCK_RATE = 25000000;					//Input Clock Output from Controller in Hz
	parameter DCM_DIVIDER = 10;						//Starting point for DCM divider (25Mhz / 10 = 2.5Mhz increments)
	parameter DCM_MULTIPLIER_START = 70;			//Starting point for DCM multiplier (2.5Mhz x 70 = 175Mhz)
	parameter DCM_MULTIPLIER_CAP = 120;				//Max Point Allowed for DCM multiplier (Safety ceiling) - KRAMBLE now 300MHz
	parameter DCM_MULTIPLIER_MIN = 20;				//Minimum Allowed for DCM multiplier (If it falls below this something is seriously wrong)
	parameter UART_BAUD_RATE = 115200;				//Baud Rate to use for UART (BPS)
	parameter UART_SAMPLE_POINT = 8;					//Point in the oversampled wave to sample the bit state for the UART (6-12 should be valid)
	parameter CLOCK_FLASH_BITS = 26;					//Number of bits for divider of flasher. (28bit = approx 67M Divider)

// `define DUALCORE					// Comment out for single core (dual core does not currently route)

`ifdef DUALCORE
	localparam LOCAL_MINERS = 2;	// One or two cores (configures ADDRBITS automatically)
`else
	localparam LOCAL_MINERS = 1;	// One or two cores (configures ADDRBITS automatically)
`endif

	localparam ADDRBITS = 12 - clog2(LOCAL_MINERS);	// Automatically selects largest RAM that will fit LX150
	localparam SBITS = 8;		// Shift data path width
	
	//IO Definitions:
	//================================================
   input clk_p;			//Input Clock From Controller (P signal of diff pair)
   input clk_n;			//Input Clock From Controller (N signal of diff pair)
   input clk_comm;		//Input Comm Clock From Controller (Single ended)
   input RxD;				//UART RX Pin (From Controller)
   output TxD;				//UART TX Pin  (To Controller)
   output [3:0] led;		//LED Array
	input [3:0]dip;		//DIP Switch Array
	input reset_a;			//Reset Signal A (position dependant) from Controller
	input reset_b;			//Reset Signal B (position dependant) from Controller
	input reset_select;	//Reset Selector (hard wired based on position)

	//Register/Wire Definitions:
	//================================================
	reg reset;								//Actual Reset Signal
	wire clk_buf;							//Actually Used Clock Signals
	wire clk_dcm;							//Output of hash clock DCM
	wire clk_comm_buf;
	wire clock_flash;						//Flasher output (24bit divider of clock)
	wire miner_busy;						//Miner Busy Flag
	wire serial_send;						//Serial Send flag, Triggers UART to begin sending what's in it's buffer
	wire serial_busy;						//Serial Busy flag, Indicates the UART is currently working
	wire [31:0] golden_nonce;				//Overall Found Golden Nonce
	wire [255:0] data1, data2;
	wire [127:0] data3;
	wire start_mining;						//Start Mining flag. This flag going high will trigger the worker to begin hashing on it's buffer
	wire syncstart_mining;					//Clock crossing (redirected from reset_a in simulation)
	reg syncstart_mining_d = 1'b0;
	wire led_nonce_fade;					//This is the output from the fader, jumps to full power when nonce found and fades out
	wire led_serial_fade;					//Output from fader for serial activity.
	wire dcm_prog_en;
	wire dcm_prog_data;
	wire dcm_prog_done;
	wire dcm_valid;
	wire dcm_reset = 1'b0;
	wire identify_flag;
	wire identify_flasher;
	
	reg [3:0] syncticket1 = 0;				//Clock domain sync
	wire got_ticket1;						//Got Ticket flag indicates the local worker found a new nonce.
`ifdef DUALCORE
	wire [63:0] slave_nonces;				//Nonce found by worker
	reg [1:0] new_nonces;					//Flag indicating new nonces found
	reg [3:0] syncticket2 = 0;
	wire got_ticket2;
`else
	wire [31:0] slave_nonces;
	reg [0:0] new_nonces;					//Flag indicating new nonces found
`endif

	//Assignments:
	//================================================
	// KRAMBLE swapped blue and geen leds as blue is far brighter and better as nonce indicator
	assign led[0] = (led_serial_fade || identify_flasher);				//LED0 (Green): UART Activity (blinks and fades on either rx or tx)
	assign led[1] = (clock_flash || ~dcm_valid || identify_flasher);	//LED1 (Red): Clock Heartbeat (blinks to indicate working input clock)
																		//		Off = no clock
																		//		On Solid = dcm invalid.
	assign led[2] = (led_nonce_fade || identify_flasher);				//LED2 (Blue): New Nonce Beacon (fader)
	assign led[3] = (~miner_busy || identify_flasher);					//LED3 (Amber): Idle Indicator. Lights when miner has nothing to do.
	assign identify_flasher = (clock_flash && identify_flag);			//Identify Mode (ALL LEDs flash with heartbeat)
	
	//Module Instantiation:
	//================================================

`ifndef SIM	
	//LVDS Clock Buffer
	IBUFGDS #(
			.DIFF_TERM("TRUE"),
			.IOSTANDARD("DEFAULT")
		) CLK_LVDS_BUF (
			.O(clk_buf),
			.I(clk_p),	//Diff_p clock input
			.IB(clk_n)	//Diff_n clock input
		);
	
	//Comm Clock Buffer
	BUFG CLK_COMM_BUF
		(
			.I   (clk_comm),
			.O   (clk_comm_buf)
		);

	//Dynamically Programmable Hash Clock DCM
	main_dcm #(
			.DCM_DIVIDER(DCM_DIVIDER),
			.DCM_MULTIPLIER(DCM_MULTIPLIER_START)
		) MAINDCM(
			.RESET(dcm_reset),
			.CLK_VALID(dcm_valid),
			.CLK_OSC(clk_buf), 
			.CLK_HASH(clk_dcm),			// KRAMBLE now divide 4 (typically 50MHz for nominal 200MHz)
			.PROGCLK(clk_comm_buf),
			.PROGDATA(dcm_prog_data),
			.PROGEN(dcm_prog_en),
			.PROGDONE(dcm_prog_done)
		);
`else
	assign clk_buf = clk_p;
	assign clk_dcm = clk_buf;
	assign clk_comm_buf = clk_comm;
`endif

	//DCM Controller Core (controls dcm clock based on special (malformed) icarus work packets which act as "command" packets
	dcm_controller #(
			.MAXIMUM_MULTIPLIER(DCM_MULTIPLIER_CAP),
			.MINIMUM_MULTIPLIER(DCM_MULTIPLIER_MIN),
			.INITIAL_MULTIPLIER(DCM_MULTIPLIER_START),
			.INITIAL_DIVIDER(DCM_DIVIDER)
		) DCM_CONTROL (
			.clk(clk_comm_buf),
			.data2({data2[255:96], data3[95:0]}),	// KRAMBLE Align with timestamp field in data3
			.midstate(data1),						// KRAMBLE all zero's for valid command packet
			.start(start_mining),
			.dcm_prog_clk(clk_comm_buf),
			.dcm_prog_en(dcm_prog_en),
			.dcm_prog_data(dcm_prog_data),
			.dcm_prog_done(dcm_prog_done),
			.identify(identify_flag)
		);
	
	//Hub core, this is a holdover from Icarus. KRAMBLE: now in use since multiple hasher cores.
   hub_core #(
			.SLAVES(LOCAL_MINERS)
		) HUBCORE (
			.hash_clk(clk_comm_buf), 
			.new_nonces(new_nonces), 
			.golden_nonce(golden_nonce), 
			.serial_send(serial_send), 
			.serial_busy(serial_busy), 
			.slave_nonces(slave_nonces)
		);
	
	//New Serial Core. Handles all communications in and out to the host.
	wire unused_rx_busy;
	
	serial_core #(
			.CLOCK(CLOCK_RATE),
			.BAUD(UART_BAUD_RATE),
			.SAMPLE_POINT(UART_SAMPLE_POINT)
		) SERIAL_COMM (
			.clk(clk_comm_buf),
			.rx(RxD),
			.tx(TxD),
			.rx_ready(start_mining),
			.tx_ready(serial_send),
			.data1(data1),
			.data2(data2),
			.data3(data3),
			.word(golden_nonce),
			.tx_busy(serial_busy),
			.rx_busy(unused_rx_busy)
		);
	
	wire [31:0] unused_nonce_out1, unused_hash_out1;
	wire [31:0] unused_nonce_out2, unused_hash_out2;
	
	// NB For now using same clk for both P and S

	reg loadnonce = 1'b0;	// Generate loadnonce strobe for new work (NB this initiates a full engine reset)
	reg [3:0]syncloadnonce = 3'd0;

	wire [31:0] mod_target = 32'h00007fff;			// Hard coded for diff=2

	wire gn_match_1;
	wire [31:0] golden_nonce_1;
	wire [31:0] hash_1, nonce_out_1;				// nonce_out_1 used for miner_busy
	wire salsa_busy_1, salsa_result_1, salsa_reset_1, salsa_start_1, salsa_shift_1;
	wire [SBITS-1:0] salsa_din_1;
	wire [SBITS-1:0] salsa_dout_1;

	pbkdfengine #(.SBITS(SBITS)) P1
		(.hash_clk(clk_dcm), .pbkdf_clk(clk_dcm), .data1(data1), .data2(data2), .data3(data3), .target(mod_target),
		.nonce_msb( 4'd0 ), .nonce_out(nonce_out_1), .golden_nonce_out(golden_nonce_1),
		.golden_nonce_match(gn_match_1), .loadnonce(loadnonce),
		.salsa_din(salsa_din_1), .salsa_dout(salsa_dout_1), .salsa_busy(salsa_busy_1), .salsa_result(salsa_result_1),
		.salsa_reset(salsa_reset_1), .salsa_start(salsa_start_1), .salsa_shift(salsa_shift_1), .hash_out(hash_1));

	salsaengine #(.ADDRBITS(ADDRBITS), .SBITS(SBITS)) S1
		(.hash_clk(clk_dcm), .reset(salsa_reset_1), .din(salsa_din_1), .dout(salsa_dout_1),
		.shift(salsa_shift_1), .start(salsa_start_1), .busy(salsa_busy_1), .result(salsa_result_1) );

`ifdef DUALCORE
	wire gn_match_2;
	wire [31:0] golden_nonce_2;
	wire [31:0] hash_2, nonce_out_2;				// both unused
	wire salsa_busy_2, salsa_result_2, salsa_reset_2, salsa_start_2, salsa_shift_2;
	wire [SBITS-1:0] salsa_din_2;
	wire [SBITS-1:0] salsa_dout_2;

	pbkdfengine #(.SBITS(SBITS)) P2
		(.hash_clk(clk_dcm), .pbkdf_clk(clk_dcm), .data1(data1), .data2(data2), .data3(data3), .target(mod_target),
		.nonce_msb( 4'd8 ), .nonce_out(nonce_out_2), .golden_nonce_out(golden_nonce_2),
		.golden_nonce_match(gn_match_2), .loadnonce(loadnonce),
		.salsa_din(salsa_din_2), .salsa_dout(salsa_dout_2), .salsa_busy(salsa_busy_2), .salsa_result(salsa_result_2),
		.salsa_reset(salsa_reset_2), .salsa_start(salsa_start_2), .salsa_shift(salsa_shift_2), .hash_out(hash_2));

	salsaengine #(.ADDRBITS(ADDRBITS), .SBITS(SBITS)) S2
		(.hash_clk(clk_dcm), .reset(salsa_reset_2), .din(salsa_din_2), .dout(salsa_dout_2),
		.shift(salsa_shift_2), .start(salsa_start_2), .busy(salsa_busy_2), .result(salsa_result_2) );

	assign got_ticket1 = gn_match_1;
	assign got_ticket2 = gn_match_2;
	assign slave_nonces = { golden_nonce_2 , golden_nonce_1 };
`else
	// Single core
	assign got_ticket1 = gn_match_1;
	assign slave_nonces = golden_nonce_1;
`endif

	assign miner_busy = ~ (|nonce_out_1[30:20]);	// Set idle if nonce > 1M (ignore MSB)

	//Flasher, this handles dividing down the comm clock by 24bits to blink the clock status LED
	flasher #(
			.BITS(CLOCK_FLASH_BITS)
		) CLK_FLASH (
			.clk(clk_dcm),
			.flash(clock_flash)
		);
	
	//Nonce PWM Fader core. This triggers on a new nonce found, flashes to full brightness, then fades out for nonce found LED.
	pwm_fade PWM_FADE_NONCE (
			.clk(clk_comm_buf), 
			.trigger(|new_nonces), 
			.drive(led_nonce_fade)
		);	

	//Serial PWM Fader core. This triggers on a new nonce found, flashes to full brightness, then fades out for nonce found LED.
	pwm_fade PWM_FADE_COMM (
			.clk(clk_comm_buf), 
			.trigger(~TxD || ~RxD), 
			.drive(led_serial_fade)
		);	
	
	// Clock Crossing

`ifdef SIM	
	assign syncstart_mining = reset_a;			// Used only for simulation
`else
	assign syncstart_mining = start_mining;
`endif

	always@ (posedge clk_dcm)
		begin
			if (got_ticket1)
				syncticket1[0] <= ~syncticket1[0];
`ifdef DUALCORE
			if (got_ticket2)
				syncticket2[0] <= ~syncticket2[0];
`endif
			syncloadnonce[3:1] <= syncloadnonce[2:0];
			loadnonce <= (syncloadnonce[3] != syncloadnonce[2]);
		end

	always@ (posedge clk_comm_buf)
		begin
			syncticket1[3:1] <= syncticket1[2:0];
			new_nonces[0] <= (syncticket1[3] != syncticket1[2]);
`ifdef DUALCORE
			syncticket2[3:1] <= syncticket2[2:0];
			new_nonces[1] <= (syncticket2[3] != syncticket2[2]);
`endif
		syncstart_mining_d <= syncstart_mining;
		if (syncstart_mining & ~syncstart_mining_d)
			syncloadnonce[0] <= ~ syncloadnonce[0];
		end

endmodule

