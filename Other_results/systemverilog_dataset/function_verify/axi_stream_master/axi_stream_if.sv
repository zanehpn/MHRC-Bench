`timescale 1ns/1ps
import axi_stream_pkg::*;

interface axi_stream_if;

	logic tvalid;
	logic tready;
	logic tlast;
	data_t tdata;


	modport master (
		output tvalid, input tready, output tlast, tdata
	);

	modport slave (
		input tvalid, output tready, input tlast, tdata
	);

endinterface
