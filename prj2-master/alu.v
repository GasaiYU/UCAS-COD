`timescale 10 ns / 1 ns

`define DATA_WIDTH 32

`define ALUOP_AND 3'b000
`define ALUOP_OR  3'b001
`define ALUOP_ADD 3'b010
`define ALUOP_SUB 3'b110
`define ALUOP_STL 3'b111
`define ALUOP_XOR 3'b100
`define ALUOP_NOR 3'b101
`define ALUOP_SLTU 3'b011



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
    wire [`DATA_WIDTH - 1: 0] andresult;
    wire [`DATA_WIDTH - 1: 0] orresult;
    wire [`DATA_WIDTH - 1: 0] assresult;
	wire [`DATA_WIDTH - 1: 0] sltresult;
	wire [`DATA_WIDTH - 1: 0] xorresult;
	wire [`DATA_WIDTH - 1: 0] norresult;
	wire [`DATA_WIDTH - 1: 0] slturesult;
    

    wire op_and = ALUop == `ALUOP_AND;
	wire op_or = ALUop ==  `ALUOP_OR;
	wire op_add = ALUop == `ALUOP_ADD;
	wire op_sub = ALUop == `ALUOP_SUB;
	wire op_stl = ALUop == `ALUOP_STL;
	wire op_xor = ALUop == `ALUOP_XOR;
	wire op_nor = ALUop == `ALUOP_NOR;
	wire op_sltu = ALUop == `ALUOP_SLTU;

	
	/*wire sltu_carryout;
	wire [31:0] sltu_assresult;

	assign {sltu_carryout,sltu_assresult} = A + ~B + 1;

	assign slturesult = {{31{1'b0}},sltu_carryout};*/

	assign andresult = A & B;
	assign orresult = A | B;
	assign xorresult = A ^ B;
	assign norresult = ~(A | B);

	

	assign {CarryOut,assresult} = A + ((ALUop[2] | op_sltu)? ~B:B) + (ALUop[2] | op_sltu);
	assign Overflow = (A[`DATA_WIDTH - 1] & B[`DATA_WIDTH - 1] & ~assresult[`DATA_WIDTH - 1] & ~ALUop[2]) | (~A[`DATA_WIDTH - 1] & ~B[`DATA_WIDTH - 1] & assresult[`DATA_WIDTH - 1] & ~ALUop[2])|
	(A[`DATA_WIDTH - 1] & ~B[`DATA_WIDTH - 1] & ~assresult[`DATA_WIDTH - 1] & ALUop[2]) | (~A[`DATA_WIDTH - 1] & B[`DATA_WIDTH - 1] & assresult[`DATA_WIDTH - 1] & ALUop[2]); 
	
	assign sltresult = Overflow ^ assresult[`DATA_WIDTH - 1];
	
	assign slturesult = {{31{1'b0}},CarryOut};

	assign Result = {32{op_and}} & andresult | 
					{32{op_or}} & orresult |
					{32{op_add}} & assresult |
					{32{op_sub}} & assresult |
					{32{op_stl}} & sltresult |
					{32{op_xor}} & xorresult |
					{32{op_nor}} & norresult |
					{32{op_sltu}} & slturesult;

	assign Zero = (Result == 32'b0)? 1:0;
	

	endmodule