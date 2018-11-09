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
module Top_VsyncFilter(
			// inputs
			input CLK1,//----------------------- system clock 100Mc (xtal)
			input RESET_N,//-------------------- fpga reset from IBUF
			input ALE, //----------------------- ALE not used
			input [2:0] BRD_ID,//--------------- Board ID bits [2:0]
			input vsyncIn,//-------------------  TP12 : Vsync input ~120Hz
			// outputs,               
			output D1,//------------------------- LED D1 tp
			output D2,//------------------------- LED D2 tp
			output TP7,//------------------------ TP7  : Fref    ~1080Hz
			output VsyncF,//--------------------- TP13 : VsyncF	  ~60Hz
			output Vsync2x, //------------------- TP14 : Vsync2x	 ~120Hz
			output TP15,//----------------------- TP15 : vsyncSrc  ~60Hz
			output TP6//------------------------- TP6  : 
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
   .CLKIN_IN   (CLK1),           // 100MHz xtal
   .RST_IN     (~RESET_N), 
   .CLKDV_OUT  (sp_clk),         // 50MHz output
   .CLKIN_IBUFG_OUT (), 
   .CLK0_OUT   (),    		   	// 100Mhz output
   .LOCKED_OUT ()
 ); 

`endif 
// --------------------------------------------------------------------

parameter M0 = 17'h10C8E; // 68750, nominal divider count,727.2Hz, (fosc/Fref)
parameter KI = 3'h6;
parameter KP = 3'h1;
parameter K0 = 3'h3;
parameter DLIM = 22'h04FFFF; // 22'h001770; // 22'h07FFFF; // integrator limit (signed)
parameter WIN= 10'h1FF;		  // window width
parameter WIDTH=17;
parameter WIDTH_ERR=22;
parameter N0 = 1237500;       // 21'h12E1FC Vsync period, 40.4Hz


reg [16:0] m0;
reg [2:0]  ki;
reg [2:0]  kp;
reg [2:0]  k0;
reg [21:0] dlim;
reg [9:0]  win_width;
reg [WIDTH_ERR-2:0] win_delay; // unsigned
reg [20:0] vsyncCnt;
reg [7:0] vsyncCount;
reg [4:0] vsyncSrcCnt;			// pulse display width

wire [WIDTH-1:0] Me;
wire sync_rst_n;
wire rst;
wire [WIDTH_ERR-1:0] Err;  // signed error
wire Venable;
wire sample;
wire vsyncClk;

// instantiate rst_gen
   rst_gen rst_gen1(
		.reset_n    	(RESET_N),	    // reset from IBUFF
		.clk        	(sp_clk), 		// master clock source
		.sync_rst_n     (sync_rst_n) 	// synchronized reset
		);

// instantiate (div-by N) counter, fractional pwm
	frac_pwm #(.WIDTH(17)) frac_pwm1(
	// inputs
	.sys_clk		(sp_clk),		// system master clock
	.sync_rst_n		(sync_rst_n),
	.No             (No),           // pwm period divider
	.N				(m0),		    // integer pwm
	.mf				(Me),			// fractional divide ...yyyyy.xxxx
	// outputs
	.count			(),
	.q_out			(Fref)			// pwm output
	);
		 

// handle Vsync enable here
assign vsyncSrc = (BRD_ID[2]==1'b1) ? vsyncClk: vsyncIn;	   // select vsync source
assign D1 = sample;
assign D2 = Venable;
assign TP15 = (vsyncSrcCnt!=0) ? 1'b1:1'b0;
assign TP7 = Fref;
assign TP6 = pd_error;
assign rst = ~sync_rst_n;


assign vsyncClk = ((vsyncCnt ==0) && (vsyncCount!=0)) ? 1'b1 : 1'b0;  // 20ns wide pulse
   
	always @ (posedge sp_clk) begin
		m0 <= M0;
	end
	
	// ================================================
	// stretch Vsync sources for display
	always @ (posedge sp_clk, posedge vsyncSrc) begin
		if(vsyncSrc)
			vsyncSrcCnt <= 24;		// 500ns wide pulse
		else if(vsyncSrcCnt !=0)
			vsyncSrcCnt <= vsyncSrcCnt - 1'b1;	
	end	
	
	// ================================================
	// Debug code
	// code to generate vsyncClk for debug (40Hz on dev board)
	always @ (posedge sp_clk, posedge rst) begin
		if(rst)
			vsyncCnt <= N0 - 1;
		else begin
			if(vsyncCnt != 0)
				vsyncCnt <= vsyncCnt -1;
			else
				vsyncCnt <= N0 - 40;  // s/b -1 (-2 works)
		end
	end
			
endmodule
