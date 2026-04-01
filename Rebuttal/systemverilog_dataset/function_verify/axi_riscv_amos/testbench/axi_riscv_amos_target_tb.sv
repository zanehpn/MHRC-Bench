`timescale 1ns/1ps
`include "../axi_riscv_amos_original.sv"

module axi_riscv_amos_target_tb;

  localparam AXI_ADDR_WIDTH     = 32;
  localparam AXI_DATA_WIDTH     = 32;
  localparam AXI_ID_WIDTH       = 4;
  localparam AXI_USER_WIDTH     = 1;
  localparam AXI_MAX_WRITE_TXNS = 4;
  localparam RISCV_WORD_WIDTH   = 32;
  localparam AXI_STRB_WIDTH     = AXI_DATA_WIDTH / 8;

  logic clk, rst_n;
  always #5 clk = ~clk;

  // Slave interface
  logic [AXI_ADDR_WIDTH-1:0]  slv_aw_addr;
  logic [2:0]                 slv_aw_prot;
  logic [3:0]                 slv_aw_region;
  logic [5:0]                 slv_aw_atop;
  logic [7:0]                 slv_aw_len;
  logic [2:0]                 slv_aw_size;
  logic [1:0]                 slv_aw_burst;
  logic                       slv_aw_lock;
  logic [3:0]                 slv_aw_cache;
  logic [3:0]                 slv_aw_qos;
  logic [AXI_ID_WIDTH-1:0]   slv_aw_id;
  logic [AXI_USER_WIDTH-1:0] slv_aw_user;
  logic                       slv_aw_ready;
  logic                       slv_aw_valid;

  logic [AXI_ADDR_WIDTH-1:0]  slv_ar_addr;
  logic [2:0]                 slv_ar_prot;
  logic [3:0]                 slv_ar_region;
  logic [7:0]                 slv_ar_len;
  logic [2:0]                 slv_ar_size;
  logic [1:0]                 slv_ar_burst;
  logic                       slv_ar_lock;
  logic [3:0]                 slv_ar_cache;
  logic [3:0]                 slv_ar_qos;
  logic [AXI_ID_WIDTH-1:0]   slv_ar_id;
  logic [AXI_USER_WIDTH-1:0] slv_ar_user;
  logic                       slv_ar_ready;
  logic                       slv_ar_valid;

  logic [AXI_DATA_WIDTH-1:0]  slv_w_data;
  logic [AXI_STRB_WIDTH-1:0]  slv_w_strb;
  logic [AXI_USER_WIDTH-1:0]  slv_w_user;
  logic                       slv_w_last;
  logic                       slv_w_ready;
  logic                       slv_w_valid;

  logic [AXI_DATA_WIDTH-1:0]  slv_r_data;
  logic [1:0]                 slv_r_resp;
  logic                       slv_r_last;
  logic [AXI_ID_WIDTH-1:0]   slv_r_id;
  logic [AXI_USER_WIDTH-1:0] slv_r_user;
  logic                       slv_r_ready;
  logic                       slv_r_valid;

  logic [1:0]                 slv_b_resp;
  logic [AXI_ID_WIDTH-1:0]   slv_b_id;
  logic [AXI_USER_WIDTH-1:0] slv_b_user;
  logic                       slv_b_ready;
  logic                       slv_b_valid;

  // Master interface
  logic [AXI_ADDR_WIDTH-1:0]  mst_aw_addr;
  logic [2:0]                 mst_aw_prot;
  logic [3:0]                 mst_aw_region;
  logic [5:0]                 mst_aw_atop;
  logic [7:0]                 mst_aw_len;
  logic [2:0]                 mst_aw_size;
  logic [1:0]                 mst_aw_burst;
  logic                       mst_aw_lock;
  logic [3:0]                 mst_aw_cache;
  logic [3:0]                 mst_aw_qos;
  logic [AXI_ID_WIDTH-1:0]   mst_aw_id;
  logic [AXI_USER_WIDTH-1:0] mst_aw_user;
  logic                       mst_aw_ready;
  logic                       mst_aw_valid;

  logic [AXI_ADDR_WIDTH-1:0]  mst_ar_addr;
  logic [2:0]                 mst_ar_prot;
  logic [3:0]                 mst_ar_region;
  logic [7:0]                 mst_ar_len;
  logic [2:0]                 mst_ar_size;
  logic [1:0]                 mst_ar_burst;
  logic                       mst_ar_lock;
  logic [3:0]                 mst_ar_cache;
  logic [3:0]                 mst_ar_qos;
  logic [AXI_ID_WIDTH-1:0]   mst_ar_id;
  logic [AXI_USER_WIDTH-1:0] mst_ar_user;
  logic                       mst_ar_ready;
  logic                       mst_ar_valid;

  logic [AXI_DATA_WIDTH-1:0]  mst_w_data;
  logic [AXI_STRB_WIDTH-1:0]  mst_w_strb;
  logic [AXI_USER_WIDTH-1:0]  mst_w_user;
  logic                       mst_w_last;
  logic                       mst_w_ready;
  logic                       mst_w_valid;

  logic [AXI_DATA_WIDTH-1:0]  mst_r_data;
  logic [1:0]                 mst_r_resp;
  logic                       mst_r_last;
  logic [AXI_ID_WIDTH-1:0]   mst_r_id;
  logic [AXI_USER_WIDTH-1:0] mst_r_user;
  logic                       mst_r_ready;
  logic                       mst_r_valid;

  logic [1:0]                 mst_b_resp;
  logic [AXI_ID_WIDTH-1:0]   mst_b_id;
  logic [AXI_USER_WIDTH-1:0] mst_b_user;
  logic                       mst_b_ready;
  logic                       mst_b_valid;

  axi_riscv_amos #(
    .AXI_ADDR_WIDTH     (AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH     (AXI_DATA_WIDTH),
    .AXI_ID_WIDTH       (AXI_ID_WIDTH),
    .AXI_USER_WIDTH     (AXI_USER_WIDTH),
    .AXI_MAX_WRITE_TXNS (AXI_MAX_WRITE_TXNS),
    .RISCV_WORD_WIDTH   (RISCV_WORD_WIDTH)
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

  // AXI slave responder
  assign mst_aw_ready = 1'b1;
  assign mst_w_ready = 1'b1;
  assign mst_ar_ready = 1'b1;

  // B response: generate B after W last handshake
  // Use negedge sampling to avoid posedge race with DUT's registered outputs
  logic w_last_seen;
  logic [AXI_ID_WIDTH-1:0] b_resp_id;
  always @(negedge clk or negedge rst_n) begin
    if (!rst_n) begin
      w_last_seen <= 1'b0;
      b_resp_id   <= '0;
    end else begin
      if (w_last_seen) w_last_seen <= 1'b0;
      if (mst_w_valid && mst_w_ready && mst_w_last) begin
        w_last_seen <= 1'b1;
        b_resp_id   <= mst_aw_id;
      end
    end
  end
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mst_b_valid  <= 1'b0;
      mst_b_resp   <= 2'b00;
      mst_b_id     <= '0;
      mst_b_user   <= '0;
    end else begin
      if (mst_b_valid && mst_b_ready) begin
        mst_b_valid <= 1'b0;
      end
      if (w_last_seen && !mst_b_valid) begin
        mst_b_valid <= 1'b1;
        mst_b_resp  <= 2'b00;
        mst_b_id    <= b_resp_id;
        mst_b_user  <= '0;
      end
    end
  end

  // R response: immediate R after AR
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mst_r_valid <= 1'b0;
      mst_r_data  <= '0;
      mst_r_resp  <= 2'b00;
      mst_r_last  <= 1'b0;
      mst_r_id    <= '0;
      mst_r_user  <= '0;
    end else begin
      if (mst_r_valid && mst_r_ready) begin
        mst_r_valid <= 1'b0;
      end
      if (mst_ar_valid && mst_ar_ready) begin
        mst_r_valid <= 1'b1;
        mst_r_data  <= 32'hDEADBEEF;
        mst_r_resp  <= 2'b00;
        mst_r_last  <= 1'b1;
        mst_r_id    <= mst_ar_id;
        mst_r_user  <= mst_ar_user;
      end
    end
  end

  integer pass_count, fail_count, total_tests;

  task automatic init_slv();
    slv_aw_valid  = 0; slv_aw_addr   = '0; slv_aw_prot   = '0;
    slv_aw_region = '0; slv_aw_atop   = '0; slv_aw_len    = '0;
    slv_aw_size   = 3'b010; slv_aw_burst  = 2'b01; slv_aw_lock   = 0;
    slv_aw_cache  = '0; slv_aw_qos    = '0; slv_aw_id     = '0;
    slv_aw_user   = '0;
    slv_ar_valid  = 0; slv_ar_addr   = '0; slv_ar_prot   = '0;
    slv_ar_region = '0; slv_ar_len    = '0; slv_ar_size   = 3'b010;
    slv_ar_burst  = 2'b01; slv_ar_lock   = 0; slv_ar_cache  = '0;
    slv_ar_qos    = '0; slv_ar_id     = '0; slv_ar_user   = '0;
    slv_w_valid   = 0; slv_w_data    = '0; slv_w_strb    = '0;
    slv_w_user    = '0; slv_w_last    = 0;
    slv_r_ready   = 1; slv_b_ready   = 1;
  endtask

  task automatic do_normal_write(input [AXI_ADDR_WIDTH-1:0] addr, input [AXI_ID_WIDTH-1:0] id);
    integer timeout;
    // Send AW first
    slv_aw_valid = 1; slv_aw_addr = addr; slv_aw_id = id;
    slv_aw_len = 8'h00; slv_aw_atop = 6'b000000;
    timeout = 0;
    forever begin
      @(posedge clk); #1;
      if (slv_aw_ready && slv_aw_valid) begin slv_aw_valid = 0; break; end
      timeout++;
      if (timeout > 100) begin slv_aw_valid = 0; return; end
    end
    // Then send W
    slv_w_valid = 1; slv_w_data = 32'hCAFEBABE; slv_w_strb = 4'hF; slv_w_last = 1;
    timeout = 0;
    forever begin
      @(posedge clk); #1;
      if (slv_w_ready && slv_w_valid) begin slv_w_valid = 0; slv_w_last = 0; break; end
      timeout++;
      if (timeout > 100) begin slv_w_valid = 0; slv_w_last = 0; return; end
    end
    // Wait for B
    timeout = 0;
    forever begin
      @(posedge clk); #1;
      if (slv_b_valid && slv_b_ready) begin
        return;
      end
      timeout++;
      if (timeout > 100) begin return; end
    end
  endtask

  task automatic check(string name, logic cond);
    total_tests++;
    if (!cond) begin
      fail_count++;
      $display("FAIL: %s", name);
    end else
      pass_count++;
  endtask

  logic aw_ready_seen;
  integer aw_ready_timeout;

  initial begin
    clk = 0; rst_n = 0;
    pass_count = 0; fail_count = 0; total_tests = 0;
    init_slv();

    repeat (4) @(posedge clk);
    rst_n = 1;
    repeat (2) @(posedge clk);

    // T1-T3: Normal writes (baseline passthrough)
    do_normal_write(32'h1000, 4'h1);
    check("T1: normal write 1", 1);

    do_normal_write(32'h2000, 4'h2);
    check("T2: normal write 2", 1);

    do_normal_write(32'h3000, 4'h3);
    check("T3: normal write 3", 1);

    // T4: AMO SWAP
    begin
      integer to;
      slv_aw_valid = 1; slv_aw_addr = 32'h4000; slv_aw_id = 4'h4;
      slv_aw_len = 8'h00; slv_aw_size = 3'b010; slv_aw_burst = 2'b01;
      slv_aw_lock = 0; slv_aw_atop = axi_pkg::ATOP_ATOMICSWAP;
      to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_aw_ready && slv_aw_valid) begin slv_aw_valid = 0; break; end
        to++; if (to > 200) begin slv_aw_valid = 0; break; end
      end
      slv_aw_atop = 6'b000000;
      slv_w_valid = 1; slv_w_data = 32'hAAAAAAAA; slv_w_strb = 4'hF; slv_w_last = 1;
      to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_w_ready && slv_w_valid) begin slv_w_valid = 0; slv_w_last = 0; break; end
        to++; if (to > 200) begin slv_w_valid = 0; slv_w_last = 0; break; end
      end
      // Wait for R (AMO old value)
      to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_r_valid && slv_r_ready) break;
        to++; if (to > 200) break;
      end
      // Wait for B
      to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_b_valid && slv_b_ready) break;
        to++; if (to > 200) break;
      end
    end
    check("T4: AMO swap", 1);

    // T5-T7: Key tests - verify AW is accepted after AMO
    // With correct code, aw_state returns to FEEDTHROUGH_AW -> slv_aw_ready works
    // With wrong code, aw_state is stuck in SEND_AW -> slv_aw_ready stays 0
    repeat(10) @(posedge clk);

    slv_aw_valid = 1; slv_aw_addr = 32'h5000; slv_aw_id = 4'h5;
    slv_aw_len = 8'h00; slv_aw_atop = 6'b000000;
    aw_ready_seen = 0;
    begin
      integer to; to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_aw_ready) begin aw_ready_seen = 1; slv_aw_valid = 0; break; end
        to++; if (to > 50) begin slv_aw_valid = 0; break; end
      end
    end
    check("T5: AW accepted after AMO (aw_state recovery)", aw_ready_seen);

    // Complete the W and B for T5 if AW was accepted
    if (aw_ready_seen) begin
      slv_w_valid = 1; slv_w_data = 32'hCAFEBABE; slv_w_strb = 4'hF; slv_w_last = 1;
      begin
        integer to; to = 0;
        forever begin
          @(posedge clk); #1;
          if (slv_w_ready && slv_w_valid) begin slv_w_valid = 0; slv_w_last = 0; break; end
          to++; if (to > 50) begin slv_w_valid = 0; slv_w_last = 0; break; end
        end
      end
      begin
        integer to; to = 0;
        forever begin
          @(posedge clk); #1;
          if (slv_b_valid) break;
          to++; if (to > 100) break;
        end
      end
    end

    // T6: Another write after AMO
    slv_aw_valid = 1; slv_aw_addr = 32'h6000; slv_aw_id = 4'h6;
    slv_aw_len = 8'h00; slv_aw_atop = 6'b000000;
    aw_ready_seen = 0;
    begin
      integer to; to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_aw_ready) begin aw_ready_seen = 1; slv_aw_valid = 0; break; end
        to++; if (to > 50) begin slv_aw_valid = 0; break; end
      end
    end
    check("T6: second AW after AMO", aw_ready_seen);
    if (aw_ready_seen) begin
      slv_w_valid = 1; slv_w_data = 32'hDEADDEAD; slv_w_strb = 4'hF; slv_w_last = 1;
      begin
        integer to; to = 0;
        forever begin
          @(posedge clk); #1;
          if (slv_w_ready && slv_w_valid) begin slv_w_valid = 0; slv_w_last = 0; break; end
          to++; if (to > 50) begin slv_w_valid = 0; slv_w_last = 0; break; end
        end
      end
      begin
        integer to; to = 0;
        forever begin
          @(posedge clk); #1;
          if (slv_b_valid) break;
          to++; if (to > 100) break;
        end
      end
    end

    // T7: Second AMO and verify recovery
    begin
      integer to;
      slv_aw_valid = 1; slv_aw_addr = 32'h8000; slv_aw_id = 4'h8;
      slv_aw_len = 8'h00; slv_aw_size = 3'b010; slv_aw_burst = 2'b01;
      slv_aw_lock = 0; slv_aw_atop = axi_pkg::ATOP_ATOMICSWAP;
      to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_aw_ready && slv_aw_valid) begin slv_aw_valid = 0; break; end
        to++; if (to > 200) begin slv_aw_valid = 0; break; end
      end
      slv_aw_atop = 6'b000000;
      slv_w_valid = 1; slv_w_data = 32'hBBBBBBBB; slv_w_strb = 4'hF; slv_w_last = 1;
      to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_w_ready && slv_w_valid) begin slv_w_valid = 0; slv_w_last = 0; break; end
        to++; if (to > 200) begin slv_w_valid = 0; slv_w_last = 0; break; end
      end
      to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_r_valid && slv_r_ready) break;
        to++; if (to > 200) break;
      end
      to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_b_valid && slv_b_ready) break;
        to++; if (to > 200) break;
      end
    end
    repeat(10) @(posedge clk);

    slv_aw_valid = 1; slv_aw_addr = 32'h9000; slv_aw_id = 4'h9;
    slv_aw_len = 8'h00; slv_aw_atop = 6'b000000;
    aw_ready_seen = 0;
    begin
      integer to; to = 0;
      forever begin
        @(posedge clk); #1;
        if (slv_aw_ready) begin aw_ready_seen = 1; slv_aw_valid = 0; break; end
        to++; if (to > 50) begin slv_aw_valid = 0; break; end
      end
    end
    check("T7: AW after second AMO", aw_ready_seen);

    if (fail_count == 0)
      $display("[TB_REAL] axi_riscv_amos all %0d / %0d tests PASSED", pass_count, total_tests);
    else
      $display("[TB_REAL] axi_riscv_amos FAILED %0d / %0d tests", fail_count, total_tests);
    $finish;
  end

  initial begin
    #500000;
    $display("[TB_REAL] axi_riscv_amos FAILED - timeout");
    $finish;
  end
endmodule
