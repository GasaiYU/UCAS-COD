`timescale 10ns / 1ns

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

`define JALR 7'b1100111


module custom_cpu(
	input  rst,
	input  clk,

	//Instruction request channel
	output reg [31:0] PC,
	output Inst_Req_Valid,
	input Inst_Req_Ready,

	//Instruction response channel
	input  [31:0] Instruction,
	input Inst_Valid,
	output Inst_Ready,

	//Memory request channel
	output [31:0] Address,
	output MemWrite,
	output [31:0] Write_data,
	output [3:0] Write_strb,
	output MemRead,
	input Mem_Req_Ready,

	//Memory data response channel
	input  [31:0] Read_data,
	input Read_data_Valid,
	output Read_data_Ready, 

    output [31:0]	cpu_perf_cnt_0,
    output [31:0]	cpu_perf_cnt_1,
    output [31:0]	cpu_perf_cnt_2,
    output [31:0]	cpu_perf_cnt_3,
    output [31:0]	cpu_perf_cnt_4,
    output [31:0]	cpu_perf_cnt_5,
    output [31:0]	cpu_perf_cnt_6,
    output [31:0]	cpu_perf_cnt_7,
    output [31:0]	cpu_perf_cnt_8,
    output [31:0]	cpu_perf_cnt_9,
    output [31:0]	cpu_perf_cnt_10,
    output [31:0]	cpu_perf_cnt_11,
    output [31:0]	cpu_perf_cnt_12,
    output [31:0]	cpu_perf_cnt_13,
    output [31:0]	cpu_perf_cnt_14,
    output [31:0]	cpu_perf_cnt_15

);

  //TODO: Please add your RISC-V CPU code here

  	wire			RF_wen;
	wire [4:0]		RF_waddr;
	wire [31:0]		RF_wdata;

  	/*Use One-Hot code to describe state*/
	parameter RST  = 9'b000000001;
	parameter IF   = 9'b000000010;
	parameter IW   = 9'b000000100;
	parameter ID   = 9'b000001000;
	parameter EX   = 9'b000010000;
	parameter LD   = 9'b000100000;
	parameter ST   = 9'b001000000;
	parameter RDW  = 9'b010000000;
	parameter WB   = 9'b100000000;

	
	/*use one hot code to describe Type*/
	parameter BType = 7'b0000001;
	parameter RType = 7'b0000010;
	parameter IType = 7'b0000100;
	parameter UType = 7'b0001000;
	parameter JType = 7'b0010000;
	parameter SType = 7'b0100000;
	parameter LType = 7'b1000000;

	/*SORT TYPES*/
	wire [6:0] Type;
	wire [6:0] opcode;
	wire [4:0] rd;
	wire [2:0] funct3;
	wire [4:0] rs1;
	wire [4:0] rs2;
	wire [6:0] funct7;
	wire [11:0] I_imm;
	wire [19:0] JU_imm;
	wire [4:0] shamt;
	wire [31:0] PC_4;

	wire [0:0] Jump;
	wire [0:0] Branch;
	wire [0:0] MemtoReg;
	wire [3:0] ALU_control;
	wire [0:0] ALUsrc;
	wire [1:0] Shifter_control;

	wire [4:0] RF_raddr1;
	wire [4:0] RF_raddr2;
	wire [31:0]rdata1;
	wire [31:0]rdata2;

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
	wire [1:0] n;
	wire [31:0] load_result;

	wire [31:0] shifter_result;
	wire [31:0] shiftop1;
	wire [31:0] shiftop2;

	wire [31:0] U_Result;
	wire [31:0] J_Result;

	reg [31:0] current_state;
	reg [31:0] next_state;
	reg [31:0] valid_Instruction;
	reg [31:0] valid_Read_data;
	reg [31:0] pre_PC;
	
	
	assign opcode = valid_Instruction[6 : 0];
	assign rd     = valid_Instruction[11: 7];
	assign funct3 = valid_Instruction[14:12];
	assign rs1    = valid_Instruction[19:15];
	assign rs2    = valid_Instruction[24:20];
	assign funct7 = valid_Instruction[31:25];
	assign I_imm  = valid_Instruction[31:20];
	assign JU_imm = valid_Instruction[31:12];
	assign shamt  = valid_Instruction[24:20];


	assign Type = ({opcode[6],opcode[4:0]} == 6'b010111)? UType:
		          ((opcode == 7'b1100011)? BType:
				  ((opcode == 7'b1101111)? JType:
				  ((opcode == 7'b0100011)? SType:
				  ((opcode == 7'b0110011)? RType:
				  ((opcode == 7'b0000011)? LType: IType)))));

	assign PC_4 = PC + 4;

	/*Below are some control signals*/
	assign Jump = (Type == JType || opcode == 7'b1100111)? 1'b1:1'b0;
	assign Branch = (Type == BType)? 1'b1: 1'b0;
	assign MemtoReg = (Type == LType)? 1'b1: 1'b0;

	assign ALU_control = (Type == LType || Type == SType || (Type == IType && funct3 == 3'b000 && opcode != `JALR) || (Type == RType && funct3 == 3'b000 && funct7 == 7'b0000000) || opcode == `JALR)? `ALUOP_ADD:
						 ((Type == BType && funct3[2:1] == 2'b00) || (Type == RType && funct3 == 3'b000 && funct7 == 7'b0100000))? `ALUOP_SUB:
						 ((Type == IType && funct3 == 3'b111 && opcode != `JALR) || (Type == RType && funct3 == 3'b111 && funct7 == 7'b0000000))? `ALUOP_AND:
						 ((Type == IType && funct3 == 3'b110 && opcode != `JALR) || (Type == RType && funct3 == 3'b110 && funct7 == 7'b0000000))? `ALUOP_OR:
						 ((Type == IType && funct3 == 3'b100 && opcode != `JALR) || (Type == RType && funct3 == 3'b100 && funct7 == 7'b0000000))? `ALUOP_XOR:
						 ((Type == BType && funct3[2:1] == 2'b10) || (Type == IType && funct3 == 3'b010 && opcode != `JALR) && (Type == RType && funct3 == 3'b010 && funct7 == 7'b0000000))? `ALUOP_STL:
						 ((Type == BType && funct3[2:1] == 2'b11) || (Type == IType && funct3 == 3'b011 && opcode != `JALR) && (Type == RType && funct3 == 3'b011 && funct7 == 7'b0000000))? `ALUOP_SLTU: `ALUOP_SLTU;


	assign Shifter_control = ((Type == IType && funct3 == 3'b001 && opcode != `JALR) || (Type == RType && funct3 == 3'b001))? `SHIFTLEFT:
							 ((Type == IType || Type == RType) && funct7 == 7'b0000000 && funct3 == 3'b101 && opcode != `JALR)? `SHIFTRIGHT:`SHIFTRIGHTA;


	/*Below aims to deal with RF*/
	wire [31:0] lui_extend;

	assign lui_extend = {JU_imm,12'b0};

	assign RF_wen = (current_state == WB)? 1'b1:1'b0;
	assign RF_waddr = rd;
	assign RF_wdata = ((Type == IType || Type == RType) && (funct3 == 3'b001 || funct3 == 3'b101))? shifter_result:
					  (opcode == 7'b0110111)? lui_extend:
					  (opcode == 7'b0010111)? alui_result:
					  (Type == LType)? load_result:
					  (Type == JType || opcode == `JALR)? pre_PC + 4: ALU_result;


	assign RF_raddr1 = rs1;
	assign RF_raddr2 = rs2;

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

	///////
	/*These signals aim to use the most significant alu*/
	wire [31:0] Store_extend;
	wire [31:0] I_extend;

	assign I_extend = {{20{valid_Instruction[31]}},I_imm};
	assign Store_extend = {{20{valid_Instruction[31]}},funct7,rd};


	assign aluop1 = rdata1;
	assign aluop2 = (Type == IType || Type == LType)? I_extend:
					(Type == SType)? Store_extend:rdata2;

	alu alu_module(
		.A(aluop1),
		.B(aluop2),
		.ALUop(ALU_control),
		.Result(ALU_result),
		.Overflow(),
		.CarryOut(),
		.Zero(Zero)
	);


	/*These signals aim to deal with shifter insturctions*/
	assign shiftop1 = rdata1;
	assign shiftop2 = (Type == IType)? {27'b0,shamt}:{27'b0, rdata2[4:0]};

	shifter shifter_module(
		.A(shiftop1),
		.B(shiftop2),
		.Shiftop(Shifter_control),
		.Result(shifter_result)
	);

	/*These signals aim to deal with branch instrcutions*/
	wire [31:0] branch_PC;
	wire [31:0] branch_signed_offset;
	wire [0:0]  branchen;

	assign branch_signed_offset = {{20{valid_Instruction[31]}},valid_Instruction[7],valid_Instruction[30:25],rd[4:1],1'b0};
	assign branchen = ((funct3 == 3'b000 && Zero == 1)||
					   (funct3 == 3'b001 && Zero == 0)||
					   ((funct3 == 3'b100 || funct3 == 3'b110) && ALU_result == 1)||
					   ((funct3 == 3'b101 || funct3 == 3'b111) && ALU_result == 0))? 1'b1:1'b0;

	alu alu_branch(
		.A(branch_signed_offset),
		.B(pre_PC),
		.ALUop(`ALUOP_ADD),
		.Result(branch_PC),
		.Overflow(),
		.CarryOut(),
		.Zero()
	); 

	
	/*These signals aim to deal with jump instructions*/
	wire [31:0] Jumpaddr;
	wire [31:0] Jump_extend;
	wire [31:0] Jal_PC;

	assign Jump_extend = {{12{valid_Instruction[31]}},valid_Instruction[19:12],valid_Instruction[20],valid_Instruction[30:21],1'b0};
	
	alu alu_jump(
		.A(Jump_extend),
		.B(pre_PC),
		.ALUop(`ALUOP_ADD),
		.Result(Jal_PC),
		.Overflow(),
		.CarryOut(),
		.Zero()
	); 

	assign Jumpaddr = (opcode == `JALR)? {ALU_result[31:1],1'b0}: Jal_PC;

	/*These signals aim to deal with ALUI-instrutions*/
	wire [31:0] alui_result;

	alu alu_u(
		.A(lui_extend),
		.B(pre_PC),
		.ALUop(`ALUOP_ADD),
		.Result(alui_result),
		.Overflow(),
		.CarryOut(),
		.Zero()
	); 

	/*These signals aim to deal with load and store instructions*/

	assign n = ALU_result[1:0];

	assign lb_result = (n[1] & n[0])? {{24{valid_Read_data[31]}},valid_Read_data[31:24]}:
					   ((n[1] & ~n[0])? {{24{valid_Read_data[23]}},valid_Read_data[23:16]}:
					   ((~n[1] & n[0])? {{24{valid_Read_data[15]}},valid_Read_data[15:8]}:{{24{valid_Read_data[7]}},valid_Read_data[7:0]}));
	assign lbu_result = {{24{1'b0}},lb_result[7:0]};

	assign lh_result = (~n[1])? {{16{valid_Read_data[15]}},valid_Read_data[15:0]}:{{16{valid_Read_data[31]}},valid_Read_data[31:16]}; 
	assign lhu_result = {{16{1'b0}},lh_result[15:0]};

	assign lw_result = valid_Read_data[31:0];

	
	assign load_result = (funct3 == 3'b000)? lb_result:
						 (funct3 == 3'b001)? lh_result:
						 (funct3 == 3'b010)? lw_result:
						 (funct3 == 3'b100)? lbu_result:lhu_result;


	assign Address = {ALU_result[31:2],2'b00};//aligned address

	wire [3:0] sb_strb;
	wire [3:0] sh_strb;
	wire [3:0] sw_strb;
	

	assign sb_strb = (n[1] & n[0])? 4'b1000:
					 ((n[1] & ~n[0])? 4'b0100:
					 ((~n[1] & n[0])? 4'b0010: 4'b0001));

	assign sh_strb = (n[1])? 4'b1100: 4'b0011;
	assign sw_strb = 4'b1111;
	


	assign Write_strb = (funct3 == 3'b000)? sb_strb:
						(funct3 == 3'b001)? sh_strb: sw_strb;

	
	wire [31:0] sb_data;
	wire [31:0] sh_data;
	wire [31:0] sw_data;

	assign sb_data = (n[1] & n[0])? {rdata2[7:0],{24{1'b0}}}:
					 ((n[1] & ~n[0])? {{8{1'b0}},rdata2[7:0],{16{1'b0}}}:
					 ((~n[1] & n[0])? {{16{1'b0}},rdata2[7:0],{8{1'b0}}}: {{24{1'b0}},rdata2[7:0]}));

	assign sh_data = (n[1])? {rdata2[15:0],{16{1'b0}}}: {{16{1'b0}},rdata2[15:0]};

	assign sw_data = rdata2[31:0];

	assign Write_data = (funct3 == 3'b000)? sb_data:
						(funct3 == 3'b001)? sh_data: sw_data;
	
	/*Use three stanzas to describe state machinery*/
	/*The first stanza*/
	
	always @(posedge clk) begin
		if(rst) begin
			current_state <= RST;
		end else begin
			current_state <= next_state;
		end
	end
	
	/*The second stanza*/

	always @(*) begin
		case(current_state)
			RST: 
				next_state = IF;
			IF: 
				if(Inst_Req_Ready) begin
					next_state = IW;
				end else begin
					next_state = IF;
				end
			IW:
				if(Inst_Valid) begin
					next_state = ID;
				end else begin
					next_state = IW;
				end
			ID:	
				if(valid_Instruction[31:0] == 32'b0) begin
					next_state = IF;
				end else begin
					next_state = EX;
				end
			EX:
				if(Type == LType) begin
					next_state = LD;
				end else if(Type == SType) begin
					next_state = ST;
				end else if(Type == BType) begin
					next_state = IF;
				end else begin
					next_state = WB;
				end
			LD:
				if(Mem_Req_Ready) begin
					next_state = RDW;
				end else begin
					next_state = LD;
				end
			RDW:
				if(Read_data_Valid) begin
					next_state = WB;
				end	else begin
					next_state = RDW;
				end
			WB:
				next_state = IF;
			ST:
				if(Mem_Req_Ready) begin
					next_state = IF;
				end else begin
					next_state = ST;
				end
			default:
				next_state = RST;
		endcase
	end

	/*The third stanza*/
	//To Store Pre_PC
	always @(posedge clk) begin
		if(current_state == IF) begin
			pre_PC <= PC;
		end else begin
			pre_PC <=  pre_PC;
		end
	end

	//PC_value change
	always @(posedge clk) begin
		if(rst) begin
			PC <= 32'b0;
		end else if(current_state == EX) begin
			PC <= Jump? Jumpaddr:((Branch & branchen)? branch_PC: PC_4);
		end else if(valid_Instruction == 32'b0 && valid_Instruction == ID) begin
			PC <= PC_4;
		end else 
			PC <= PC;
	end

	assign Inst_Req_Valid  = current_state == IF;//Only if instruction
	assign Inst_Ready      = (current_state == IW || current_state == RST);
	assign Read_data_Ready = (current_state == RDW || current_state == RST);
	assign MemRead         = current_state == LD;//Load Instructions
	assign MemWrite        = current_state == ST;//Store Instructions

	//shake hands
	always @(posedge clk) begin
		/*If shake hands successfully, then change Instructions, else do not change*/
		valid_Instruction <= (Inst_Ready && Inst_Valid)? Instruction:valid_Instruction;
	end

	always @(posedge clk) begin
		/*If shake hands successfully, then change Read_data, else do not change*/
		valid_Read_data <= (Read_data_Ready && Read_data_Valid)? Read_data: valid_Read_data;
	end

	//Below are some counting signals

	/*The number of visiting mem*/
	reg [31:0] Mem_cnt;

	always @(posedge clk) begin
		if(rst) begin
			Mem_cnt <= 32'd0;
		end else if((MemRead || MemWrite) && Mem_Req_Ready) begin
			Mem_cnt <= Mem_cnt + 32'd1;
		end else begin
			Mem_cnt <= Mem_cnt;
		end
	end
	
	assign cpu_perf_cnt_0 = Mem_cnt;

	/*The number of cycle*/
	reg [31:0] cycle_cnt;

	always @(posedge clk) begin
		if(rst) begin
			cycle_cnt <= 32'd0;
		end else begin
			cycle_cnt <= cycle_cnt + 32'd1;
		end
	end
	assign cpu_perf_cnt_1 = cycle_cnt;

	/*The number of branch*/
	reg [31:0] Branch_cnt;

	always @(posedge clk) begin
		if(rst) begin
			Branch_cnt <= 32'd0;
		end else if(current_state == EX && branchen && Branch) begin
			Branch_cnt <= Branch_cnt + 32'd1;
		end else begin
			Branch_cnt <= Branch_cnt;
		end
	end

	assign cpu_perf_cnt_2 = Branch_cnt;

	/*The number of Instrutions*/
	reg [31:0] Ins_cnt;

	always @(posedge clk) begin
		if(rst) begin
			Ins_cnt <= 32'd0;
		end else if(Inst_Ready && Inst_Valid) begin
			Ins_cnt <= Ins_cnt + 1;
		end else begin
			Ins_cnt <= Ins_cnt;
		end
	end

	assign cpu_perf_cnt_3 = Ins_cnt;

endmodule

