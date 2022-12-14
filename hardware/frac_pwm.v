`include "..\include\timescale.v"
`include "..\include\defines.v"
//////////////////////////////////////////////////////////////////////////////////
// Company:	Tremaine Consulting Group
// Engineer: 	Brian Tremaine
// 
// Create Date:    Nov. 6, 2018 
// Design Name: 
// Module Name:    frac_pwm 
// Project Name:
// Target Devices: Spartan 3AN XC3S50ATQ144 
// Tool versions: 
// Description:    fractional pwm
//                 Generate clock with constant period sys_clk/No. 
//			          Generate PWM signal high > Nf+1 counts for m-cycles and 
//                 high > Nf counts for M-m cycles. Average PWM count is Nf + m/M
//		             In this code Mbar is parameterized using fsze
//                 Count is bounded by [0 No] (0-100% duty cycle)
//                 Output q is high for period_cnt > Ni otherwise q is low.
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module frac_pwm #(parameter WIDTH = 17, parameter fsze = 6) (
	// inputs
	input sys_clk,
	input sync_rst_n,
	input [WIDTH-1:0] No,			// period divider	
	input [WIDTH-1:0] N,			// default center pwm value
	input signed [WIDTH-1:0] mf,	// fractional pwm ...yyyyy.xxx
	// outputs
	output [WIDTH-1:0] count, 	// ?? debug ??
	output q_out					// pwm output
    );

localparam MSB = WIDTH-1;

reg [WIDTH-1:0] ncoarse;
reg [WIDTH-1:0] Mreg;
reg [fsze-1:0] mcnt;
reg [WIDTH-1:0] period_cnt;
reg signed [WIDTH-1:0] mfs4;
reg signed [WIDTH-1:0] R1;

wire rst;
wire [fsze-1:0] nfine;

// initialize
initial begin
	mcnt[fsze-1:0] = 0;
	end
	
// assign
	assign q_out = (Mreg!=0) ? 1'b1 : 1'b0;
	assign count = Mreg;
	assign rst = ~sync_rst_n;
	assign nfine = mf[fsze-1:0] ;

////// limit ncoarse to [0 No]
always @(posedge sys_clk) begin
     mfs4 <= mf >>> fsze;
end
always @ (posedge sys_clk) begin
     R1 <= (mf[MSB]) ? (N - (~mfs4+1)) : (N + mfs4);
end
always @ (posedge sys_clk) begin
	ncoarse <= (R1[MSB]) ? 0 : 
				 (R1 > No) ? No: R1;
end

// --------------------------------------------------
// --------------------------------------------------
    always @(negedge sys_clk, posedge rst) begin       // constant period counter
        if(rst)                                        // generates fixed frequency 
		    period_cnt <= 0;
		else begin
		    if(period_cnt !=0)
			   period_cnt <= period_cnt - 1'b1;
			else
			   period_cnt <= No;
		end
	 end
	 
// ---------------------------------------------------
// ---------------------------------------------------
	
	always @(negedge sys_clk, posedge rst) begin		// mcnt register
		if(rst)                                      // generates M count windows {M-1:0]
			mcnt <= 0;
		else begin
				if(period_cnt==0) begin
					if(mcnt!=0)
						mcnt <= mcnt-1;
					else
						mcnt <= (1 << fsze) - 1;
				end
		end
	end
	
// ----------------------------------------------------
// ----------------------------------------------------
	
	always @(negedge sys_clk, posedge rst) begin		// M register
		if (rst)                                     // counts N or N+1 depending on
			Mreg <= N-1;                              // on mcnt < nfine
		else begin
				if(Mreg !=0) 
					Mreg <= Mreg - 1'b1;
				else if(period_cnt==0) begin
				    if( mcnt < nfine)
				    begin
					Mreg <= ncoarse + 1'b1;
					end
				else begin
					Mreg <= ncoarse; 
					end
				end
		end			
	end

endmodule
