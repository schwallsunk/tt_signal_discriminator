/*
 * Copyright (c) 2024 Schwallsunk
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_schwallsunk_signal_discriminator (
    input  wire [7:0] ui_in,    // Dedicated inputs: 0 = low thresh, 1 = high thresh, 2 = MUX IO DLY 0, 3 = MUX IO DLY 1, 4 = shift to buffer, 5 = MUX IO CNTR 0, 6 = MUX IO CNTR 1
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
    assign uio_oe  = 8'b11111111; // port uio goes all out
    //assign uio_out  = 8'b11111111; // port uio goes all out
    assign uo_out[7:1] = 7'b0000000;
    wire internal_rst; // Internal reset signal based on lower threshold state as well as external reset signal
    wire internal_rst_n; // Internal reset signal based on lower threshold state as well as external reset signal
    wire dly_internal_rst;
    wire rst; //
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
    wire rst_dff_output_n;
    wire [31:0] counter_32_bit_out;
    // LOGIC frontend start for discrimination
    (* keep *) sg13g2_dlygate4sd2_1  dly0(.X(dly_low), .A(ui_in[0]));
    (* keep *) sg13g2_dlygate4sd2_1  dly00(.X(dly_dly_low), .A(dly_low));
    (* keep *) sg13g2_dlygate4sd2_1  dly1(.X(dly_high), .A(ui_in[1]));
    (* keep *) sg13g2_dlygate4sd2_1  dly10(.X(dly_dly_high), .A(dly_high));
    (* keep *) sg13g2_and2_1  and0(.X(internal_rst), .A(ui_in[0]), .B(rst_n));
    (* keep *) sg13g2_dlygate4sd2_1  dly2(.X(dly_internal_rst), .A(internal_rst));
    (* keep *) sg13g2_dfrbp_1  dff_low(.CLK(dly_dly_low),.RESET_B(dly_internal_rst),.D(1'b1),.Q(dff_low_q));
    (* keep *) sg13g2_dfrbp_1  dff_high(.CLK(dly_dly_high),.RESET_B(dly_internal_rst),.D(1'b1),.Q_N(dff_high_qn));
    (* keep *) sg13g2_and2_1  and1(.X(coincidence_cont_q), .A(dff_high_qn), .B(dff_low_q));
    (* keep *) sg13g2_inv_2  inv0(.Y(internal_rst_n), .A(internal_rst));
    (* keep *) sg13g2_inv_2  inv1(.Y(rst), .A(rst_n));
    (* keep *) sg13g2_dfrbp_1  dff_output(.CLK(internal_rst_n),.RESET_B(rst_dff_output_n),.D(coincidence_cont_q),.Q(dff_output_q));
    delay_gate_sim dly3(.in(dff_output_q),.out(dly_dff_rst_1));
    delay_gate_sim_triple dly4(.in(dff_output_q),.out(dly_dff_rst_3));
    delay_gate_sim_nine dly5(.in(dff_output_q),.out(dly_dff_rst_9));
    delay_gate_sim_twenty_seven dly6(.in(dff_output_q),.out(dly_dff_rst_27));
    (* keep *) sg13g2_mux4_1 mux0(.A0(dly_dff_rst_1),.A1(dly_dff_rst_3),.A2(dly_dff_rst_9),.A3(dly_dff_rst_27),.S0(ui_in[2]),.S1(ui_in[3]),.X(dly_dff_output_q));
    (* keep *) sg13g2_mux2_1 mux1(.X(rst_dff_output), .A0(1'b1), .A1(dly_dff_output_q), .S(rst_n));
    (* keep *) sg13g2_inv_2  inv3(.Y(rst_dff_output_n), .A(rst_dff_output));
    // LOGIC frontend finished
    // complete counter work
    counter_32_bit cnt0(.cnt_in(dff_output_q),.rst_n(rst_n),.out(counter_32_bit_out));
    shift_reg_32_bit hold_reg0(.rst_n(rst_n),.latch_res(ui_in[4]),.adress(ui_in[6:5]),.input_bits(counter_32_bit_out),.out_uio(uio_out));

  assign uo_out[0]=dff_output_q;

  // List all unused inputs to prevent warnings
    wire _unused = &{ui_in[7], uio_in, ena, clk, 1'b0};

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

module counter_32_bit (
    input  wire cnt_in,
    input  wire rst_n,
    output wire [31:0] out
);
    wire dff_fbk_0;
    wire dff_out_0;
    wire dff_fbk_1;
    wire dff_out_1;
    wire dff_fbk_2;
    wire dff_out_2;
    wire dff_fbk_3;
    wire dff_out_3;
    wire dff_fbk_4;
    wire dff_out_4;
    wire dff_fbk_5;
    wire dff_out_5;
    wire dff_fbk_6;
    wire dff_out_6;
    wire dff_fbk_7;
    wire dff_out_7;
    wire dff_fbk_8;
    wire dff_out_8;
    wire dff_fbk_9;
    wire dff_out_9;
    wire dff_fbk_10;
    wire dff_out_10;
    wire dff_fbk_11;
    wire dff_out_11;
    wire dff_fbk_12;
    wire dff_out_12;
    wire dff_fbk_13;
    wire dff_out_13;
    wire dff_fbk_14;
    wire dff_out_14;
    wire dff_fbk_15;
    wire dff_out_15;
    wire dff_fbk_16;
    wire dff_out_16;
    wire dff_fbk_17;
    wire dff_out_17;
    wire dff_fbk_18;
    wire dff_out_18;
    wire dff_fbk_19;
    wire dff_out_19;
    wire dff_fbk_20;
    wire dff_out_20;
    wire dff_fbk_21;
    wire dff_out_21;
    wire dff_fbk_22;
    wire dff_out_22;
    wire dff_fbk_23;
    wire dff_out_23;
    wire dff_fbk_24;
    wire dff_out_24;
    wire dff_fbk_25;
    wire dff_out_25;
    wire dff_fbk_26;
    wire dff_out_26;
    wire dff_fbk_27;
    wire dff_out_27;
    wire dff_fbk_28;
    wire dff_out_28;
    wire dff_fbk_29;
    wire dff_out_29;
    wire dff_fbk_30;
    wire dff_out_30;
    wire dff_fbk_31;
    wire dff_out_31;
    (* keep *) sg13g2_dfrbp_1  dff_cnt_0(.CLK(cnt_in),.RESET_B(rst_n),.D(dff_fbk_0),.Q(out[0]),.Q_N(dff_fbk_0));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_1(.CLK(dff_fbk_0),.RESET_B(rst_n),.D(dff_fbk_1),.Q(out[1]),.Q_N(dff_fbk_1));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_2(.CLK(dff_fbk_1),.RESET_B(rst_n),.D(dff_fbk_2),.Q(out[2]),.Q_N(dff_fbk_2));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_3(.CLK(dff_fbk_2),.RESET_B(rst_n),.D(dff_fbk_3),.Q(out[3]),.Q_N(dff_fbk_3));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_4(.CLK(dff_fbk_3),.RESET_B(rst_n),.D(dff_fbk_4),.Q(out[4]),.Q_N(dff_fbk_4));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_5(.CLK(dff_fbk_4),.RESET_B(rst_n),.D(dff_fbk_5),.Q(out[5]),.Q_N(dff_fbk_5));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_6(.CLK(dff_fbk_5),.RESET_B(rst_n),.D(dff_fbk_6),.Q(out[6]),.Q_N(dff_fbk_6));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_7(.CLK(dff_fbk_6),.RESET_B(rst_n),.D(dff_fbk_7),.Q(out[7]),.Q_N(dff_fbk_7));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_8(.CLK(dff_fbk_7),.RESET_B(rst_n),.D(dff_fbk_8),.Q(out[8]),.Q_N(dff_fbk_8));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_9(.CLK(dff_fbk_8),.RESET_B(rst_n),.D(dff_fbk_9),.Q(out[9]),.Q_N(dff_fbk_9));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_10(.CLK(dff_fbk_9),.RESET_B(rst_n),.D(dff_fbk_10),.Q(out[10]),.Q_N(dff_fbk_10));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_11(.CLK(dff_fbk_10),.RESET_B(rst_n),.D(dff_fbk_11),.Q(out[11]),.Q_N(dff_fbk_11));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_12(.CLK(dff_fbk_11),.RESET_B(rst_n),.D(dff_fbk_12),.Q(out[12]),.Q_N(dff_fbk_12));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_13(.CLK(dff_fbk_12),.RESET_B(rst_n),.D(dff_fbk_13),.Q(out[13]),.Q_N(dff_fbk_13));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_14(.CLK(dff_fbk_13),.RESET_B(rst_n),.D(dff_fbk_14),.Q(out[14]),.Q_N(dff_fbk_14));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_15(.CLK(dff_fbk_14),.RESET_B(rst_n),.D(dff_fbk_15),.Q(out[15]),.Q_N(dff_fbk_15));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_16(.CLK(dff_fbk_15),.RESET_B(rst_n),.D(dff_fbk_16),.Q(out[16]),.Q_N(dff_fbk_16));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_17(.CLK(dff_fbk_16),.RESET_B(rst_n),.D(dff_fbk_17),.Q(out[17]),.Q_N(dff_fbk_17));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_18(.CLK(dff_fbk_17),.RESET_B(rst_n),.D(dff_fbk_18),.Q(out[18]),.Q_N(dff_fbk_18));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_19(.CLK(dff_fbk_18),.RESET_B(rst_n),.D(dff_fbk_19),.Q(out[19]),.Q_N(dff_fbk_19));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_20(.CLK(dff_fbk_19),.RESET_B(rst_n),.D(dff_fbk_20),.Q(out[20]),.Q_N(dff_fbk_20));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_21(.CLK(dff_fbk_20),.RESET_B(rst_n),.D(dff_fbk_21),.Q(out[21]),.Q_N(dff_fbk_21));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_22(.CLK(dff_fbk_21),.RESET_B(rst_n),.D(dff_fbk_22),.Q(out[22]),.Q_N(dff_fbk_22));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_23(.CLK(dff_fbk_22),.RESET_B(rst_n),.D(dff_fbk_23),.Q(out[23]),.Q_N(dff_fbk_23));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_24(.CLK(dff_fbk_23),.RESET_B(rst_n),.D(dff_fbk_24),.Q(out[24]),.Q_N(dff_fbk_24));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_25(.CLK(dff_fbk_24),.RESET_B(rst_n),.D(dff_fbk_25),.Q(out[25]),.Q_N(dff_fbk_25));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_26(.CLK(dff_fbk_25),.RESET_B(rst_n),.D(dff_fbk_26),.Q(out[26]),.Q_N(dff_fbk_26));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_27(.CLK(dff_fbk_26),.RESET_B(rst_n),.D(dff_fbk_27),.Q(out[27]),.Q_N(dff_fbk_27));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_28(.CLK(dff_fbk_27),.RESET_B(rst_n),.D(dff_fbk_28),.Q(out[28]),.Q_N(dff_fbk_28));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_29(.CLK(dff_fbk_28),.RESET_B(rst_n),.D(dff_fbk_29),.Q(out[29]),.Q_N(dff_fbk_29));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_30(.CLK(dff_fbk_29),.RESET_B(rst_n),.D(dff_fbk_30),.Q(out[30]),.Q_N(dff_fbk_30));
    (* keep *) sg13g2_dfrbp_1  dff_cnt_31(.CLK(dff_fbk_30),.RESET_B(rst_n),.D(dff_fbk_31),.Q(out[31]),.Q_N(dff_fbk_31));


endmodule

module shift_reg_32_bit (
    input  wire rst_n,
    input  wire latch_res,
    input  wire adress[1:0],
    input  wire [31:0] input_bits
    output wire [7:0] out_uio
);
    
    wire dff_out_0;
    wire dff_out_1;
    wire dff_out_2;
    wire dff_out_3;
    wire dff_out_4;
    wire dff_out_5;
    wire dff_out_6;
    wire dff_out_7;
    wire dff_out_8;
    wire dff_out_9;
    wire dff_out_10;
    wire dff_out_11;
    wire dff_out_12;
    wire dff_out_13;
    wire dff_out_14;
    wire dff_out_15;
    wire dff_out_16;
    wire dff_out_17;
    wire dff_out_18;
    wire dff_out_19;
    wire dff_out_20;
    wire dff_out_21;
    wire dff_out_22;
    wire dff_out_23;
    wire dff_out_24;
    wire dff_out_25;
    wire dff_out_26;
    wire dff_out_27;
    wire dff_out_28;
    wire dff_out_29;
    wire dff_out_30;
    wire dff_out_31;

    (* keep *) sg13g2_mux4_1 mux_bit_0(.A0(dff_out_0),.A1(dff_out_8),.A2(dff_out_16),.A3(dff_out_24),.S0(adress[0]),.S1(adress[1]),.X(out_uio[0]));
    (* keep *) sg13g2_mux4_1 mux_bit_1(.A0(dff_out_1),.A1(dff_out_9),.A2(dff_out_17),.A3(dff_out_25),.S0(adress[0]),.S1(adress[1]),.X(out_uio[1]));
    (* keep *) sg13g2_mux4_1 mux_bit_2(.A0(dff_out_2),.A1(dff_out_10),.A2(dff_out_17),.A3(dff_out_26),.S0(adress[0]),.S1(adress[1]),.X(out_uio[2]));
    (* keep *) sg13g2_mux4_1 mux_bit_3(.A0(dff_out_3),.A1(dff_out_11),.A2(dff_out_18),.A3(dff_out_27),.S0(adress[0]),.S1(adress[1]),.X(out_uio[3]));
    (* keep *) sg13g2_mux4_1 mux_bit_4(.A0(dff_out_4),.A1(dff_out_12),.A2(dff_out_19),.A3(dff_out_28),.S0(adress[0]),.S1(adress[1]),.X(out_uio[4]));
    (* keep *) sg13g2_mux4_1 mux_bit_5(.A0(dff_out_5),.A1(dff_out_13),.A2(dff_out_20),.A3(dff_out_29),.S0(adress[0]),.S1(adress[1]),.X(out_uio[5]));
    (* keep *) sg13g2_mux4_1 mux_bit_6(.A0(dff_out_6),.A1(dff_out_14),.A2(dff_out_21),.A3(dff_out_30),.S0(adress[0]),.S1(adress[1]),.X(out_uio[6]));
    (* keep *) sg13g2_mux4_1 mux_bit_7(.A0(dff_out_7),.A1(dff_out_15),.A2(dff_out_22),.A3(dff_out_31),.S0(adress[0]),.S1(adress[1]),.X(out_uio[7]));
    
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_0(.Q(dff_out_0), .CLK(latch_res), .D(input_bits[0]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_1(.Q(dff_out_1), .CLK(latch_res), .D(input_bits[1]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_2(.Q(dff_out_2), .CLK(latch_res), .D(input_bits[2]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_3(.Q(dff_out_3), .CLK(latch_res), .D(input_bits[3]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_4(.Q(dff_out_4), .CLK(latch_res), .D(input_bits[4]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_5(.Q(dff_out_5), .CLK(latch_res), .D(input_bits[5]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_6(.Q(dff_out_6), .CLK(latch_res), .D(input_bits[6]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_7(.Q(dff_out_7), .CLK(latch_res), .D(input_bits[7]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_8(.Q(dff_out_8), .CLK(latch_res), .D(input_bits[8]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_9(.Q(dff_out_9), .CLK(latch_res), .D(input_bits[9]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_10(.Q(dff_out_10), .CLK(latch_res), .D(input_bits[10]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_11(.Q(dff_out_11), .CLK(latch_res), .D(input_bits[11]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_12(.Q(dff_out_12), .CLK(latch_res), .D(input_bits[12]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_13(.Q(dff_out_13), .CLK(latch_res), .D(input_bits[13]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_14(.Q(dff_out_14), .CLK(latch_res), .D(input_bits[14]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_15(.Q(dff_out_15), .CLK(latch_res), .D(input_bits[15]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_16(.Q(dff_out_16), .CLK(latch_res), .D(input_bits[16]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_17(.Q(dff_out_17), .CLK(latch_res), .D(input_bits[17]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_18(.Q(dff_out_18), .CLK(latch_res), .D(input_bits[18]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_19(.Q(dff_out_19), .CLK(latch_res), .D(input_bits[19]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_20(.Q(dff_out_20), .CLK(latch_res), .D(input_bits[20]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_21(.Q(dff_out_21), .CLK(latch_res), .D(input_bits[21]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_22(.Q(dff_out_22), .CLK(latch_res), .D(input_bits[22]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_23(.Q(dff_out_23), .CLK(latch_res), .D(input_bits[23]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_24(.Q(dff_out_24), .CLK(latch_res), .D(input_bits[24]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_25(.Q(dff_out_25), .CLK(latch_res), .D(input_bits[25]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_26(.Q(dff_out_26), .CLK(latch_res), .D(input_bits[26]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_27(.Q(dff_out_27), .CLK(latch_res), .D(input_bits[27]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_28(.Q(dff_out_28), .CLK(latch_res), .D(input_bits[28]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_29(.Q(dff_out_29), .CLK(latch_res), .D(input_bits[29]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_30(.Q(dff_out_30), .CLK(latch_res), .D(input_bits[30]), .RESET_B(rst_n));
    (* keep *) sg13g2_dfrbpq_1 dff_bit_out_31(.Q(dff_out_31), .CLK(latch_res), .D(input_bits[31]), .RESET_B(rst_n));

endmodule

