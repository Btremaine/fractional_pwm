// Module     : BLDC_bench.v                                                           
// Description: This is the top level stimulus module for testing 
// the module frac_pwm.v with a BLDC closed loop architecture
// Brian Tremaine 
// Nov 21, 2018
//
// Project Name:   	 
// Target Devices:	Spartan 3AN XC3S50ATQ144  	
// Tool versions: 
// Description:    	Prototype Fractional divider.
//
// Dependencies:    This file designed to work on PCBA 341-00250-00 Rev 01 
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
`include "..\include\timescale.v"
`include "..\include\defines.v"
//-----------------------------------------------------------------------
module  BLDC_bench;

// IO Ports
// parameter DLIM = 6000; // 21'H0E4E1C
// --------------------------------------------------------------------------------------------------------

reg clk1;
reg reset_n;
reg [2:0] brd_id;
reg ale;
reg FgIn;

wire tp31;

// --------------------------------------------------------------------------------------------------------
// Instantiate top level 
	Top_Frac_pwm Top_Frac_pwm1(
			.CLK1		(clk1),   //--------------------- system clock 100Mc (xtal)
			.RESET_N	(reset_n),//--------------------- fpga reset from IBUF
			.ALE	(ale),//--------------------- ALE not used
			.BRD_ID	(brd_id),//---------------- Board ID bits [2:0]
			.TP31	(tp31),  //---------------------- TP31 : fgIn input ~360Hz
			// outputs,               
			.D2	(d1),//------------------------- LED D2 tp
			.D3	(d2),//------------------------- LED D3 tp
			.D4	(d4),//------------------------- LED D4 TP
			.TP29	(tp29), //---------------------- TP29 : fgFb	  ~60Hz
			.TP32	(tp32), //---------------------- TP32 : pwm
			.TP28	(tp28), //---------------------- TP28 : pd_error
			.TP33	(tp33)   //----------------------TP33 : Fref    ~60Hz
    );

assign fgFb = tp29;
assign pwm = tp32;
assign pd_error = tp28;
assign Fref = tp33;

assign tp31 = FgIn;




always begin
     #5 clk1 = !clk1;     	         // ~100.0MHz
end

always begin
    #1_136_364 FgIn = !FgIn; // 360Hz motor (make 440Hz)
end


initial begin
       `ifdef Veritak
        $dumpvars;
       `endif
  
#0   	reset_n = 0;
		brd_id[2:0] = 3'b110;
		ale = 0;				// not used in this design
		FgIn = 0;   // fgIn

#50 	clk1 = 0;
#50 	reset_n = 1;


#500_000_000 $finish ;
end


endmodule