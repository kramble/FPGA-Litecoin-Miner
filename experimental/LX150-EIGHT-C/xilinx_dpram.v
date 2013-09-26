// xilinx_ram.v - inferring the ram seems to work fine

module ram # ( parameter ADDRBITS=10 ) (
	raddr,
	waddr,
	clock,
	data,
	wren,
	q);

	input	[ADDRBITS-1:0]  raddr;
	input	[ADDRBITS-1:0]  waddr;
	input	  clock;
	input	[255:0]  data;
	input	  wren;
	output	[255:0]  q;

	//synthesis attribute ram_style of store is block
	reg [255:0] store [(2 << (ADDRBITS-1))-1:0];
	reg[ADDRBITS-1:0] raddr_reg;
	reg[ADDRBITS-1:0] waddr_reg;
	
	always @ (posedge clock)
	begin
		raddr_reg <= raddr;
		(* S = "TRUE" *) waddr_reg <= waddr;	// Extra register on waddr (replaces wr_addr1_d externally) to see if it improves routing
		if (wren)
			store[waddr_reg] <= data;
	end
	
	assign q = store[raddr_reg];
			
endmodule