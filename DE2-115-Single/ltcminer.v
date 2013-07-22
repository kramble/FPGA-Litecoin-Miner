/* ltcminer.v
*
* Copyright (c) 2013 kramble
* Parts copyright (c) 2011 fpgaminer@bitcoin-mining.com
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
* 
*/

`timescale 1ns/1ps

module ltcminer (osc_clk);		// Version without LEDs

// module ltcminer (osc_clk, LEDS_out);
	
	input osc_clk;
	// output [7:0]LEDS_out;			// Optional progress indicator

	wire hash_clk;
	`ifndef SIM
		main_pll pll_blk (osc_clk, hash_clk);
	`else
	 	assign hash_clk = osc_clk;
	`endif
	
	wire [31:0] nonce_out;
	
	wire [3:0] nonce_msb = 4'd0;	// Multiple cores use different prefix
	
	hashcore uut (hash_clk, nonce_msb, nonce_out);

	// assign LEDS_out = nonce_out[15:8];			// Optional progress indicator
			
endmodule
