`timescale 10 ns / 1 ns

`define DATA_WIDTH 32

`define ALUOP_AND 3'b000
`define ALUOP_OR 3'b001
`define ALUOP_ADD 3'b010
`define ALUOP_SUB 3'b110
`define ALUOP_STL 3'b111




module alu(
	input [`DATA_WIDTH - 1:0] A,
	input [`DATA_WIDTH - 1:0] B,
	input [2:0] ALUop,
	output Overflow,
	output CarryOut,
	output Zero,
	output [`DATA_WIDTH - 1:0] Result
);

	// TODO: Please add your logic code here
    	wire [`DATA_WIDTH -1 : 0] andresult;
    	wire [`DATA_WIDTH - 1: 0] orresult;
    	wire [`DATA_WIDTH - 1 : 0] assresult;
	wire [`DATA_WIDTH - 1: 0] sltresult;
    

    	wire op_and = ALUop == `ALUOP_AND;
	wire op_or = ALUop ==  `ALUOP_OR;
	wire op_add = ALUop == `ALUOP_ADD;
	wire op_sub = ALUop == `ALUOP_SUB;
	wire op_stl = ALUop == `ALUOP_STL;


	assign andresult = A & B;
	assign orresult = A | B;
	assign {CarryOut,assresult} = A + ((ALUop[2])? ~B:B) + ALUop[2];//accoring to ALUop[2], if ALUop[2]'s value is 1, it means the operation contains substraction
	assign Overflow = (A[`DATA_WIDTH - 1] & B[`DATA_WIDTH - 1] & ~assresult[`DATA_WIDTH - 1] & ~ALUop[2]) | (~A[`DATA_WIDTH - 1] & ~B[`DATA_WIDTH - 1] & assresult[`DATA_WIDTH - 1] & ~ALUop[2])|
	(A[`DATA_WIDTH - 1] & ~B[`DATA_WIDTH - 1] & ~assresult[`DATA_WIDTH - 1] & ALUop[2]) | (~A[`DATA_WIDTH - 1] & B[`DATA_WIDTH - 1] & assresult[`DATA_WIDTH - 1] & ALUop[2]); 
	//overflow judge: Add: Two operations > 0 and result < 0, two operations < 0 and result > 0; the substraction is similiar


	assign sltresult = Overflow ^ assresult[`DATA_WIDTH - 1];

	assign Result = {32{op_and}} & andresult | 
			{32{op_or}} & orresult |
			{32{op_add}} & assresult |
			{32{op_sub}} & assresult |
			{32{op_stl}} & sltresult;//select the right answer,only the selected answer will be assigned to 'Result'

	assign Zero = (Result == 32'b0) ? 1 : 0;

	endmodule
