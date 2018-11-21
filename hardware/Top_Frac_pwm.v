`include "..\include\timescale.v"
`include "..\include\defines.v"
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Company: 	Tremaine Consulting Group.
// Engineer: 	Brian Tremaine
// 
// Create Date:    	Nov. 6, 2018 
// Design Name: 
// Module Name:    	Top_Frac_pwm
// Project Name:   	 
// Target Devices:	Spartan 3AN XC3S50ATQ144  	
// Tool versions: 
// Description:    	Prototype Fractional divider.
//
// Dependencies:    This file designed to work on PCBA 341-00250-00 Rev 01 
//						
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module Top_Frac_pwm(
			// inputs
			input CLK1,   //--------------------- system clock 100Mc (xtal)
			input RESET_N,//--------------------- fpga reset from IBUF
			input ALE,    //--------------------- ALE not used
			input [2:0] BRD_ID,//---------------- Board ID bits [2:0]
			input TP29,  //---------------------- TP29 : fgIn input ~360Hz
			// outputs,               
			output D2,//------------------------- LED D2 tp
			output D3,//------------------------- LED D3 tp
			output D4,//------------------------- LED D4 TP
			output TP31,  //--------------------- TP31 : fgFb	  ~60Hz
			output TP32,   //-------------------- TP32 : pwm
			output TP33  //---------------------- TP33 : Fref    ~60Hz
    );
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
`ifdef BENCH        // defined in defines.v for testbench simulation
wire dcm_lock ;
assign dcm_lock = 1'b1;

reg clk3;

initial 
  begin
  clk3 <= 0 ;
  end 
  
  always @ (posedge CLK1)
     clk3 <= ~clk3 ;
	  
 assign sp_clk = clk3 ;	// 50MHz

 //------------ DCM for implementation, not in testbench --------------
`else
dcm2 instance_name (
   .CLKIN_IN   (CLK1),        // 100MHz xtal
   .RST_IN     (~RESET_N), 
   .CLKDV_OUT  (sp_clk),      // 50MHz output
   .CLKIN_IBUFG_OUT (), 
   .CLK0_OUT   (),    		  // 100Mhz output
   .LOCKED_OUT ()
 ); 

`endif 
// --------------------------------------------------------------------

parameter KI = 3'h6;
parameter KP = 3'h1;
parameter K0 = 3'h3;
parameter DLIM = 22'h04FFFF; // integrator limit (signed)
parameter WIN= 10'h1FF;		  // window width
parameter WIDTH=17;
parameter WIDTH_ERR=22;
parameter Nref = 833333;     // 20'hCB735 Fref period, 60.0Hz
parameter N0 = 2000;         // 12'h7D0 pwm period 25kHz
parameter M0 =  N0 >>1;


reg [16:0] m0 =  M0;
reg [5:0]  ki =  KI;
reg [5:0]  kp =  KP;
reg [5:0]  k0 =  K0;
reg [WIDTH-1:0] no = N0;
reg [21:0] dlim = DLIM;
reg [9:0]  win_width;
reg [WIDTH_ERR-2:0] win_delay;// unsigned
reg [20:0] M;						// Fref counter

wire [WIDTH-1:0] Me;
wire sync_rst_n;
wire [WIDTH_ERR-1:0] Err;  // signed error
wire Venable;
wire sample;
wire fgFb;
wire pwm;


// instantiate rst_gen
   rst_gen rst_gen1(
		.reset_n    	(RESET_N),	    // reset from IBUFF
		.clk        	(sp_clk), 		 // master clock source
		.sync_rst_n    (sync_rst_n) 	 // synchronized reset
		);
		
// instaniate fgFb counter (div-by-6)	
	down_cnt_sync #(.WIDTH(4)) down_cnt_sync1(
	   // inputs
		.sys_clk    (sp_clk),			// master clock source
		.clk_in		(fgIn),				// input source clock
		.sync_rst_n (sync_rst_n),		// synchronized reset
		.N			   (4'h6),				// divide ratio
		// outputs
		.count		(),					// reg count value
		.q_out		(fgFb)			   // output
       );	

// instantiate fractional pwm
	frac_pwm #(.WIDTH(17)) frac_pwm1(
	// inputs
	.sys_clk		   (sp_clk),		// system master clock
	.sync_rst_n		(sync_rst_n),
	.No            (no),          // pwm period divider
	.N				   (m0),		      // integer pwm
	.mf				(Me),			   // fractional divide ...yyyyy.xxxx
	// outputs
	.count			(),
	.q_out			(pwm)			   // pwm output
	);
	
/// instantiate phase detector
 phase_det phase_det1(
    // inputs
	.clk        		(sp_clk),		// master clock source
	.sync_rst_n 		(sync_rst_n),	// synchronized reset
	.ref_phase  		(Fref),		   // input raw vsync
	.fb_phase   		(fgFb),		   // input feedback phase
	.delay_len  		(win_delay),	// user reg, window delay count
	.width_win  		(win_width),	// user reg, window width count
    // outputs
	.sample_out       (sample),
	.err        		(Err),          // error count
	.pd_error   		(pd_error)      // (RST signal, lost vsync)
    );

// instantiate compensation
 compensate compensate1(
     // inputs
    .sys_clk             (sp_clk),
    .rst                 (~sync_rst_n),
    .err                 (Err),
    .M0                  (m0),				// user reg, default divider
    .dlim                (dlim),				// user reg
    .ki                  (ki),				// user reg
    .kp                  (kp),            // user reg
    .k0                  (k0),				// user reg
    .enable		          (Venable),
    .process		       (sample),
     // outputs
    .uk			          (Me)
     );	 

// handle enable here:
//    D3|D2|D4
//     2 1 0
// BRD 1 0 x enabled & closed loop
//     1 1 x enabled & open loop
//     0 x x disabled

assign D3 = (BRD_ID[2]==1'b1)? 1: 0;
assign D2 = (BRD_ID[1]==1'b1)? 1: 0;
assign D4 = (BRD_ID[0]==1'b1)? 1: 0;
assign Venable = (D3 & ~D2)? 1: 0;   // set Venable

assign fgIn = TP29;
assign TP31 = fgFb;
assign TP32 = (D3) ? pwm: 1'b0;      // set pwm
assign TP33 = Fref; 

assign Fref = (M < (Nref>>1) ) ? 1'b1: 1'b0;   // generate Fref

	// Fref counter (generates 60Hz ref clock
	always @(posedge sp_clk) begin
		if(~sync_rst_n) begin
		   M <= Nref;
		end else begin
		   if (M<=0)
			  M <= Nref;
			else
			  M <= M -1'b1;
		end
	end

    // --------------------------------------
			
endmodule
