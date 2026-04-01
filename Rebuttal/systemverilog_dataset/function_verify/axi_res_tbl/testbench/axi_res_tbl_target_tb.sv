`timescale 1ns/1ps
`include "../axi_res_tbl_original.sv"

// TARGET: line 60 in axi_res_tbl.sv - combinational check logic:
//   if (check_clr_req_i) begin
//       check_clr_gnt_o = 1'b1;
// This handles the check_clr_req_i request path: grants the request and
// sets up the check_res_o and clr signals.

module axi_res_tbl_target_tb;
  localparam AXI_ADDR_WIDTH = 8;
  localparam AXI_ID_WIDTH   = 2;

  logic                        clk_i;
  logic                        rst_ni;
  logic [AXI_ADDR_WIDTH-1:0]   check_clr_addr_i;
  logic [AXI_ID_WIDTH-1:0]     check_id_i;
  logic                        check_clr_excl_i;
  logic                        check_res_o;
  logic                        check_clr_req_i;
  logic                        check_clr_gnt_o;
  logic [AXI_ADDR_WIDTH-1:0]   set_addr_i;
  logic [AXI_ID_WIDTH-1:0]     set_id_i;
  logic                        set_req_i;
  logic                        set_gnt_o;

  axi_res_tbl #(
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH)
  ) dut (
    .clk_i           (clk_i),
    .rst_ni          (rst_ni),
    .check_clr_addr_i(check_clr_addr_i),
    .check_id_i      (check_id_i),
    .check_clr_excl_i(check_clr_excl_i),
    .check_res_o     (check_res_o),
    .check_clr_req_i (check_clr_req_i),
    .check_clr_gnt_o (check_clr_gnt_o),
    .set_addr_i      (set_addr_i),
    .set_id_i        (set_id_i),
    .set_req_i       (set_req_i),
    .set_gnt_o       (set_gnt_o)
  );

  always #5 clk_i = ~clk_i;

  int pass_count = 0;
  int fail_count = 0;
  int total_tests = 0;

  task automatic check_val(string name, logic cond);
    total_tests++;
    if (!cond) begin
      $display("FAIL: %s", name);
      fail_count++;
    end else begin
      pass_count++;
    end
  endtask

  initial begin
    clk_i = 0; rst_ni = 0;
    check_clr_addr_i = 0; check_id_i = 0; check_clr_excl_i = 0;
    check_clr_req_i = 0;
    set_addr_i = 0; set_id_i = 0; set_req_i = 0;

    // Reset
    @(posedge clk_i); #1;
    rst_ni = 1;
    @(posedge clk_i); #1;

    // T1: No request => all outputs 0
    check_val("T1: no req, check_clr_gnt=0", check_clr_gnt_o === 1'b0);
    check_val("T2: no req, check_res=0", check_res_o === 1'b0);
    check_val("T3: no req, set_gnt=0", set_gnt_o === 1'b0);

    // T4-T5: Set reservation: id=0, addr=0x10
    set_addr_i = 8'h10; set_id_i = 2'd0; set_req_i = 1;
    check_clr_req_i = 0;
    #1;
    check_val("T4: set_gnt=1 on set_req", set_gnt_o === 1'b1);
    check_val("T5: check_clr_gnt=0 during set", check_clr_gnt_o === 1'b0);
    @(posedge clk_i); #1;
    set_req_i = 0;

    // T6-T8: Check reservation: id=0, addr=0x10, should match
    @(posedge clk_i); #1;
    check_clr_addr_i = 8'h10; check_id_i = 2'd0;
    check_clr_excl_i = 1; // exclusive: don't clear if match
    check_clr_req_i = 1;
    #1;
    check_val("T6: check_clr_gnt=1", check_clr_gnt_o === 1'b1);
    check_val("T7: check_res=1 (match)", check_res_o === 1'b1);
    // With excl=1 and match=1: clr = !(1 && !1) = !(0) = 1... wait:
    // clr = !(check_clr_excl_i && !match) = !(1 && !1) = !(1 && 0) = !(0) = 1
    // So it DOES clear on exclusive match. That means the entry will be cleared.
    @(posedge clk_i); #1;
    check_clr_req_i = 0;

    // T9: Check with wrong address: should not match
    @(posedge clk_i); #1;
    check_clr_addr_i = 8'hFF; check_id_i = 2'd0;
    check_clr_excl_i = 0;
    check_clr_req_i = 1;
    #1;
    check_val("T8: check_clr_gnt=1 wrong addr", check_clr_gnt_o === 1'b1);
    check_val("T9: check_res=0 (no match)", check_res_o === 1'b0);
    @(posedge clk_i); #1;
    check_clr_req_i = 0;

    // T10-T11: Set reservation for different ID: id=1, addr=0x20
    set_addr_i = 8'h20; set_id_i = 2'd1; set_req_i = 1;
    #1;
    check_val("T10: set_gnt=1 id=1", set_gnt_o === 1'b1);
    @(posedge clk_i); #1;
    set_req_i = 0;

    // T12: Check id=1, addr=0x20 => match
    @(posedge clk_i);
    check_clr_addr_i = 8'h20; check_id_i = 2'd1;
    check_clr_excl_i = 1;
    check_clr_req_i = 1;
    #1;
    check_val("T11: check_clr_gnt=1 id=1", check_clr_gnt_o === 1'b1);
    check_val("T12: check_res=1 id=1 match", check_res_o === 1'b1);
    @(posedge clk_i); #1;
    check_clr_req_i = 0;

    // T13: Check id=1, addr=0x20 with excl=0 (non-exclusive)
    // First re-set it since it was cleared
    set_addr_i = 8'h20; set_id_i = 2'd1; set_req_i = 1;
    @(posedge clk_i); #1;
    set_req_i = 0;
    @(posedge clk_i);
    check_clr_addr_i = 8'h20; check_id_i = 2'd1;
    check_clr_excl_i = 0;
    check_clr_req_i = 1;
    #1;
    check_val("T13: non-excl check_res=1", check_res_o === 1'b1);
    // clr = !(0 && !1) = !(0) = 1, so it clears
    @(posedge clk_i); #1;
    check_clr_req_i = 0;

    // T14: After clearing, check again - should not match (addr was cleared to 0)
    @(posedge clk_i);
    check_clr_addr_i = 8'h20; check_id_i = 2'd1;
    check_clr_excl_i = 0;
    check_clr_req_i = 1;
    #1;
    check_val("T14: after clear check_res=0", check_res_o === 1'b0);
    @(posedge clk_i); #1;
    check_clr_req_i = 0;

    // T15-T16: Priority: check_clr_req has priority over set_req
    set_addr_i = 8'h30; set_id_i = 2'd2; set_req_i = 1;
    check_clr_addr_i = 8'h00; check_id_i = 2'd0;
    check_clr_excl_i = 0;
    check_clr_req_i = 1;
    #1;
    check_val("T15: check_clr_gnt=1 (priority)", check_clr_gnt_o === 1'b1);
    check_val("T16: set_gnt=0 (lower priority)", set_gnt_o === 1'b0);
    @(posedge clk_i); #1;
    check_clr_req_i = 0; set_req_i = 0;

    // T17-T18: Set reservations for all IDs
    for (int id = 0; id < 4; id++) begin
      set_addr_i = 8'h40 + id; set_id_i = id[1:0]; set_req_i = 1;
      @(posedge clk_i); #1;
    end
    set_req_i = 0;

    // T19-T22: Check all IDs
    @(posedge clk_i);
    for (int id = 0; id < 4; id++) begin
      check_clr_addr_i = 8'h40 + id; check_id_i = id[1:0];
      check_clr_excl_i = 1;
      check_clr_req_i = 1;
      #1;
      check_val($sformatf("T%0d: check id=%0d match", 17+id, id), check_res_o === 1'b1);
      check_val($sformatf("T%0d: gnt id=%0d", 17+id, id), check_clr_gnt_o === 1'b1);
      @(posedge clk_i); #1;
    end
    check_clr_req_i = 0;

    // T23: Check wrong ID for an address
    @(posedge clk_i);
    // Re-set id=0 to addr 0x50
    set_addr_i = 8'h50; set_id_i = 2'd0; set_req_i = 1;
    @(posedge clk_i); #1;
    set_req_i = 0;
    @(posedge clk_i);
    check_clr_addr_i = 8'h50; check_id_i = 2'd1; // wrong ID
    check_clr_excl_i = 1;
    check_clr_req_i = 1;
    #1;
    check_val("T21: wrong id no match", check_res_o === 1'b0);
    @(posedge clk_i); #1;
    check_clr_req_i = 0;

    // T24: Exclusive check with no match - clr should NOT happen
    // clr = !(check_clr_excl_i && !match) = !(1 && 1) = 0
    // So entry should NOT be cleared
    // Set id=2, addr=0x60
    set_addr_i = 8'h60; set_id_i = 2'd2; set_req_i = 1;
    @(posedge clk_i); #1;
    set_req_i = 0;
    @(posedge clk_i);
    check_clr_addr_i = 8'hFF; check_id_i = 2'd2; // no match
    check_clr_excl_i = 1;
    check_clr_req_i = 1;
    #1;
    check_val("T22: excl no match res=0", check_res_o === 1'b0);
    // clr = !(1 && !0) = !(1 && 1) = 0, no clear
    @(posedge clk_i); #1;
    check_clr_req_i = 0;

    // T25: Verify entry still exists
    @(posedge clk_i);
    check_clr_addr_i = 8'h60; check_id_i = 2'd2;
    check_clr_excl_i = 0;
    check_clr_req_i = 1;
    #1;
    check_val("T23: entry preserved after excl no-match", check_res_o === 1'b1);
    @(posedge clk_i); #1;
    check_clr_req_i = 0;

    // T26: Reset clears all reservations
    rst_ni = 0;
    @(posedge clk_i); #1;
    rst_ni = 1;
    @(posedge clk_i); #1;

    check_clr_addr_i = 8'h60; check_id_i = 2'd2;
    check_clr_excl_i = 0;
    check_clr_req_i = 1;
    #1;
    check_val("T24: after reset no match", check_res_o === 1'b0);
    check_val("T25: after reset gnt=1", check_clr_gnt_o === 1'b1);
    @(posedge clk_i); #1;
    check_clr_req_i = 0;

    repeat(3) @(posedge clk_i);

    if (fail_count == 0)
      $display("[TB_REAL] axi_res_tbl check/clear logic tests PASSED");
    else
      $display("[TB_REAL] axi_res_tbl FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end

  initial begin
    #10000;
    $display("[TB_REAL] axi_res_tbl FAILED - TIMEOUT");
    $finish;
  end
endmodule
