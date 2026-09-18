/*
 * Copyright (c) 2024 Schwallsunk
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_schwallsunk_signal_discriminator (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

      wire internal_rst; // Internal reset signal based on lower threshold state as well as external reset signal
  wire internal_rst_n; // Internal reset signal based on lower threshold state as well as external reset signal
  wire rst;
  wire dly_high; // Internal reset signal based on lower threshold state as well as external reset signal
  wire dff_high_q; // Output D-FF of the high triggered FF
  wire dff_high_qn; // Output D-FF of the high triggered FF
  wire dly_low; // Internal reset signal based on lower threshold state as well as external reset signal
  wire dff_low_q; // Output D-FF of the low triggered FF
  wire dff_low_qn; // Output D-FF of the low triggered FF
  wire coincidence_cont_q; // conincidence detection and rejection output
  wire dff_output_q;
  wire dff_output_qn;
  wire xor_output_q;
  wire rst_dff_output;
  wire dly_dff_rst_1;
  wire dly_dff_rst_3;
  wire dly_dff_rst_9;
  wire dly_dff_rst_27;
  wire dly_dff_output_q;

  // All output pins must be assigned. If not used, assign to 0.
  delay_gate_sim dly0 (.in(ui_in[0]),.out(dly_low));
  delay_gate_sim dly1 (.in(ui_in[1]),.out(dly_high));
  addition_gate_level and0 (.a(ui_in[0]),.b(rst_n),.out(internal_rst));
  d_ff_async_reset dff_low (.clk(dly_low),.rst_n(internal_rst),.d(1'b1),.q(dff_low_q),.qn(dff_low_qn));
  d_ff_async_reset dff_high (.clk(dly_high),.rst_n(internal_rst),.d(1'b1),.q(dff_high_q),.qn(dff_high_qn));
  addition_gate_level and1 (.a(dff_high_qn),.b(dff_low_q),.out(coincidence_cont_q));
  inverter inv0 (.in(internal_rst),.out(internal_rst_n));
  inverter inv1 (.in(rst_n),.out(rst));
  delay_gate_sim dly2 (.in(ui_in[1]),.out(dly_high));
  d_ff_async_reset dff_output (.clk(internal_rst_n),.rst_n(rst_dff_output),.d(coincidence_cont_q),.q(dff_output_q),.qn(dff_output_qn));
  delay_gate_sim dly3 (.in(dff_output_q),.out(dly_dff_rst_1));
  delay_gate_sim_triple dly4 (.in(dff_output_q),.out(dly_dff_rst_3));
  delay_gate_sim_nine dly5 (.in(dff_output_q),.out(dly_dff_rst_9));
  delay_gate_sim_twenty_seven dly6 (.in(dff_output_q),.out(dly_dff_rst_27));
  mux_4_to_1 mux0 (.A0(dly_dff_rst_1),.A1(dly_dff_rst_3),.A2(dly_dff_rst_9),.A3(dly_dff_rst_27),.S0(ui_in[2]),.S1(ui_in[3]),.X(dly_dff_output_q));
  xor_gate_level xor0 (.a(rst_n),.b(dly_dff_output_q),.out(rst_dff_output));

  assign uo_out[0]=dff_output_q;
  assign uio_out = 0;
  assign uio_oe  = 0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};

endmodule



module d_ff_async_reset (
    input wire clk,
    input wire rst_n, // Low-active reset
    input wire d,
    output reg q,
    output reg qn
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= 1'b0;
            qn <= 1'b1;
        end else begin
            q <= d;
            qn <= ~d;
        end
    end
endmodule

module xor_gate_level (
    input  wire a,
    input  wire b,
    output wire out
);
    // Built-in Verilog structural primitive: xor (output, input1, input2)
    xor u1 (out, a, b);

endmodule

module addition_gate_level (
    input  wire a,
    input  wire b,
    output wire out
);
    assign out = a & b;

endmodule

module delay_gate_sim (
    input  wire in,
    output wire out
);

    // Continuous assignment with a 0.45 ns delay
    assign #0.45 out = in;

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


module inverter(
    input  wire in,
    output wire out
);
    // Continuous assignment using bitwise NOT operator
    assign out = ~in; 

endmodule


module mux_4_to_1 (
    input wire A0,
    input wire A1,
    input wire A2,
    input wire A3,
    input wire S0,
    input wire S1,
    output wire X
);
  wire [1:0] sel;
  assign sel = {S1, S0};
    // Using conditional (ternary) operators
    assign X = (sel == 2'b00) ? A0 :
                 (sel == 2'b01) ? A1 :
                 (sel == 2'b10) ? A2 : A3;

endmodule
