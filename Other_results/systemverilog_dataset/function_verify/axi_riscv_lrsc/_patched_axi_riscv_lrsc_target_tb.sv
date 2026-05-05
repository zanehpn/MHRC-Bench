`timescale 1ns/1ps
`include "../_patched_axi_riscv_lrsc_original.sv"

module axi_riscv_lrsc_target_tb;

  localparam longint unsigned ADDR_BEGIN        = 0;
  localparam longint unsigned ADDR_END          = 32'hFFFF;
  localparam AXI_ADDR_WIDTH     = 32;
  localparam AXI_DATA_WIDTH     = 32;
  localparam AXI_ID_WIDTH       = 4;
  localparam AXI_USER_WIDTH     = 1;
  localparam AXI_MAX_READ_TXNS  = 4;
  localparam AXI_MAX_WRITE_TXNS = 4;
  localparam AXI_STRB_WIDTH     = AXI_DATA_WIDTH / 8;

  logic clk, rst_n;
  always #5 clk = ~clk;

  logic [AXI_ADDR_WIDTH-1:0]  slv_aw_addr, slv_ar_addr;
  logic [2:0]                 slv_aw_prot, slv_ar_prot;
  logic [3:0]                 slv_aw_region, slv_ar_region;
  logic [5:0]                 slv_aw_atop;
  logic [7:0]                 slv_aw_len, slv_ar_len;
  logic [2:0]                 slv_aw_size, slv_ar_size;
  logic [1:0]                 slv_aw_burst, slv_ar_burst;
  logic                       slv_aw_lock, slv_ar_lock;
  logic [3:0]                 slv_aw_cache, slv_ar_cache;
  logic [3:0]                 slv_aw_qos, slv_ar_qos;
  logic [AXI_ID_WIDTH-1:0]   slv_aw_id, slv_ar_id;
  logic [AXI_USER_WIDTH-1:0] slv_aw_user, slv_ar_user;
  logic                       slv_aw_ready, slv_ar_ready;
  logic                       slv_aw_valid, slv_ar_valid;
  logic [AXI_DATA_WIDTH-1:0]  slv_w_data;
  logic [AXI_STRB_WIDTH-1:0]  slv_w_strb;
  logic [AXI_USER_WIDTH-1:0]  slv_w_user;
  logic                       slv_w_last, slv_w_ready, slv_w_valid;
  logic [AXI_DATA_WIDTH-1:0]  slv_r_data;
  logic [1:0]                 slv_r_resp;
  logic                       slv_r_last;
  logic [AXI_ID_WIDTH-1:0]   slv_r_id;
  logic [AXI_USER_WIDTH-1:0] slv_r_user;
  logic                       slv_r_ready, slv_r_valid;
  logic [1:0]                 slv_b_resp;
  logic [AXI_ID_WIDTH-1:0]   slv_b_id;
  logic [AXI_USER_WIDTH-1:0] slv_b_user;
  logic                       slv_b_ready, slv_b_valid;

  logic [AXI_ADDR_WIDTH-1:0]  mst_aw_addr, mst_ar_addr;
  logic [2:0]                 mst_aw_prot, mst_ar_prot;
  logic [3:0]                 mst_aw_region, mst_ar_region;
  logic [5:0]                 mst_aw_atop;
  logic [7:0]                 mst_aw_len, mst_ar_len;
  logic [2:0]                 mst_aw_size, mst_ar_size;
  logic [1:0]                 mst_aw_burst, mst_ar_burst;
  logic                       mst_aw_lock, mst_ar_lock;
  logic [3:0]                 mst_aw_cache, mst_ar_cache;
  logic [3:0]                 mst_aw_qos, mst_ar_qos;
  logic [AXI_ID_WIDTH-1:0]   mst_aw_id, mst_ar_id;
  logic [AXI_USER_WIDTH-1:0] mst_aw_user, mst_ar_user;
  logic                       mst_aw_ready, mst_ar_ready;
  logic                       mst_aw_valid, mst_ar_valid;
  logic [AXI_DATA_WIDTH-1:0]  mst_w_data;
  logic [AXI_STRB_WIDTH-1:0]  mst_w_strb;
  logic [AXI_USER_WIDTH-1:0]  mst_w_user;
  logic                       mst_w_last, mst_w_ready, mst_w_valid;
  logic [AXI_DATA_WIDTH-1:0]  mst_r_data;
  logic [1:0]                 mst_r_resp;
  logic                       mst_r_last;
  logic [AXI_ID_WIDTH-1:0]   mst_r_id;
  logic [AXI_USER_WIDTH-1:0] mst_r_user;
  logic                       mst_r_ready, mst_r_valid;
  logic [1:0]                 mst_b_resp;
  logic [AXI_ID_WIDTH-1:0]   mst_b_id;
  logic [AXI_USER_WIDTH-1:0] mst_b_user;
  logic                       mst_b_ready, mst_b_valid;

  axi_riscv_lrsc #(
    .ADDR_BEGIN(ADDR_BEGIN), .ADDR_END(ADDR_END),
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH), .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH), .AXI_USER_WIDTH(AXI_USER_WIDTH),
    .AXI_MAX_READ_TXNS(AXI_MAX_READ_TXNS), .AXI_MAX_WRITE_TXNS(AXI_MAX_WRITE_TXNS)
  ) dut (
    .clk_i(clk), .rst_ni(rst_n),
    .slv_aw_addr_i(slv_aw_addr), .slv_aw_prot_i(slv_aw_prot),
    .slv_aw_region_i(slv_aw_region), .slv_aw_atop_i(slv_aw_atop),
    .slv_aw_len_i(slv_aw_len), .slv_aw_size_i(slv_aw_size),
    .slv_aw_burst_i(slv_aw_burst), .slv_aw_lock_i(slv_aw_lock),
    .slv_aw_cache_i(slv_aw_cache), .slv_aw_qos_i(slv_aw_qos),
    .slv_aw_id_i(slv_aw_id), .slv_aw_user_i(slv_aw_user),
    .slv_aw_ready_o(slv_aw_ready), .slv_aw_valid_i(slv_aw_valid),
    .slv_ar_addr_i(slv_ar_addr), .slv_ar_prot_i(slv_ar_prot),
    .slv_ar_region_i(slv_ar_region), .slv_ar_len_i(slv_ar_len),
    .slv_ar_size_i(slv_ar_size), .slv_ar_burst_i(slv_ar_burst),
    .slv_ar_lock_i(slv_ar_lock), .slv_ar_cache_i(slv_ar_cache),
    .slv_ar_qos_i(slv_ar_qos), .slv_ar_id_i(slv_ar_id),
    .slv_ar_user_i(slv_ar_user), .slv_ar_ready_o(slv_ar_ready),
    .slv_ar_valid_i(slv_ar_valid),
    .slv_w_data_i(slv_w_data), .slv_w_strb_i(slv_w_strb),
    .slv_w_user_i(slv_w_user), .slv_w_last_i(slv_w_last),
    .slv_w_ready_o(slv_w_ready), .slv_w_valid_i(slv_w_valid),
    .slv_r_data_o(slv_r_data), .slv_r_resp_o(slv_r_resp),
    .slv_r_last_o(slv_r_last), .slv_r_id_o(slv_r_id),
    .slv_r_user_o(slv_r_user), .slv_r_ready_i(slv_r_ready),
    .slv_r_valid_o(slv_r_valid),
    .slv_b_resp_o(slv_b_resp), .slv_b_id_o(slv_b_id),
    .slv_b_user_o(slv_b_user), .slv_b_ready_i(slv_b_ready),
    .slv_b_valid_o(slv_b_valid),
    .mst_aw_addr_o(mst_aw_addr), .mst_aw_prot_o(mst_aw_prot),
    .mst_aw_region_o(mst_aw_region), .mst_aw_atop_o(mst_aw_atop),
    .mst_aw_len_o(mst_aw_len), .mst_aw_size_o(mst_aw_size),
    .mst_aw_burst_o(mst_aw_burst), .mst_aw_lock_o(mst_aw_lock),
    .mst_aw_cache_o(mst_aw_cache), .mst_aw_qos_o(mst_aw_qos),
    .mst_aw_id_o(mst_aw_id), .mst_aw_user_o(mst_aw_user),
    .mst_aw_ready_i(mst_aw_ready), .mst_aw_valid_o(mst_aw_valid),
    .mst_ar_addr_o(mst_ar_addr), .mst_ar_prot_o(mst_ar_prot),
    .mst_ar_region_o(mst_ar_region), .mst_ar_len_o(mst_ar_len),
    .mst_ar_size_o(mst_ar_size), .mst_ar_burst_o(mst_ar_burst),
    .mst_ar_lock_o(mst_ar_lock), .mst_ar_cache_o(mst_ar_cache),
    .mst_ar_qos_o(mst_ar_qos), .mst_ar_id_o(mst_ar_id),
    .mst_ar_user_o(mst_ar_user), .mst_ar_ready_i(mst_ar_ready),
    .mst_ar_valid_o(mst_ar_valid),
    .mst_w_data_o(mst_w_data), .mst_w_strb_o(mst_w_strb),
    .mst_w_user_o(mst_w_user), .mst_w_last_o(mst_w_last),
    .mst_w_ready_i(mst_w_ready), .mst_w_valid_o(mst_w_valid),
    .mst_r_data_i(mst_r_data), .mst_r_resp_i(mst_r_resp),
    .mst_r_last_i(mst_r_last), .mst_r_id_i(mst_r_id),
    .mst_r_user_i(mst_r_user), .mst_r_ready_o(mst_r_ready),
    .mst_r_valid_i(mst_r_valid),
    .mst_b_resp_i(mst_b_resp), .mst_b_id_i(mst_b_id),
    .mst_b_user_i(mst_b_user), .mst_b_ready_o(mst_b_ready),
    .mst_b_valid_i(mst_b_valid)
  );

  assign mst_aw_ready = 1'b1;
  assign mst_w_ready = 1'b1;
  assign mst_ar_ready = 1'b1;

  // B and R responders
  logic w_hs_seen;
  logic [AXI_ID_WIDTH-1:0] b_id_q;
  always @(negedge clk or negedge rst_n) begin
    if (!rst_n) begin w_hs_seen <= 0; b_id_q <= '0; end
    else begin
      if (w_hs_seen) w_hs_seen <= 0;
      if (mst_w_valid && mst_w_ready && mst_w_last) begin
        w_hs_seen <= 1; b_id_q <= mst_aw_id;
      end
    end
  end
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin mst_b_valid <= 0; mst_b_resp <= 0; mst_b_id <= '0; mst_b_user <= '0; end
    else begin
      if (mst_b_valid && mst_b_ready) mst_b_valid <= 0;
      if (w_hs_seen && !mst_b_valid) begin
        mst_b_valid <= 1; mst_b_resp <= 2'b00; mst_b_id <= b_id_q; mst_b_user <= '0;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mst_r_valid <= 0; mst_r_data <= '0; mst_r_resp <= 0;
      mst_r_last <= 0; mst_r_id <= '0; mst_r_user <= '0;
    end else begin
      if (mst_ar_valid && mst_ar_ready) begin
        mst_r_valid <= 1; mst_r_data <= 32'hDEADBEEF; mst_r_resp <= 2'b00;
        mst_r_last <= 1; mst_r_id <= mst_ar_id; mst_r_user <= mst_ar_user;
      end else if (mst_r_valid && mst_r_ready) mst_r_valid <= 0;
    end
  end

  integer pass_count, fail_count, total_tests;

  task automatic init_slv();
    slv_aw_valid = 0; slv_aw_addr = '0; slv_aw_prot = '0;
    slv_aw_region = '0; slv_aw_atop = '0; slv_aw_len = '0;
    slv_aw_size = 3'b010; slv_aw_burst = 2'b01; slv_aw_lock = 0;
    slv_aw_cache = '0; slv_aw_qos = '0; slv_aw_id = '0; slv_aw_user = '0;
    slv_ar_valid = 0; slv_ar_addr = '0; slv_ar_prot = '0;
    slv_ar_region = '0; slv_ar_len = '0; slv_ar_size = 3'b010;
    slv_ar_burst = 2'b01; slv_ar_lock = 0; slv_ar_cache = '0;
    slv_ar_qos = '0; slv_ar_id = '0; slv_ar_user = '0;
    slv_w_valid = 0; slv_w_data = '0; slv_w_strb = '0;
    slv_w_user = '0; slv_w_last = 0;
    slv_r_ready = 1; slv_b_ready = 1;
  endtask

  task automatic check(string name, logic cond);
    total_tests++;
    if (!cond) begin fail_count++; $display("FAIL: %s", name); end
    else pass_count++;
  endtask

  // Test that a burst write with held exclusive AR at matching address
  // blocks the AW channel (DUT stays in AW_BURST).
  // With correct code: blocked while AR held, unblocked when released.
  // With wrong code: blocked forever (deadlock in AW_BURST).

  integer aw_accepted;

  initial begin
    clk = 0; rst_n = 0;
    pass_count = 0; fail_count = 0; total_tests = 0;
    init_slv();
    repeat (4) @(posedge clk);
    rst_n = 1;
    repeat (2) @(posedge clk);

    // T1: Do a burst write at addr 0x0300 len=15 (16 beats)
    // This enters AW_BURST to clear reservation addresses
    // Simultaneously hold exclusive AR at addr 0x0308
    // This should stall AW_BURST at clr_addr matching 0x0308

    // First, hold the exclusive AR
    slv_ar_valid = 1; slv_ar_addr = 32'h0000_0308; slv_ar_id = 4'hF;
    slv_ar_len = 0; slv_ar_size = 3'b010; slv_ar_burst = 2'b01; slv_ar_lock = 1;

    // Send burst AW
    slv_aw_valid = 1; slv_aw_addr = 32'h0000_0300; slv_aw_id = 4'hA;
    slv_aw_len = 8'h0F; slv_aw_atop = 0; slv_aw_lock = 0;
    begin
      integer to; to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_aw_ready && slv_aw_valid) begin slv_aw_valid = 0; break; end
        to++; if (to > 200) begin slv_aw_valid = 0; break; end
      end
    end
    check("T1: burst AW accepted", slv_aw_valid == 0);

    // Send W beats
    begin
      integer beats, to;
      for (beats = 0; beats <= 15; beats++) begin
        slv_w_valid = 1; slv_w_data = 32'hCAFE; slv_w_strb = 4'hF;
        slv_w_last = (beats == 15) ? 1 : 0;
        to = 0;
        forever begin
          @(posedge clk); #1;
          if (slv_w_ready && slv_w_valid) begin slv_w_valid = 0; slv_w_last = 0; break; end
          to++; if (to > 200) begin slv_w_valid = 0; slv_w_last = 0; break; end
        end
      end
    end

    // Wait some cycles with AR still held
    repeat(10) @(posedge clk);

    // Release the exclusive AR
    slv_ar_valid = 0;

    // Wait for any R responses
    repeat(10) @(posedge clk);

    // Wait for B
    begin
      integer to; to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_b_valid) begin @(posedge clk); break; end
        to++; if (to > 200) break;
      end
    end

    // T2: After burst + conflict, try a new AW
    // With correct code: AW_BURST recovered, new AW works
    // With wrong code: AW_BURST deadlocked, new AW blocked
    aw_accepted = 0;
    slv_aw_valid = 1; slv_aw_addr = 32'h0000_F000; slv_aw_id = 4'hB;
    slv_aw_len = 0; slv_aw_atop = 0; slv_aw_lock = 0;
    begin
      integer to; to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_aw_ready && slv_aw_valid) begin aw_accepted = 1; slv_aw_valid = 0; break; end
        to++; if (to > 100) begin slv_aw_valid = 0; break; end
      end
    end
    check("T2: AW accepted after burst with conflict (no deadlock)", aw_accepted == 1);

    // Complete the write if accepted
    if (aw_accepted) begin
      integer to;
      slv_w_valid = 1; slv_w_data = 32'h1234; slv_w_strb = 4'hF; slv_w_last = 1;
      to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_w_ready && slv_w_valid) begin slv_w_valid = 0; slv_w_last = 0; break; end
        to++; if (to > 100) begin slv_w_valid = 0; slv_w_last = 0; break; end
      end
      to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_b_valid) begin @(posedge clk); break; end
        to++; if (to > 200) break;
      end
    end

    // T3: Another burst write without conflict (should work fine)
    aw_accepted = 0;
    slv_aw_valid = 1; slv_aw_addr = 32'h0000_0400; slv_aw_id = 4'hC;
    slv_aw_len = 8'h03; slv_aw_atop = 0; slv_aw_lock = 0;
    begin
      integer to; to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_aw_ready && slv_aw_valid) begin aw_accepted = 1; slv_aw_valid = 0; break; end
        to++; if (to > 100) begin slv_aw_valid = 0; break; end
      end
    end
    check("T3: burst AW without conflict", aw_accepted == 1);
    if (aw_accepted) begin
      integer beats, to;
      for (beats = 0; beats <= 3; beats++) begin
        slv_w_valid = 1; slv_w_data = 32'hBEEF; slv_w_strb = 4'hF;
        slv_w_last = (beats == 3) ? 1 : 0;
        to = 0;
        forever begin
          @(posedge clk); #1;
          if (slv_w_ready && slv_w_valid) begin slv_w_valid = 0; slv_w_last = 0; break; end
          to++; if (to > 100) begin slv_w_valid = 0; slv_w_last = 0; break; end
        end
      end
      to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_b_valid) begin @(posedge clk); break; end
        to++; if (to > 200) break;
      end
    end

    // T4: Another write after burst
    aw_accepted = 0;
    slv_aw_valid = 1; slv_aw_addr = 32'h0000_E000; slv_aw_id = 4'hD;
    slv_aw_len = 0; slv_aw_atop = 0; slv_aw_lock = 0;
    begin
      integer to; to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_aw_ready && slv_aw_valid) begin aw_accepted = 1; slv_aw_valid = 0; break; end
        to++; if (to > 100) begin slv_aw_valid = 0; break; end
      end
    end
    check("T4: write after burst", aw_accepted == 1);
    if (aw_accepted) begin
      integer to;
      slv_w_valid = 1; slv_w_data = 32'hDEAD; slv_w_strb = 4'hF; slv_w_last = 1;
      to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_w_ready && slv_w_valid) begin slv_w_valid = 0; slv_w_last = 0; break; end
        to++; if (to > 100) begin slv_w_valid = 0; slv_w_last = 0; break; end
      end
      to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_b_valid) begin @(posedge clk); break; end
        to++; if (to > 200) break;
      end
    end

    if (fail_count == 0)
      $display("[TB_REAL] axi_riscv_lrsc all %0d / %0d tests PASSED", pass_count, total_tests);
    else
      $display("[TB_REAL] axi_riscv_lrsc FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end

  initial begin
    #500000;
    $display("[TB_REAL] axi_riscv_lrsc FAILED - timeout");
    $finish;
  end

endmodule
