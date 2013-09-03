// by teknohog, replaces virtual_wire by rs232

// Now using fpgaminer's uart code instead of fpga4fun's. Besides
// GPL3, the practical difference is that instead of TxD_busy we have
// its inverse tx_ready.

module serial_receive # (
   parameter baud_rate = 115_200,
   parameter comm_clk_frequency = 100_000_000 )
  ( clk, RxD, data1, data2, data3, target, rx_done );
   input      clk;
   input      RxD;
   
   wire       RxD_data_ready;
   wire [7:0] RxD_data;


   `ifdef CONFIG_SERIAL_TIMEOUT
	parameter SERIAL_TIMEOUT = `CONFIG_SERIAL_TIMEOUT;
   `else
        // Timeout after 8 million clock at 100Mhz is 80ms, which should be
        // OK for all sensible clock speeds eg 20MHz is 400ms, 200MHz is 40ms
	parameter SERIAL_TIMEOUT = 24'h800000;
   `endif

   uart_receiver #(.comm_clk_frequency(comm_clk_frequency), .baud_rate(baud_rate)) urx (.clk(clk), .uart_rx(RxD), .tx_new_byte(RxD_data_ready), .tx_byte(RxD_data));
      
   output [255:0] data1;
   output [255:0] data2;
   output [127:0] data3;
   output [31:0] target;

   output reg rx_done = 1'b0;
   
   // 80 bytes data (including nonce) + 4 bytes target = 84 bytes / 672 bits
   
   reg [671:0] input_buffer = 0;
   reg [671:0] input_copy = 0;
   reg [6:0]   demux_state = 7'b0000000;
   reg [23:0]  timer = 0;

   // ltcminer.py sends target first then data
`ifdef SIM	// Sane data for simulation - NB disable if simulating serial data loading
   assign target = input_copy[671:640];		// Not needed since no RxD_data_ready strobe to load targetreg
   assign data1 = 256'h18e7b1e8eaf0b62a90d1942ea64d250357e9a09c063a47827c57b44e01000000;
   assign data2 = 256'hc791d4646240fc2a2d1b80900020a24dc501ef1599fc48ed6cbac920af755756;
   assign data3 = 128'h0000318f7e71441b141fe951b2b0c7df;	// NB 0000318f is loaded into nonce
`else   
   assign target = input_copy[671:640];
   assign data3 = input_copy[639:512];
   assign data2 = input_copy[511:256];
   assign data1 = input_copy[255:0];
`endif
   // kramble: changed this as clock crossing requires timing consistency so
   // rx_done is now registered and strobes in sync with the data output
   // hence the following is no longer true...
   // Needed to reset the nonce for new work. There is a 1-cycle delay
   // in the main miner loop, because reset only zeroes nonce_next, so
   // we can do this already at this stage.
   // assign rx_done = (demux_state == 7'd84);
   
   always @(posedge clk)
     case (demux_state)
       7'd84:				// 84 bytes loaded
	 begin
		rx_done <= 1;
	    input_copy <= input_buffer;
	    demux_state <= 0;
	 end
       
       default:
     begin
        rx_done <= 0;
	    if(RxD_data_ready)
	      begin
	         input_buffer <= input_buffer << 8;
             input_buffer[7:0] <= RxD_data;
             demux_state <= demux_state + 1;
	         timer <= 0;
	      end
	      else
	      begin
	         timer <= timer + 1;
	         if (timer == SERIAL_TIMEOUT)
	           demux_state <= 0;
	      end
     end // default
     endcase // case (demux_state)
   
endmodule // serial_receive

module serial_transmit # (
   parameter baud_rate = 115_200,
   parameter comm_clk_frequency = 100_000_000 )
  (clk, TxD, busy, send, word);
   
   // split 4-byte output into bytes

   wire TxD_start;
   wire TxD_ready;
   
   reg [7:0]  out_byte = 0;
   reg        serial_start = 0;
   reg [3:0]  mux_state = 4'b0000;

   assign TxD_start = serial_start;

   input      clk;
   output     TxD;
   
   input [31:0] word;
   input 	send;
   output 	busy;

   reg [31:0] 	word_copy = 0;
   
   assign busy = (|mux_state);

   always @(posedge clk)
     begin
	// Testing for busy is problematic if we are keeping the
	// module busy all the time :-/ So we need some wait stages
	// between the bytes.

	if (!busy && send)
	  begin
	     mux_state <= 4'b1000;
	     word_copy <= word;
	  end  

	else if (mux_state[3] && ~mux_state[0] && TxD_ready)
	  begin
	     serial_start <= 1;
	     mux_state <= mux_state + 1;

	     out_byte <= word_copy[31:24];
	     word_copy <= (word_copy << 8);
	  end
	
	// wait stages
	else if (mux_state[3] && mux_state[0])
	  begin
	     serial_start <= 0;
	     if (TxD_ready) mux_state <= mux_state + 1;
	  end
     end

   uart_transmitter #(.comm_clk_frequency(comm_clk_frequency), .baud_rate(baud_rate)) utx (.clk(clk), .uart_tx(TxD), .rx_new_byte(TxD_start), .rx_byte(out_byte), .tx_ready(TxD_ready));

endmodule // serial_send
