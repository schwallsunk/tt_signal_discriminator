`timescale 1ns/10ps
`celldefine

module sg13g2_dlygate4sd2_1 (
    output X,
    input A
);

    assign #0.45 X = A;

endmodule

`endcelldefine
