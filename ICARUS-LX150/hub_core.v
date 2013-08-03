module hub_core (uart_clk, new_nonces, golden_nonce, serial_send, serial_busy, slave_nonces);
   parameter SLAVES = 2;

   input uart_clk;
   
   input [SLAVES-1:0] new_nonces;
   input [SLAVES*32-1:0] slave_nonces;
   output [31:0] 	 golden_nonce;
   output 		 serial_send;
   input 		 serial_busy;

   // kramble - since using separate clocks for uart and hasher, we need clock crossing logic,
   // just synchronise the new_nonces flags (golden_nonce is held stable until next match)
   reg [SLAVES-1:0] new_nonces_d1 = 0;
   reg [SLAVES-1:0] new_nonces_d2 = 0;
   always @ (posedge uart_clk)
   begin
	new_nonces_d1 <= new_nonces;
	new_nonces_d2 <= new_nonces_d1;
   end
   
   reg 			 serial_send_reg = 0;
   assign serial_send = serial_send_reg;
  
   // Remember all nonces, even when they come too close together, and
   // send them whenever the uplink is ready
   reg [SLAVES-1:0] 	new_nonces_flag = 0;
   
   // Replace the tedious if-else chain for input ports with a
   // continuously running selector. This may seem slow/inefficient
   // for a large hub, but it is still insanely faster than the serial
   // port we are driving. Also, due to simplicity, it should be more
   // robust for big hubs with fast clocks.
   reg [$clog2(SLAVES)+1:0] port_counter = 0;
   reg [SLAVES*32-1:0] 	    slave_nonces_shifted = 0;
   assign golden_nonce = slave_nonces_shifted[31:0];

   // When sending, mark nonces to be cleared during next clock cycle
   reg [SLAVES-1:0] 	    clear_nonces = 0;
   
   always @(posedge uart_clk)
     begin
	// Raise flags when new nonces appear; lower those that have
	// been sent
	new_nonces_flag <= (new_nonces_flag & ~clear_nonces) | new_nonces_d2;

	if (port_counter == SLAVES-1)
	  port_counter <= 0;
	else
	  port_counter <= port_counter + 1;
	
	// Send results one at a time, mark to be cleared
	// kramble - the optimiser removes all but the low 32 bits of slave_nonces_shifted since
	// the following code implements a multiplexor on slave_nonces input, NOT an actual shifter.
	// This is also the behaviour of nghzang's github code, so I'm not going to change it.
	if (!serial_busy && new_nonces_flag[port_counter])
	  begin
	     slave_nonces_shifted <= slave_nonces >> port_counter*32;
	     serial_send_reg <= 1;
	     clear_nonces[port_counter] <= 1;
	  end
	else 
	  begin
	     serial_send_reg <= 0;
	     clear_nonces <= 0;
	  end
     end

endmodule // hub_core
