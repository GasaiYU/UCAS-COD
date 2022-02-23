`timescale 10ns / 1ns

`define SPECIAL 6'b000000
`define BRANCH 6'b0001
`define ADDI 5'b00100

`define ALUOP_AND 3'b000
`define ALUOP_OR  3'b001
`define ALUOP_ADD 3'b010
`define ALUOP_SUB 3'b110
`define ALUOP_STL 3'b111
`define ALUOP_XOR 3'b100
`define ALUOP_NOR 3'b101
`define ALUOP_SLTU 3'b011

`define SHIFTLEFT   2'b00
`define SHIFTRIGHT  2'b10
`define SHIFTRIGHTA 2'b11

`define TYPEALUIMM 4'b0000
`define TYPEALUR   4'b0001
`define TYPESHIFT  4'b0010
`define TYPESHIFTS 4'b0011
`define TYPEBRANCH 4'b0100
`define TYPEJ      4'b0101
`define TYPEJS     4'b0110
`define TYPELOAD   4'b0111
`define TYPESTORE  4'b1000
`define TYPEMOVE   4'b1111

module mips_cpu(
	input  rst,
	input  clk,

	output reg [31:0] PC,
	input  [31:0] Instruction,

	output [31:0] Address,
	output MemWrite,
	output [31:0] Write_data,
	output [3:0] Write_strb,

	input  [31:0] Read_data,
	output MemRead
);

	// THESE THREE SIGNALS ARE USED IN OUR TESTBENCH
	// PLEASE DO NOT MODIFY SIGNAL NAMES
	// AND PLEASE USE THEM TO CONNECT PORTS
	// OF YOUR INSTANTIATION OF THE REGISTER FILE MODULE
	wire			RF_wen;
	wire [4:0]		RF_waddr;
	wire [31:0]		RF_wdata;


	// TODO: PLEASE ADD YOUT CODE BELOW

	//R_TYPE Instructions

	wire [4:0] rs;
	wire [4:0] rt;
	wire [4:0] rd;
	wire [4:0] sa;//special shifter signal
	wire [5:0] opcode;
	wire [15:0] immediate;//imm number
	wire [5:0] funccode;
	wire [31:0] sign_extend;
	wire [31:0] zero_extend;
	wire [2:0] alu_op;
	wire [31:0] offset_two_extend;//offset||00
	wire [31:0] instr_two_extend;//instr||00
	wire [31:0] lui_extend;


	
	wire [4:0] RF_raddr1;
	wire [4:0] RF_raddr2;
	wire [31:0]rdata1;
	wire [31:0]rdata2;


	wire [0:0] RegDst;
	wire [0:0] Jump;
	wire [0:0] Branch;
	wire [0:0] MemtoReg;
	wire [3:0] ALU_control;
	wire [0:0] ALUsrc;
	wire [1:0] Shifter_control;

	wire [31:0] PC_4;
	
	wire [3:0] Type;//define Instruction Type

	wire [31:0] aluop1; 
	wire [31:0] aluop2;
	wire [31:0] ALU_result;//ALU_result
	wire Zero;
	wire [31:0] extend;

	wire [31:0] lb_result;
	wire [31:0] lh_result;
	wire [31:0] lbu_result;
	wire [31:0] lhu_result;
	wire [31:0] lw_result;
	wire [31:0] lwl_result;
	wire [31:0] lwr_result;
	wire [1:0] n;
	wire [31:0] load_result;

	wire [31:0] shifter_result;
	wire [31:0] shiftop1 = rdata2;
	wire [31:0] shiftop2 = (Type == `TYPESHIFT)? {{27{1'b0}},sa}: {{27{1'b0}},rdata1[4:0]};//sa or rt

	assign Type = (opcode[5:3] == 3'b001 && opcode != 6'b001111)? `TYPEALUIMM://ALU Immdiate word
				  ((opcode == `SPECIAL && funccode[5] == 1)? `TYPEALUR://ALU rs rt rd
				  ((opcode == `SPECIAL && funccode[5:2] == 4'b0000)? `TYPESHIFT://Shifter 
				  ((opcode == `SPECIAL && funccode[5:2] == 4'b0001)? `TYPESHIFTS://SHifter with some special operations
				  ((opcode[5:2] == 4'b0001 || (opcode == 6'b000001 && (rt == 5'b00001 || rt == 5'b00000)))? `TYPEBRANCH://BRANCH
				  ((opcode[5:1] == 5'b00001)? `TYPEJ://J with instr_index
				  ((opcode == `SPECIAL && funccode[5:1] == 5'b00100)? `TYPEJS://J with special operations
				  ((opcode[5:3] == 3'b100)? `TYPELOAD://Load
				  ((opcode[5:3] == 3'b101)? `TYPESTORE: //Store
				  ((opcode == `SPECIAL && funccode[5:1] == 5'b00101)? `TYPEMOVE://Move
				  ((opcode == 6'b001111)? 4'b1001: 4'b1010))))))))));//Lui


	/*Below are some controlling signals*/
	assign RegDst = (Type == `TYPEALUIMM || Type == `TYPELOAD || opcode == 6'b001111)? 1'b0:1'b1;//only when ALU Immediate word and Load word and lui, rt -> rd
	assign Jump = (Type == `TYPEJS || Type == `TYPEJ)? 1'b1:1'b0;//Jump onli when J instructions
	assign Branch = (Type == `TYPEBRANCH)? 1'b1:1'b0;//Branch Instructions
	assign MemRead = (Type == `TYPELOAD)? 1'b1:1'b0;//Load Instructions
	assign MemtoReg = (Type == `TYPELOAD)? 1'b1:1'b0;//Load Instructions
	assign MemWrite = (Type == `TYPESTORE)? 1'b1: 1'b0;//Store Instructions
	assign ALUsrc = (Type == `TYPEALUIMM || Type == `TYPELOAD || Type == `TYPESTORE)? 1'b1: 1'b0;//ALU Immediate & Load & Store Instructions
	assign ALU_control = (opcode[5:1] == `ADDI || (Type == `TYPEALUR && funccode == 6'b100001) || Type == `TYPELOAD || Type == `TYPESTORE)? `ALUOP_ADD:
						 (((Type == `TYPEALUR && funccode == 6'b100011) || (Type == 4'b0100 && opcode[5:1] == 5'b00010) || (Type == `TYPEMOVE))? `ALUOP_SUB:
						 (((Type == `TYPEALUIMM && opcode == 6'b001100) || (Type == `TYPEALUR && funccode == 6'b100100))? `ALUOP_AND:
						 (((Type == `TYPEALUIMM && opcode == 6'b001101) || (Type == `TYPEALUR && funccode == 6'b100101))? `ALUOP_OR:
						 (((Type == `TYPEALUIMM && opcode == 6'b001110) || (Type == `TYPEALUR && funccode == 6'b100110))? `ALUOP_XOR:
						 ((Type == `TYPEALUR && funccode == 6'b100111)? `ALUOP_NOR:
						 (((Type == `TYPEALUIMM && opcode == 6'b001010) || (Type == `TYPEALUR && funccode == 6'b101010) || (Type == 4'b0100 && opcode[5:1] != 5'b00010))? `ALUOP_STL:`ALUOP_SLTU))))));
	
	assign Shifter_control = ({funccode[5:3],funccode[1:0]} == 5'b00000 && opcode == `SPECIAL)? `SHIFTLEFT:
							 (({funccode[5:3],funccode[1:0]} == 5'b00011 && opcode == `SPECIAL)? `SHIFTRIGHTA:
							 (({funccode[5:3],funccode[1:0]} == 5'b00010 && opcode == `SPECIAL)? `SHIFTRIGHT: `SHIFTRIGHT));
	
	assign PC_4 = PC + 4;

	assign RF_wen = (Type == `TYPEBRANCH || Type == `TYPESTORE || opcode == 6'b000010 || (Type == `TYPEJS && funccode == 6'b001000) || (Type == `TYPEMOVE && funccode[0] == 1'b1 && Zero == 1)
					|| (Type == `TYPEMOVE && funccode[0] == 1'b0 && Zero == 0))? 1'b0: 1'b1;

	assign RF_waddr = (opcode == 6'b000011)? 31:((RegDst)? rd:rt);//control which data to write

	assign RF_wdata = (Type[3:1] == 3'b000)? ALU_result:
					  ((Type[3:1] == 3'b001)? shifter_result:
					  ((opcode == 6'b000011 || (Type == `TYPEJS && funccode == 6'b001001))? PC + 8:
					  ((Type == `TYPELOAD)? load_result:
					  ((Type == `TYPEMOVE)? rdata1:lui_extend))));

	assign RF_raddr1 = rs;
	assign RF_raddr2 = rt;

	reg_file ref_file_module(
		.clk(clk),
		.rst(rst),
		.waddr(RF_waddr),
		.raddr1(RF_raddr1),
		.raddr2(RF_raddr2),
		.wen(RF_wen),
		.wdata(RF_wdata),
		.rdata1(rdata1),
		.rdata2(rdata2)
	);




	assign opcode = Instruction[31:26];
	assign rs = Instruction[25:21];
	assign rt = Instruction[20:16];
	assign rd = Instruction[15:11];
	assign immediate = Instruction[15:0];
	assign funccode = Instruction[5:0];
	assign sa = Instruction[10:6];
	

	assign sign_extend = {{16{Instruction[15]}},Instruction[15:0]};//sign_extend
	assign zero_extend = {{16{1'b0}},Instruction[15:0]};//zero_extend
	assign offset_two_extend = {{14{Instruction[15]}},Instruction[15:0],2'b0};//offset_two_extend
	assign instr_two_extend = {PC_4[31:28],Instruction[25:0],2'b0};//instr_two_extend
	assign lui_extend = {immediate,16'b0};//lui_extend
	
	/*assign ALU_control = (opcode == `SPECIAL && funccode[3:2] == 2'b00)? {funccode[1],2'b10}:
						 ((opcode == `SPECIAL && funccode[3:2] == 2'b01)? {funccode[1],1'b0,funccode[0]}:
						 ((opcode == `SPECIAL && funccode[3:2] == 2'b10)? {~funccode[0],2'b11}:
						 ((opcode == `ADDI)? )))*/

	/*These signals aim to deal with shift instructions*/

	

	shifter shifter_module(
		.A(shiftop1),
		.B(shiftop2),
		.Shiftop(Shifter_control),
		.Result(shifter_result)
	);


	/*These signals aim to deal with branch instrcutions*/
	wire [31:0] branch_PC;

	alu alu_branch(
		.A(offset_two_extend),
		.B(PC_4),
		.ALUop(`ALUOP_ADD),
		.Result(branch_PC),
		.Overflow(),
		.CarryOut(),
		.Zero()
	); 


	wire [0:0] branchen;//To determine if branch or not
	
	assign branchen = ((Branch && opcode[5:1] == 5'b00010 && Zero == ~opcode[0]) || 
					   (opcode == 6'b000001 && rt == 5'b00001 && (ALU_result == 0 || rdata1 == 32'b0)) ||
					   (opcode == 6'b000111 && rt == 5'b00000 && ALU_result == 0) ||
					   (opcode == 6'b000110 && rt == 5'b00000 && (ALU_result != 0 || rdata1 == 32'b0))||
					   (opcode == 6'b000001 && rt == 5'b00000 && ALU_result != 0))? 1:0;


	/*These signals aim to deal with jump instructions*/
	wire [31:0] Jumpaddr;
	
	assign Jumpaddr = (opcode[5:1] == 5'b00001)? instr_two_extend:rdata1;
	
	always @(posedge clk) begin
		if(rst) begin
			PC <= 32'b0;
		end else begin
			PC <= Jump? Jumpaddr:((Branch & branchen)? branch_PC: PC_4);
		end
	end

	//////
	/*Below aim to use the most significant ALU*/
	

	assign extend = ((Type == `TYPEALUIMM && opcode[2] == 1) || (Type == `TYPELOAD && opcode[5:1] == 5'b10010))? zero_extend:sign_extend;
	assign aluop1 = (Type == 4'b1111)? rdata2:rdata1;
	assign aluop2 = (ALUsrc)? extend:
					(((Type == `TYPEBRANCH && opcode[5:1]!= 5'b00010) || Type == `TYPEMOVE)? 32'b0:rdata2);

	alu alu_module(
		.A(aluop1),
		.B(aluop2),
		.ALUop(ALU_control),
		.Result(ALU_result),
		.Overflow(),
		.CarryOut(),
		.Zero(Zero)
	);
	
	/*These signals aim to deal with Load instructions*/
	
	
	
	assign n = ALU_result[1:0];

	assign lb_result = (n[1] & n[0])? {{24{Read_data[31]}},Read_data[31:24]}:
					   ((n[1] & ~n[0])? {{24{Read_data[23]}},Read_data[23:16]}:
					   ((~n[1] & n[0])? {{24{Read_data[15]}},Read_data[15:8]}:{{24{Read_data[7]}},Read_data[7:0]}));
	assign lbu_result = {{24{1'b0}},lb_result[7:0]};

	assign lh_result = (~n[1])? {{16{Read_data[15]}},Read_data[15:0]}:{{16{Read_data[31]}},Read_data[31:16]}; 
	assign lhu_result = {{16{1'b0}},lh_result[15:0]};

	assign lw_result = Read_data[31:0];
	assign lwl_result = (n[1] & n[0])? Read_data[31:0]: 
						((n[1] & ~n[0])? {Read_data[23:0],rdata2[7:0]}:
						((~n[1] & n[0])? {Read_data[15:0],rdata2[15:0]}:{Read_data[7:0],rdata2[23:0]}));

	assign lwr_result = (~n[1] & ~n[0])? Read_data[31:0]:
						((~n[1] & n[0])? {rdata2[31:24],Read_data[31:8]}:
						((n[1] & ~n[0])? {rdata2[31:16],Read_data[31:16]}:{rdata2[31:8],Read_data[31:24]}));

	
	assign load_result = (opcode == 6'b100000)? lb_result:
						 ((opcode == 6'b100001)? lh_result:
						 ((opcode == 6'b100011)? lw_result:
						 ((opcode == 6'b100100)? lbu_result:
						 ((opcode == 6'b100101)? lhu_result:
						 ((opcode == 6'b100010)? lwl_result: lwr_result)))));

	/*These signals aim to deal with store instructions*/

	assign Address = {ALU_result[31:2],2'b00};//aligned address

	wire [3:0] sb_strb;
	wire [3:0] sh_strb;
	wire [3:0] sw_strb;
	wire [3:0] swl_strb;
	wire [3:0] swr_strb;

	assign sb_strb = (n[1] & n[0])? 4'b1000:
					 ((n[1] & ~n[0])? 4'b0100:
					 ((~n[1] & n[0])? 4'b0010: 4'b0001));
	assign sh_strb = (n[1])? 4'b1100: 4'b0011;
	assign sw_strb = 4'b1111;
	
	assign swl_strb = {ALU_result[1] & ALU_result[0], ALU_result[1], ALU_result[1] | ALU_result[0], 1'b1};
	assign swr_strb = {1'b1, ~(ALU_result[1] & ALU_result[0]), ~ALU_result[1], ~ALU_result[1] & ~ALU_result[0]};

	assign Write_strb = (opcode == 6'b101000)? sb_strb:
						((opcode == 6'b101001)? sh_strb:
						((opcode == 6'b101011)? sw_strb:
						((opcode == 6'b101010)? swl_strb:
						((opcode == 6'b101110)? swr_strb:swr_strb))));

	wire [31:0] sb_data;
	wire [31:0] sh_data;
	wire [31:0] sw_data;
	wire [31:0] swl_data;
	wire [31:0] swr_data;

	assign sb_data = (n[1] & n[0])? {rdata2[7:0],{24{1'b0}}}:
					 ((n[1] & ~n[0])? {{8{1'b0}},rdata2[7:0],{16{1'b0}}}:
					 ((~n[1] & n[0])? {{16{1'b0}},rdata2[7:0],{8{1'b0}}}: {{24{1'b0}},rdata2[7:0]}));

	assign sh_data = (n[1])? {rdata2[15:0],{16{1'b0}}}: {{16{1'b0}},rdata2[15:0]};

	assign sw_data = rdata2[31:0];

	assign swl_data = (swl_strb == 4'b0001)? {{24{1'b0}},rdata2[31:24]}:
					  ((swl_strb == 4'b0011)? {{16{1'b0}},rdata2[31:16]}:
					  ((swl_strb == 4'b0111)? {{8{1'b0}},rdata2[31:8]}:rdata2[31:0]));

	assign swr_data = (swr_strb == 4'b1111)? rdata2[31:0]:
					  ((swr_strb == 4'b1110)? {rdata2[23:0],{8{1'b0}}}:
					  ((swr_strb == 4'b1100)? {rdata2[15:0],{16{1'b0}}}:{rdata2[7:0],{24{1'b0}}}));

	assign Write_data = (opcode == 6'b101000)? sb_data:
						((opcode == 6'b101001)? sh_data:
						((opcode == 6'b101011)? sw_data:
						((opcode == 6'b101010)? swl_data:
						((opcode == 6'b101110)? swr_data: swr_data))));
 	
endmodule
