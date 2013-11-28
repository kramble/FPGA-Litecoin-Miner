module hub_core (hash_clk, new_nonces, golden_nonce, serial_send, serial_busy, slave_nonces);
   parameter SLAVES = 2;

   input hash_clk;
   
   input [SLAVES-1:0] new_nonces;
   input [SLAVES*32-1:0] slave_nonces;
   output [31:0] 	 golden_nonce;
   output 		 serial_send;
   input 		 serial_busy;

   reg 			 serial_send_reg;
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
   reg [SLAVES*32-1:0] 	    slave_nonces_shifted;
   assign golden_nonce = slave_nonces_shifted[31:0];

   // When sending, mark nonces to be cleared during next clock cycle
   reg [SLAVES-1:0] 	    clear_nonces;
   
   always @(posedge hash_clk)
     begin
	// Raise flags when new nonces appear; lower those that have
	// been sent
	new_nonces_flag <= (new_nonces_flag & ~clear_nonces) | new_nonces;

	if (port_counter == SLAVES-1)
	  port_counter <= 0;
	else
	  port_counter <= port_counter + 1;
	
	// Send results one at a time, mark to be cleared
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
