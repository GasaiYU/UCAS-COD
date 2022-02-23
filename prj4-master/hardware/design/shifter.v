`timescale 10 ns / 1 ns

`define SHIFTLEFT   2'b00
`define SHIFTRIGHT  2'b10
`define SHIFTRIGHTA 2'b11

`define DATA_WIDTH 32

module shifter (
	input [`DATA_WIDTH - 1:0] A,
	input [`DATA_WIDTH - 1:0] B,
	input [1:0] Shiftop,
	output [`DATA_WIDTH - 1:0] Result
);

	// TODO: Please add your logic code here

    /*define my shiftop here*/
    wire op_left = Shiftop == `SHIFTLEFT;
    wire op_right = Shiftop == `SHIFTRIGHT;
    wire op_righta = Shiftop == `SHIFTRIGHTA;

    /*define my shifter logic there*/
    wire [63:0] extend = {{32{A[`DATA_WIDTH - 1]}},A};
    wire [63:0] extend_rightaresult = extend >> B;

    wire [31:0] leftresult = A << B;
    wire [31:0] rightresult = A >> B;

    wire [31:0] rightaresult = extend_rightaresult[31:0];


    assign Result = ({32{op_left}} & leftresult) |
                    ({32{op_right}} & rightresult) |
                    ({32{op_righta}} & rightaresult);


endmodule
