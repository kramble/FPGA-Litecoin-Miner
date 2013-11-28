// file: main_dcm.v
// 
// (c) Copyright 2008 - 2011 Xilinx, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
//----------------------------------------------------------------------------
// User entered comments
//----------------------------------------------------------------------------
// None
//
//----------------------------------------------------------------------------
// "Output    Output      Phase     Duty      Pk-to-Pk        Phase"
// "Clock    Freq (MHz) (degrees) Cycle (%) Jitter (ps)  Error (ps)"
//----------------------------------------------------------------------------
// CLK_OUT1___800.000______0.000_______N/A______205.000________N/A
//
//----------------------------------------------------------------------------
// "Input Clock   Freq (MHz)    Input Jitter (UI)"
//----------------------------------------------------------------------------
// __primary__________25.000____________0.010

`timescale 1ps/1ps

(* CORE_GENERATION_INFO = "main_dcm,clk_wiz_v4_1,{component_name=main_dcm,use_phase_alignment=false,use_min_o_jitter=false,use_max_i_jitter=false,use_dyn_phase_shift=false,use_inclk_switchover=false,use_dyn_reconfig=true,feedback_source=FDBK_AUTO,primtype_sel=DCM_CLKGEN,num_out_clk=1,clkin1_period=40.000,clkin2_period=40.000,use_power_down=false,use_reset=true,use_locked=false,use_inclk_stopped=false,use_status=false,use_freeze=false,use_clk_valid=true,feedback_type=SINGLE,clock_mgr_type=MANUAL,manual_override=true}" *)
module main_dcm
 (// Clock in ports
  input         CLK_OSC,
  // Clock out ports
  output        CLK_HASH,
  // Dynamic reconfiguration ports
  input         PROGCLK,
  input         PROGDATA,
  input         PROGEN,
  output        PROGDONE,
  // Status and control signals
  input         RESET,
  output        CLK_VALID
 );

	parameter DCM_DIVIDER = 10;	
	parameter DCM_MULTIPLIER = 60;

  // Input buffering
  //------------------------------------
  BUFG clkin1_buf
   (.O (clkin1),
    .I (CLK_OSC));
	 
  // Clocking primitive
  //------------------------------------
  // Instantiation of the DCM primitive
  //    * Unused inputs are tied off
  //    * Unused outputs are labeled unused
  wire        locked_int;
  wire [2:1]  status_int;
  wire        clkfx;
  wire        clkfx180_unused;
  wire        clkfx_unused;			// KRAMBLE was clkfxdv_unused

  DCM_CLKGEN
  #(.CLKFXDV_DIVIDE        (4),					// KRAMBLE approx 50Mhz dcm_clk (for nominal 200MHz)
    .CLKFX_DIVIDE          (DCM_DIVIDER),
    .CLKFX_MULTIPLY        (DCM_MULTIPLIER),
    .SPREAD_SPECTRUM       ("NONE"),
    .STARTUP_WAIT          ("FALSE"),
    .CLKIN_PERIOD          (40.000),
    .CLKFX_MD_MAX          (0.000))
   dcm_clkgen_inst
    // Input clock
   (.CLKIN                 (clkin1),
    // Output clocks
    .CLKFX                 (clkfx_unused),
    .CLKFX180              (clkfx180_unused),
    .CLKFXDV               (clkfx),				// KRAMBLE now using divided output
    // Ports for dynamic reconfiguration
    .PROGCLK               (PROGCLK),
    .PROGDATA              (PROGDATA),
    .PROGEN                (PROGEN),
    .PROGDONE              (PROGDONE),
    // Other control and status signals
    .FREEZEDCM             (1'b0),
    .LOCKED                (locked_int),
    .STATUS                (status_int),
    .RST                   (RESET));

    assign CLK_VALID = ( ( locked_int == 1'b 1 ) && ( status_int[2] == 1'b 0 ) );

  // Output buffering
  //-----------------------------------

  BUFG clkout1_buf
   (.O   (CLK_HASH),
    .I   (clkfx));

endmodule
