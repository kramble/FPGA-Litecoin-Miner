// sim_ram.v - identical to xilinx_ram.v (use for altera simulation to avoid
// the need to specify library path for the altsyncram)

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

	reg [255:0] store [(2 << (ADDRBITS-1))-1:0];
	reg[ADDRBITS-1:0] raddr_reg;
	
	always @ (posedge clock)
	begin
		raddr_reg <= raddr;
		if (wren)
			store[waddr] <= data;
	end
	
	assign q = store[raddr_reg];
			
endmodule