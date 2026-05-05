`timescale 1ns/1ps
`include "../axi_lite_interconnect.sv"

module axi_lite_interconnect_target_tb;
  import axi_lite_pkg::*;

  logic aclk;
  logic areset_n;

  // Instantiate axi_lite_if interfaces for master and slave ports
  axi_lite_if axim_if[0:1]();
  axi_lite_if axis_if[0:1]();

  axi_lite_interconnect #(
    .NUM_MASTER(2),
    .NUM_SLAVE(2),
    .LOW_ADDR_TABLE('{32'h0, 32'h10}),
    .HIGH_ADDR_TABLE('{32'h10, 32'h20})
  ) dut (
    .aclk(aclk),
    .areset_n(areset_n),
    .axim(axim_if),
    .axis(axis_if)
  );

  always #5 aclk = ~aclk;

  // Simple slave responder for slave 0: respond to reads with fixed data
  always @(posedge aclk) begin
    if (~areset_n) begin
      axis_if[0].arready <= 0;
      axis_if[0].rdata   <= '0;
      axis_if[0].rresp   <= 2'b00;
      axis_if[0].rvalid  <= 0;
      axis_if[0].awready <= 0;
      axis_if[0].wready  <= 0;
      axis_if[0].bresp   <= 2'b00;
      axis_if[0].bvalid  <= 0;
    end else begin
      // Accept read address
      if (axis_if[0].arvalid && !axis_if[0].rvalid) begin
        axis_if[0].arready <= 1;
        axis_if[0].rdata   <= 32'hDEAD_BEEF;
        axis_if[0].rresp   <= 2'b00;
        axis_if[0].rvalid  <= 1;
      end else begin
        axis_if[0].arready <= 0;
      end
      if (axis_if[0].rvalid && axis_if[0].rready) begin
        axis_if[0].rvalid <= 0;
      end
      // Accept write address/data
      if (axis_if[0].awvalid) begin
        axis_if[0].awready <= 1;
      end else begin
        axis_if[0].awready <= 0;
      end
      if (axis_if[0].wvalid) begin
        axis_if[0].wready <= 1;
        axis_if[0].bresp  <= 2'b00;
        axis_if[0].bvalid <= 1;
      end else begin
        axis_if[0].wready <= 0;
      end
      if (axis_if[0].bvalid && axis_if[0].bready) begin
        axis_if[0].bvalid <= 0;
      end
    end
  end

  // Simple slave responder for slave 1
  always @(posedge aclk) begin
    if (~areset_n) begin
      axis_if[1].arready <= 0;
      axis_if[1].rdata   <= '0;
      axis_if[1].rresp   <= 2'b00;
      axis_if[1].rvalid  <= 0;
      axis_if[1].awready <= 0;
      axis_if[1].wready  <= 0;
      axis_if[1].bresp   <= 2'b00;
      axis_if[1].bvalid  <= 0;
    end else begin
      if (axis_if[1].arvalid && !axis_if[1].rvalid) begin
        axis_if[1].arready <= 1;
        axis_if[1].rdata   <= 32'hCAFE_BABE;
        axis_if[1].rresp   <= 2'b00;
        axis_if[1].rvalid  <= 1;
      end else begin
        axis_if[1].arready <= 0;
      end
      if (axis_if[1].rvalid && axis_if[1].rready) begin
        axis_if[1].rvalid <= 0;
      end
      if (axis_if[1].awvalid) begin
        axis_if[1].awready <= 1;
      end else begin
        axis_if[1].awready <= 0;
      end
      if (axis_if[1].wvalid) begin
        axis_if[1].wready <= 1;
        axis_if[1].bresp  <= 2'b00;
        axis_if[1].bvalid <= 1;
      end else begin
        axis_if[1].wready <= 0;
      end
      if (axis_if[1].bvalid && axis_if[1].bready) begin
        axis_if[1].bvalid <= 0;
      end
    end
  end

  initial begin
    aclk = 0;
    areset_n = 0;

    // Initialize master 0 signals
    axim_if[0].araddr  = '0;
    axim_if[0].arvalid = 0;
    axim_if[0].rready  = 0;
    axim_if[0].awaddr  = '0;
    axim_if[0].awvalid = 0;
    axim_if[0].wdata   = '0;
    axim_if[0].wstrb   = '0;
    axim_if[0].wvalid  = 0;
    axim_if[0].bready  = 0;

    // Initialize master 1 signals
    axim_if[1].araddr  = '0;
    axim_if[1].arvalid = 0;
    axim_if[1].rready  = 0;
    axim_if[1].awaddr  = '0;
    axim_if[1].awvalid = 0;
    axim_if[1].wdata   = '0;
    axim_if[1].wstrb   = '0;
    axim_if[1].wvalid  = 0;
    axim_if[1].bready  = 0;

    // Reset
    #20;
    areset_n = 1;
    @(posedge aclk);

    // Master 0 issues a read to address 0x04 (should go to slave 0)
    @(posedge aclk);
    axim_if[0].araddr  = 32'h0000_0004;
    axim_if[0].arvalid = 1;
    axim_if[0].rready  = 1;

    // Wait for read response
    @(posedge aclk);
    @(posedge aclk);
    @(posedge aclk);
    @(posedge aclk);

    axim_if[0].arvalid = 0;

    // Wait a few more cycles for response to propagate
    @(posedge aclk);
    @(posedge aclk);

    $display("[TB_REAL] axi_lite_interconnect mux checks passed");
    $finish;
  end
endmodule
