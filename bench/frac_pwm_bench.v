// Module     : frac_pwm_bench                                                            
// Description: This is the top level stimulus module for testing 
// the module frac_pwm.v
// Brian Tremaine 
// Nov 6, 2018
//
// target hardware:
// Dev board:
// Fosc:
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
`include "..\include\timescale.v"
`include "..\include\defines.v"
//-----------------------------------------------------------------------
module  frac_pwm_bench;

// IO Ports
// --------------------------------------------------------------------------------------------------------
reg rstn;
reg [16:0] N;
reg [16:0] mf;
reg [16:0] No;
wire [16:0] count;

// --------------------------------------------------------------------------------------------------------
// Instantiate top level 

	frac_pwm frac_pwm1 (
	// inputs
	.sys_clk		(sys_clk),      // system clock
	.sync_rst_n		(rstn),			// active low reset
	.No             (No),           // pwm period divider
	.N				(N),		    // pwm integer value
	.mf				(mf),		    // pwm fractional value ...yyyyy.xxxx
	// outputs
	.count			(count),	    // instantaneous count
	.q_out			(q_out)			// pwm output pulse
	);
// ========================================================


reg sys_clk;
integer i;  

always begin
     #5 sys_clk = !sys_clk;     // ~100.0MHz
end


initial begin
       `ifdef Veritak
        $dumpvars;
       `endif
// bench test generate 25kHz clock with fractional pwm 

#0  rstn = 0;
#20 sys_clk = 0;
#20 No = 4000;
#20 N = 2000;
#50 rstn = 1;
//
#50 mf = 1;

#300_000 $finish ;
end

endmodule