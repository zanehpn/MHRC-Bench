`default_nettype none
`timescale 1 ns / 10 ps

module miner (input logic [639:0] block,
			input logic clk, rst,
			output logic [255:0] hashed,
			output logic done);
	
	logic [255:0] first_hash;
	logic [255:0] secnd_hash;

	logic second_run_rst;
	logic done_first_hash;
	logic done_secnd_hash;

	sha_256 #(.MSG_SIZE(640), .PADDED_SIZE(1024)) first (.message(block), .hashed(first_hash), .clk(clk), .rst(rst), .done(done_first_hash));
	sha_256 #(.MSG_SIZE(256), .PADDED_SIZE(512)) second (.message(first_hash), .hashed(secnd_hash), .clk(clk), .rst(second_run_rst), .done(done_secnd_hash));

	// always @* second_run_rst <= 1'b0;

	always @(posedge clk) begin
		if (done_first_hash === 1'bX) second_run_rst <= 1'b1;
		else if (done_first_hash == 1'b1) second_run_rst <= 1'b0;
	end

	assign done = done_secnd_hash;
<TARGET>
