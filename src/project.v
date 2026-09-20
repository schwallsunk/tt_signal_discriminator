/*
 * Copyright (c) 2024 Schwallsunk
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_schwallsunk_signal_discriminator (
    input  wire [7:0] ui_in,    // Dedicated inputs: 0 = low thresh, 1 = high thresh, 2 = MUX IO DLY 0, 3 = MUX IO DLY 1, 4 = shift to buffer
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
    assign uio_oe  = 8'b11111111; // port uio goes all out
    assign uio_out  = 8'b11111111; // port uio goes all out
    assign uo_out[7:1] = 7'b0000000;
    wire internal_rst; // Internal reset signal based on lower threshold state as well as external reset signal
    wire internal_rst_n; // Internal reset signal based on lower threshold state as well as external reset signal
    wire del_internal_rst;
    wire rst;
    wire dly_high; // Internal reset signal based on lower threshold state as well as external reset signal
    wire dly_dly_high; // Internal reset signal based on lower threshold state as well as external reset signal
    wire dff_high_qn; // Output D-FF of the high triggered FF
    wire dly_low; // Internal reset signal based on lower threshold state as well as external reset signal
    wire dly_dly_low; // Internal reset signal based on lower threshold state as well as external reset signal
    wire dff_low_q; // Output D-FF of the low triggered FF
    wire coincidence_cont_q; // conincidence detection and rejection output
    wire dff_output_q;
    wire rst_dff_output;
    wire dly_dff_rst_1;
    wire dly_dff_rst_3;
    wire dly_dff_rst_9;
    wire dly_dff_rst_27;
    wire dly_dff_output_q;

  // All output pins must be assigned. If not used, assign to 0.
    (* keep *) sg13g2_dlygate4sd2_1  dly0(.X(dly_low), .A(ui_in[0]));
    (* keep *) sg13g2_dlygate4sd2_1  dly00(.X(dly_dly_low), .A(dly_low));
    (* keep *) sg13g2_dlygate4sd2_1  dly1(.X(dly_high), .A(ui_in[1]));
    (* keep *) sg13g2_dlygate4sd2_1  dly10(.X(dly_dly_high), .A(dly_high));
    (* keep *) sg13g2_and2_1  and0(.X(internal_rst), .A(ui_in[0]), .B(rst_n));
    (* keep *) sg13g2_dlygate4sd2_1  dly2(.X(del_internal_rst), .A(internal_rst));
    (* keep *) sg13g2_dfrbp_1  dff_low(.CLK(dly_low),.RESET_B(del_internal_rst),.D(1'b1),.Q(dff_low_q));
    (* keep *) sg13g2_dfrbp_1  dff_high(.CLK(dly_high),.RESET_B(del_internal_rst),.D(1'b1),.Q_N(dff_high_qn));
    (* keep *) sg13g2_and2_1  and1(.X(coincidence_cont_q), .A(dff_high_qn), .B(dff_low_q));
    (* keep *) sg13g2_inv_2  inv0(.Y(internal_rst_n), .A(internal_rst));
    (* keep *) sg13g2_inv_2  inv1(.Y(rst), .A(rst_n));
    (* keep *) sg13g2_dfrbp_1  dff_output(.CLK(internal_rst_n),.RESET_B(rst_dff_output),.D(coincidence_cont_q),.Q(dff_output_q));
    delay_gate_sim dly3(.in(dff_output_q),.out(dly_dff_rst_1));
    delay_gate_sim_triple dly4(.in(dff_output_q),.out(dly_dff_rst_3));
    delay_gate_sim_nine dly5(.in(dff_output_q),.out(dly_dff_rst_9));
    delay_gate_sim_twenty_seven dly6(.in(dff_output_q),.out(dly_dff_rst_27));
    (* keep *) sg13g2_mux2_1 mux1(.X(rst_dff_output), .A0(1'b1), .A1(dly_dff_output_q), .S(rst_n));
    (* keep *) sg13g2_inv_2  inv3(.Y(rst_dff_output_n), .A(rst_dff_output));
    //(* keep *) sg13g2_mux4_1 mux0(.A0(dly_dff_rst_1),.A1(dly_dff_rst_3),.A2(dly_dff_rst_9),.A3(dly_dff_rst_27),.S0(ui_in[2]),.S1(ui_in[3]),.X(dly_dff_output_q));
    //(* keep *) sg13g2_xnor2_1 xnor0(.Y(rst_dff_output), .A(rst), .B(dly_dff_output_q));
    

  assign uo_out[0]=dff_output_q;

  // List all unused inputs to prevent warnings
    wire _unused = &{ui_in[7:4], uio_in, ena, clk, 1'b0};

endmodule


module delay_gate_sim (
    input  wire in,
    output wire out
);

    // Continuous assignment with a 0.45 ns delay
    (* keep *) sg13g2_dlygate4sd2_1  dly0(.X(out), .A(in));

endmodule

module delay_gate_sim_triple (
    input  wire in,
    output wire out
);
  wire delay_1;
  wire delay_2;

    // Continuous assignment with a 1.35 ns delay
    delay_gate_sim dly7 (.in(in), .out(delay_1));
    delay_gate_sim dly8 (.in(delay_1), .out(delay_2));
    delay_gate_sim dly9 (.in(delay_2), .out(out));
endmodule

module delay_gate_sim_nine (
    input  wire in,
    output wire out
);
  wire delay_1;
  wire delay_2;

    // Continuous assignment with a 4.05 ns delay
    delay_gate_sim_triple dly10 (.in(in), .out(delay_1));
    delay_gate_sim_triple dly11 (.in(delay_1), .out(delay_2));
    delay_gate_sim_triple dly12 (.in(delay_2), .out(out));
endmodule


module delay_gate_sim_twenty_seven (
    input  wire in,
    output wire out
);
  wire delay_1;
  wire delay_2;

    // Continuous assignment with a 12.15 ns delay
    delay_gate_sim_nine dly13 (.in(in), .out(delay_1));
    delay_gate_sim_nine dly14 (.in(delay_1), .out(delay_2));
    delay_gate_sim_nine dly15 (.in(delay_2), .out(out));
endmodule
