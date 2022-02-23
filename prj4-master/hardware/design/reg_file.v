`timescale 10 ns / 1 ns

`define DATA_WIDTH 32
`define ADDR_WIDTH 5

module reg_file(
	input clk,
	input rst,
	input [`ADDR_WIDTH - 1:0] waddr,
	input [`ADDR_WIDTH - 1:0] raddr1,
	input [`ADDR_WIDTH - 1:0] raddr2,
	input wen,
	input [`DATA_WIDTH - 1:0] wdata,
	output [`DATA_WIDTH - 1:0] rdata1,
	output [`DATA_WIDTH - 1:0] rdata2
);

	// TODO: Please add your logic code here
	reg [31:0] reg_file [31:0];
	always @(posedge clk)
	begin
	reg_file[0] <= 32'b0;
	if(wen && waddr)
		begin
		reg_file[waddr] <= wdata;
		end
	end

	assign rdata1 = reg_file[raddr1];
	assign rdata2 = reg_file[raddr2];
	
endmodule
