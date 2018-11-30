`include "..\include\timescale.v"
`include "..\include\defines.v"
//////////////////////////////////////////////////////////////////////////////////
// Company: 	Prysm Inc.
// Engineer: 	Brian Tremaine
// 
// Create Date:    13:59:01 04/27/2016 
// Design Name: 
// Module Name:    compensate 
// Project Name: 
// Target Devices:	Spartan 3AN XC3S50ATQ144  
// Tool versions: 
// Description: 	digital PI compensation for Denoise DPLL
//						Uses signed arithmetic and shift divides
//						User gains {ki,kp,ko} are in registers.
//                Calulations of difference eqt. are pipelined.
// Dependencies:	
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module compensate #(parameter WIDTH= 17, WIDTH_ERR=22, fsze = 6) (
	// input
	input sys_clk,								// system clock
	input rst,									// active high reset
	input signed [WIDTH_ERR-1:0] err,	// signed error
	input [WIDTH_ERR-1:0] dlim,
	input [fsze-1:0] ki,
	input [fsze-1:0] kp,
	input [fsze-1:0] k0,
	input enable,
	input process,
	// outputs
	output [WIDTH-1:0] uk
    );


localparam MSB = WIDTH_ERR-1;

reg signed 	[WIDTH_ERR-1:0] Yi;		// integrator raw
reg signed 	[WIDTH_ERR-1:0] Ys;		// integrator saturated
reg signed  [WIDTH-1:0] result1;		// 
reg signed  [WIDTH-1:0] result2;
reg signed 	[WIDTH_ERR-1:0] R1 ;		// intermediate result
reg process_dly;
reg [3:0] counter;
reg [WIDTH_ERR-1:0] dlim_neg;
reg undrflow;
reg ovrflow;
reg extra;

// assign
assign uk = result2;
//
	always @ (posedge sys_clk) begin
		dlim_neg <= ~dlim + 1;
	end	
	
	always @ (posedge sys_clk, posedge rst) begin
		if(rst)
			process_dly <= 0;
		else
		   process_dly <= process;
	end
		
	always @ (posedge sys_clk, posedge rst) begin 
		if(rst) begin
				result1 <= 0;
				result2 <= 0;
				Yi <= 0;
				Ys <= 0;
				R1 <= 0;
				counter <= 0;
		end
		else begin
			if (process & !process_dly)
				counter <= 4'h8;
			else if (counter !=0)
				counter <= counter-1;		
			if(!enable) 
			begin
				result2 <=  4'h0 ;	// default count
				Yi <= 0;
				R1 <= 0;
				counter <= 0;
			end else begin
		   // compensation pipeline
				case (counter)
					4'h8: begin
						{extra, Yi} <= {Ys[MSB], Ys} + {err[MSB], err};
						R1 <=  err>>>kp;
						end
					4'h7: begin
						ovrflow <=  ({extra, Yi[MSB]} == 2'b01 );
						undrflow <=  ({extra, Yi[MSB]} == 2'b10 );
						end
					4'h6:	Ys <= (ovrflow)? ~(1<<MSB): (undrflow)? 1<<MSB: Yi;				
					4'h5: begin		
					   if(Ys[WIDTH_ERR-1])
							Ys <= Ys < dlim_neg ? dlim_neg:Ys;
						else
						   Ys <= Ys > dlim ? dlim : Ys;
						end	
               4'h4: Yi <= Ys >>>ki;		// temporary re-use Yi						
					4'h3: R1 <= R1 + Yi;			// preserve Ys
					4'h2: result1 <= R1>>>k0; 
					4'h1: result2 <= $signed(result1) ;
					default: ;    // don't do anything
				endcase  
			end
		end
	end	
endmodule
