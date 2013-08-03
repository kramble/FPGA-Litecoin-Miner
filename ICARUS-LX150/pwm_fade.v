// When triggered, turn the output to maximum and start fading to black

// by teknohog

module pwm_fade (clk, trigger, drive);
   input trigger;
   input clk;
   output drive;

   `define FADE_BITS 27
   parameter LEVEL_BITS = 8;

   // Average block interval in clock cycles is
   // 2**32 / (clk * 0.5**ll2 * miners) * clk
   // where (clk * 0.5**ll2 * miners) is the hashrate
   parameter LOCAL_MINERS = 1;
   //parameter LOOP_LOG2 = 5;
   //localparam FADE_BITS = 32 + LOOP_LOG2 - $clog2(LOCAL_MINERS);

   // Xilinx ISE 13.2 cannot handle $clog2 in localparam, but it works
   // in the index
   //`define FADE_BITS (32 + LOOP_LOG2 - $clog2(LOCAL_MINERS))
   
   reg [LEVEL_BITS-1:0] pwm_counter = 0;
   always @(posedge clk) pwm_counter = pwm_counter + 1;

   reg [`FADE_BITS-1:0] fade_counter = 0;
   always @(posedge clk)
     if (trigger) fade_counter = 0 - 1;
     else if (|fade_counter) fade_counter = fade_counter - 1;
   
   // For some reason, {FADE_BITS{1}} sets the register to zero, but
   // 0-1 works. Also, it needs to be explicitly initialized to
   // zero. Could be just a Nexys2 quirk, as these LEDs are routed to
   // general I/O pins too.
     
   wire [LEVEL_BITS-1:0] level;
   assign level = fade_counter[`FADE_BITS-1:`FADE_BITS-LEVEL_BITS];

   // With <= we cannot have true zero; with < we cannot have full
   // brightness. This is a rather fundamental problem, since we need
   // 256 timeslices to fill the whole, but the choice of "off" would
   // require an extra bit... of course, it is possible to get by
   // using a little extra logic.
   assign drive = (pwm_counter < level);
   
endmodule
