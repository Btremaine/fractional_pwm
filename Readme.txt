//////////////////////////////////////////////////////////////////////////////////
// Company:	  Tremaine Consulting Group
// Engineer:  Brian Tremaine
// 
// Create Date:    Nov. 6, 2018 
// Design Name: 
// Module Name:    frac_pwm.v 
// Project Name:
// Target Devices: Spartan 3AN XC3S50ATQ144 
// Tool versions: 
// Description:    fractional pwm
//                 Generate clock with constant period sys_clk/No. 
//			       Generate PWM signal high > N+1 counts for m-cycles and 
//                 high > N counts for M-m cycles. Average PWM count is N + m/M
//		           In this code Mbar is parameterized using fsze
//
//                 Output q is high for period_cnt > Ni otherwise q is low.
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////