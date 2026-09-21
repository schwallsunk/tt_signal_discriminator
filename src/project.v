/*
 * Copyright (c) 2024 Schwallsunk
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_schwallsunk_signal_discriminator (
    input  wire [7:0] ui_in,    // Dedicated inputs: 0=low thresh, 1=high thresh, 2=MUX IO DLY 0, 3=MUX IO DLY 1, 4=shift to buffer (latch_res), 5=MUX IO CNTR 0, 6=MUX IO CNTR 1, rst_counter
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // master clock
    input  wire       rst_n     // reset_n - low to reset
);
    assign uio_oe  = 8'b11111111; 
    assign uo_out[7:1] = 7'b0000000;

    wire internal_rst; 
    wire internal_rst_n; 
    wire dly_internal_rst;
    wire dly_high; 
    wire dly_dly_high; 
    wire dff_high_qn; 
    wire dly_low; 
    wire dly_dly_low; 
    wire dff_low_q; 
    wire coincidence_cont_q; 
    wire dff_output_q;
    wire rst_dff_output;
    wire dly_dff_rst_1;
    wire dly_dff_rst_3;
    wire dly_dff_rst_9;
    wire dly_dff_rst_27;
    wire dly_dff_output_q;
    wire rst_dff_output_n;
    wire buf_dly_dly_low;
    wire buf_dly_dly_high;
    wire buf_dly_internal_rst;
    wire [31:0] counter_32_bit_out;
    wire rst_n_cnt;

    // ------------------------------------------------------------------
    // LOGIC frontend start for discrimination
    // ------------------------------------------------------------------
    (* keep *) sg13g2_dlygate4sd2_1  dly0(.X(dly_low), .A(ui_in[0]));
    (* keep *) sg13g2_dlygate4sd2_1  dly00(.X(buf_dly_dly_low), .A(dly_low));
    (* keep *) sg13g2_buf_2 buf0(.X(dly_dly_low),.A(buf_dly_dly_low));
    (* keep *) sg13g2_dlygate4sd2_1  dly1(.X(dly_high), .A(ui_in[1]));
    (* keep *) sg13g2_dlygate4sd2_1  dly10(.X(buf_dly_dly_high), .A(dly_high));
    (* keep *) sg13g2_buf_2 buf1(.X(dly_dly_high),.A(buf_dly_dly_high));
    (* keep *) sg13g2_and2_2  and0(.X(internal_rst), .A(ui_in[0]), .B(rst_n));
    (* keep *) sg13g2_dlygate4sd2_1  dly2(.X(buf_dly_internal_rst), .A(internal_rst));
    (* keep *) sg13g2_buf_2 buf2(.X(dly_internal_rst),.A(buf_dly_internal_rst));
    (* keep *) sg13g2_dfrbp_2  dff_low(.CLK(dly_dly_low),.RESET_B(dly_internal_rst),.D(1'b1),.Q(dff_low_q));
    (* keep *) sg13g2_dfrbp_2  dff_high(.CLK(dly_dly_high),.RESET_B(dly_internal_rst),.D(1'b1),.Q_N(dff_high_qn));
    (* keep *) sg13g2_and2_2  and1(.X(coincidence_cont_q), .A(dff_high_qn), .B(dff_low_q));
    (* keep *) sg13g2_inv_2  inv0(.Y(internal_rst_n), .A(internal_rst));
    (* keep *) sg13g2_dfrbp_2  dff_output(.CLK(internal_rst_n),.RESET_B(rst_dff_output_n),.D(coincidence_cont_q),.Q(dff_output_q));
    
    delay_gate_sim dly3(.in(dff_output_q),.out(dly_dff_rst_1));
    delay_gate_sim_triple dly4(.in(dff_output_q),.out(dly_dff_rst_3));
    delay_gate_sim_nine dly5(.in(dff_output_q),.out(dly_dff_rst_9));
    delay_gate_sim_twenty_seven dly6(.in(dff_output_q),.out(dly_dff_rst_27));
    
    (* keep *) sg13g2_mux4_1 mux0(.A0(dly_dff_rst_1),.A1(dly_dff_rst_3),.A2(dly_dff_rst_9),.A3(dly_dff_rst_27),.S0(ui_in[2]),.S1(ui_in[3]),.X(dly_dff_output_q));
    (* keep *) sg13g2_mux2_1 mux1(.X(rst_dff_output), .A0(1'b1), .A1(dly_dff_output_q), .S(rst_n));
    (* keep *) sg13g2_inv_2  inv3(.Y(rst_dff_output_n), .A(rst_dff_output));

    sg13g2_and2_2  and2(.X(rst_n_cnt), .A(rst_n), .B(ui_in[7]));
    
    // ------------------------------------------------------------------
    // Counter & Register Array Call
    // ------------------------------------------------------------------
    counter_32_bit cnt0 (
        .cnt_in(dff_output_q), 
        .rst_n(rst_n_cnt), 
        .out(counter_32_bit_out)
    );
    
    shift_reg_32_bit hold_reg0 (
        .rst_n(rst_n), 
        .latch_res(ui_in[4]), 
        .adress(ui_in[6:5]), 
        .input_bits(counter_32_bit_out), 
        .out_uio(uio_out)
    );

    assign uo_out[0] = dff_output_q;
    wire _unused = &{ uio_in, ena, clk, 1'b0};
endmodule

// ------------------------------------------------------------------
// OPTIMIZED HYBRID 300 MHz COUNTER (4-Bit Ripple Prescaler + 28-Bit Sync)
// ------------------------------------------------------------------
module counter_32_bit (
    input  wire cnt_in,
    input  wire rst_n,
    output wire [31:0] out
);
    wire [3:0] p_qn;
    wire [3:0] p_q;

    // High-drive cell primitives ensure clean edge propagation at 300 MHz
    sg13g2_dfrbp_2 dff_cnt_0 (.CLK(cnt_in),  .RESET_B(rst_n), .D(p_qn[0]), .Q(p_q[0]), .Q_N(p_qn[0]));
    sg13g2_dfrbp_2 dff_cnt_1 (.CLK(p_qn[0]), .RESET_B(rst_n), .D(p_qn[1]), .Q(p_q[1]), .Q_N(p_qn[1]));
    sg13g2_dfrbp_2 dff_cnt_2 (.CLK(p_qn[1]), .RESET_B(rst_n), .D(p_qn[2]), .Q(p_q[2]), .Q_N(p_qn[2]));
    sg13g2_dfrbp_2 dff_cnt_3 (.CLK(p_qn[2]), .RESET_B(rst_n), .D(p_qn[3]), .Q(p_q[3]), .Q_N(p_qn[3]));

    assign out[3:0] = p_q;

    // Remaining bits run synchronously on the 18.75 MHz prescaler output
    reg [27:0] sync_upper_cnt;
    always @(posedge p_qn[3] or negedge rst_n) begin
        if (!rst_n) 
            sync_upper_cnt <= 28'b0;
        else 
            sync_upper_cnt <= sync_upper_cnt + 1'b1;
    end

    assign out[31:4] = sync_upper_cnt;
endmodule

// ------------------------------------------------------------------
// SAFE SHADOW SNAPSHOT SHIFT REGISTER (Prevents Metastability)
// ------------------------------------------------------------------
module shift_reg_32_bit (
    input  wire        rst_n,
    input  wire        latch_res,
    input  wire [1:0]  adress,
    input  wire [31:0] input_bits,
    output reg  [7:0]  out_uio
);
    reg [31:0] counter_snapshot;

    // Instantly freeze counter data upon readout request
    always @(posedge latch_res or negedge rst_n) begin
        if (!rst_n) begin
            counter_snapshot <= 32'b0;
        end else begin
            counter_snapshot <= input_bits;
        end
    end

    // Stable, hazard-free multiplexed output
    always @(*) begin
        case (adress)
            2'b00:   out_uio = counter_snapshot[7:0];
            2'b01:   out_uio = counter_snapshot[15:8];
            2'b10:   out_uio = counter_snapshot[23:16];
            2'b11:   out_uio = counter_snapshot[31:24];
            default: out_uio = 8'b00000000;
        endcase
    end
endmodule

// ------------------------------------------------------------------
// DELAY STAGE PRIMITIVES 
// ------------------------------------------------------------------
module delay_gate_sim (input wire in, output wire out);
     sg13g2_dlygate4sd2_1 dly0(.X(out), .A(in));
endmodule

module delay_gate_sim_triple (input wire in, output wire out);
    wire delay_1, delay_2,buf_1;
    delay_gate_sim dly7 (.in(in), .out(delay_1));
    delay_gate_sim dly8 (.in(delay_1), .out(delay_2));
    delay_gate_sim dly9 (.in(delay_2), .out(buf_1));
    sg13g2_buf_4 buf0(.X(out),.A(buf_1));
endmodule

module delay_gate_sim_nine (input wire in, output wire out);
    wire delay_1, delay_2;
    delay_gate_sim_triple dly10 (.in(in), .out(delay_1));
    delay_gate_sim_triple dly11 (.in(delay_1), .out(delay_2));
    delay_gate_sim_triple dly12 (.in(delay_2), .out(out));
endmodule

module delay_gate_sim_twenty_seven (input wire in, output wire out);
    wire delay_1, delay_2;
    delay_gate_sim_nine dly13 (.in(in), .out(delay_1));
    delay_gate_sim_nine dly14 (.in(delay_1), .out(delay_2));
    delay_gate_sim_nine dly15 (.in(delay_2), .out(out));
endmodule
