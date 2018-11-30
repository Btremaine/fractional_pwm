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
			input TP31,  //---------------------- TP31 : fgIn input ~360Hz
			// outputs,               
			output D2,//------------------------- LED D2 tp
			output D3,//------------------------- LED D3 tp
			output D4,//------------------------- LED D4 TP
			output TP29, //---------------------- TP29 : fgFb	  ~60Hz
			output TP32, //---------------------- TP32 : pwm
			output TP28, //---------------------- TP28 : pd_error
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
   .CLK0_OUT   (),    		   // 100Mhz output
   .LOCKED_OUT ()
 ); 

`endif 
// --------------------------------------------------------------------
parameter FSZE = 3;
parameter KI = 3'h4;
parameter KP = 3'h0;
parameter K0 = 3'h7;

parameter DLIM = 22'h000FFF; // integrator limit (signed) 22'h04FFFF
parameter WIN= 9'h1FF;		  // window width 9'h1FF is max
parameter WIDTH=17;
parameter WIDTH_ERR=22;
parameter Nref = 833333; 	// 20'hCB735 Fref period, 60.0Hz
parameter N0 = 2000; 		// 12'h7D0 pwm period 25kHz
parameter M0 =  950; 		// pwm default center point @Me==0


reg [16:0] m0;
reg [FSZE-1:0]  ki;
reg [FSZE-1:0]  kp;
reg [FSZE-1:0]  k0;
reg [WIDTH-1:0] no;				// pwm frequency divider
reg [21:0] dlim;
reg [9:0]  win_width;				// set window width
reg [WIDTH_ERR-2:0] win_delay;	// set window delay
reg [20:0] M;						// Fref counter

wire [WIDTH-1:0] Me;
wire sync_rst_n;
wire [WIDTH_ERR-1:0] Err;  // signed error
wire Venable;
wire sample;
wire pd_error;
wire fgFb;
wire pwm;
wire fgIn_sync;
wire Fref;
wire [WIDTH-1:0] pwm_in;


// instantiate rst_gen
   rst_gen rst_gen1(
		// inputs
		.reset_n    	(RESET_N),	    // reset from IBUFF
		.clk        	(sp_clk), 		 // master clock source
		// outputs
		.sync_rst_n    (sync_rst_n) 	 // synchronized reset
		);

// instantiate debounce module
	debounce #(.DELAY(500))	debounce1(
			// Inputs
			.sync_rst_n	(sync_rst_n), 	// synchronized reset
			.clk			(sp_clk),		// master clock source
			.inpt			(fgIn),			// input signal
			// Outputs
			.outp			(fgIn_sync) 	// debounced output        
) ;

		
// instaniate fgFb counter (div-by-6)	
	down_cnt_sync #(.WIDTH(4)) down_cnt_sync1(
	   // inputs
		.sys_clk    (sp_clk),			// master clock source
		.clk_in		(fgIn_sync),		// input source clock
		.sync_rst_n (sync_rst_n),		// synchronized reset
		.N			   (4'h6),				// divide ratio
		// outputs
		.count		(),					// reg count value
		.q_out		(fgFb)			   // output
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
 compensate #(.WIDTH(17), .WIDTH_ERR(22), .fsze(FSZE)) compensate1(
     // inputs
    .sys_clk             (sp_clk),
    .rst                 (~sync_rst_n),
    .err                 (Err),
    .dlim                (dlim),				// user reg
    .ki                  (ki),				// user reg
    .kp                  (kp),            // user reg
    .k0                  (k0),				// user reg
    .enable		          (Venable),
    .process		       (sample),
     // outputs
    .uk			          (Me)
     );	 

// instantiate fractional pwm
	frac_pwm #(.WIDTH(17), .fsze(FSZE)) frac_pwm1(
	// inputs
	.sys_clk			(sp_clk),	// system master clock
	.sync_rst_n		(sync_rst_n),
	.N					(m0),			// default centerpoint at Me==0
	.No            (no),			// pwm period divide
	.mf				(pwm_in),	// signed fractional divide ...yyyyy.xxxx
	// outputs
	.count			(),
	.q_out			(pwm)			// pwm output
	);

// handle enable here:
//    D3|D2|D4
//     2 1 0
// BRD 1 0 x comp enabled & pwm 0%
//     1 1 x comp enabled & closed loop
//     0 1 x comp disabled & pwm default
//     0 0 x comp disabled & pwm 0%


assign D2 = (BRD_ID[1]==1'b1)? 1: 0;
assign D4 = (BRD_ID[0]==1'b1)? 1: 0;
assign Venable = (BRD_ID[2]==1'b1)? 1: 0;   // set comp Venable

assign D3 = Venable;

assign fgIn = TP31;
assign TP29 = fgFb;
assign TP32 = (D2) ? pwm: 1'b0;      // set pwm
assign TP33 = Fref; 
assign TP28 = pd_error; // (phase det window high)

assign pwm_in = (~Me+1);

assign Fref = (M < (Nref>>1) ) ? 1'b1: 1'b0;   // generate Fref

	always @ (posedge sp_clk) begin
		m0 <= M0;
		ki <= KI;
		kp <= KP;
		k0 <= K0;
           dlim <= DLIM;
		no <= N0;
		win_width <= WIN;
		win_delay <= Nref - (WIN>>1);
	end

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
