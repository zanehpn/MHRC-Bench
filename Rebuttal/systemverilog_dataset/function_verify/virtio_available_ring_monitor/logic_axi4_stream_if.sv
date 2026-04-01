`timescale 1ns/1ps

`include "logic.svh"

interface logic_axi4_stream_if #(
    int TDATA_BYTES = 1,
    int TDEST_WIDTH = 1,
    int TUSER_WIDTH = 1,
    int TID_WIDTH = 1,
    int USE_TLAST = 1,
    int USE_TKEEP = 1,
    int USE_TSTRB = 1
) (
    input aclk,
    input areset_n
);
    localparam int TDATA_WIDTH = 8 * TDATA_BYTES;
    localparam int TSTRB_WIDTH = (USE_TSTRB > 0) ? TDATA_BYTES : 0;
    localparam int TKEEP_WIDTH = (USE_TKEEP > 0) ? TDATA_BYTES : 0;
    localparam int TLAST_WIDTH = (USE_TLAST > 0) ? 1 : 0;

    localparam int TOTAL_WIDTH = TUSER_WIDTH + TDEST_WIDTH + TID_WIDTH +
        TLAST_WIDTH + TKEEP_WIDTH + TSTRB_WIDTH + TDATA_WIDTH;

    localparam int M_TDATA_BITS = (TDATA_BYTES > 0) ? 8 : 1;

    localparam int M_TDATA_BYTES = (TDATA_BYTES > 0) ? TDATA_BYTES : 1;
    localparam int M_TDEST_WIDTH = (TDEST_WIDTH > 0) ? TDEST_WIDTH : 1;
    localparam int M_TUSER_WIDTH = (TUSER_WIDTH > 0) ? TUSER_WIDTH : 1;
    localparam int M_TID_WIDTH = (TID_WIDTH > 0) ? TID_WIDTH : 1;

    localparam int M_TDATA_WIDTH = M_TDATA_BYTES * M_TDATA_BITS;
    localparam int M_TSTRB_WIDTH = M_TDATA_BYTES;
    localparam int M_TKEEP_WIDTH = M_TDATA_BYTES;

    localparam int M_TDATA_OFFSET = 0;
    localparam int M_TSTRB_OFFSET = M_TDATA_OFFSET + TDATA_WIDTH;
    localparam int M_TKEEP_OFFSET = M_TSTRB_OFFSET + TSTRB_WIDTH;
    localparam int M_TLAST_OFFSET = M_TKEEP_OFFSET + TKEEP_WIDTH;
    localparam int M_TDEST_OFFSET = M_TLAST_OFFSET + TLAST_WIDTH;
    localparam int M_TUSER_OFFSET = M_TDEST_OFFSET + TDEST_WIDTH;
    localparam int M_TID_OFFSET = M_TUSER_OFFSET + TUSER_WIDTH;

    typedef logic [M_TDATA_BYTES-1:0][M_TDATA_BITS-1:0] tdata_t;
    typedef logic [M_TSTRB_WIDTH-1:0] tstrb_t;
    typedef logic [M_TKEEP_WIDTH-1:0] tkeep_t;
    typedef logic [M_TDEST_WIDTH-1:0] tdest_t;
    typedef logic [M_TUSER_WIDTH-1:0] tuser_t;
    typedef logic [M_TID_WIDTH-1:0] tid_t;
    typedef logic tlast_t;

`ifdef SYNTHESIS
    logic tready;
    logic tvalid;
    tlast_t tlast;
    tdata_t tdata;
    tstrb_t tstrb;
    tkeep_t tkeep;
    tdest_t tdest;
    tuser_t tuser;
    tid_t tid;
`else
    logic tready = 'X;
    logic tvalid = 'X;
    tlast_t tlast = 'X;
    tdata_t tdata = 'X;
    tstrb_t tstrb = 'X;
    tkeep_t tkeep = 'X;
    tdest_t tdest = 'X;
    tuser_t tuser = 'X;
    tid_t tid = 'X;
`endif

    function automatic logic [TOTAL_WIDTH-1:0] read();
        if (TDATA_WIDTH > 0) begin
            read[M_TDATA_OFFSET+:$bits(tdata_t)] = tdata;
        end
        if (TKEEP_WIDTH > 0) begin
            read[M_TKEEP_OFFSET+:$bits(tkeep_t)] = tkeep;
        end
        if (TSTRB_WIDTH > 0) begin
            read[M_TSTRB_OFFSET+:$bits(tstrb_t)] = tstrb;
        end
        if (TDEST_WIDTH > 0) begin
            read[M_TDEST_OFFSET+:$bits(tdest_t)] = tdest;
        end
        if (TUSER_WIDTH > 0) begin
            read[M_TUSER_OFFSET+:$bits(tuser_t)] = tuser;
        end
        if (TLAST_WIDTH > 0) begin
            read[M_TLAST_OFFSET+:$bits(tlast_t)] = tlast;
        end
        if (TID_WIDTH > 0) begin
            read[M_TID_OFFSET+:$bits(tid_t)] = tid;
        end
    endfunction

    task automatic write(input [TOTAL_WIDTH-1:0] packet);
        if (TDATA_WIDTH > 0) begin
            tdata <= packet[M_TDATA_OFFSET+:$bits(tdata_t)];
        end else begin
            tdata <= '0;
        end
        if (TKEEP_WIDTH > 0) begin
            tkeep <= packet[M_TKEEP_OFFSET+:$bits(tkeep_t)];
        end else begin
            tkeep <= '1;
        end
        if (TSTRB_WIDTH > 0) begin
            tstrb <= packet[M_TSTRB_OFFSET+:$bits(tstrb_t)];
        end else begin
            tstrb <= '1;
        end
        if (TDEST_WIDTH > 0) begin
            tdest <= packet[M_TDEST_OFFSET+:$bits(tdest_t)];
        end else begin
            tdest <= '0;
        end
        if (TUSER_WIDTH > 0) begin
            tuser <= packet[M_TUSER_OFFSET+:$bits(tuser_t)];
        end else begin
            tuser <= '0;
        end
        if (TLAST_WIDTH > 0) begin
            tlast <= packet[M_TLAST_OFFSET+:$bits(tlast_t)];
        end else begin
            tlast <= '1;
        end
        if (TID_WIDTH > 0) begin
            tid <= packet[M_TID_OFFSET+:$bits(tid_t)];
        end else begin
            tid <= '0;
        end
    endtask

    task automatic comb_write(input [TOTAL_WIDTH-1:0] packet);
        if (TDATA_WIDTH > 0) begin
            tdata = packet[M_TDATA_OFFSET+:$bits(tdata_t)];
        end else begin
            tdata = '0;
        end
        if (TKEEP_WIDTH > 0) begin
            tkeep = packet[M_TKEEP_OFFSET+:$bits(tkeep_t)];
        end else begin
            tkeep = '1;
        end
        if (TSTRB_WIDTH > 0) begin
            tstrb = packet[M_TSTRB_OFFSET+:$bits(tstrb_t)];
        end else begin
            tstrb = '1;
        end
        if (TDEST_WIDTH > 0) begin
            tdest = packet[M_TDEST_OFFSET+:$bits(tdest_t)];
        end else begin
            tdest = '0;
        end
        if (TUSER_WIDTH > 0) begin
            tuser = packet[M_TUSER_OFFSET+:$bits(tuser_t)];
        end else begin
            tuser = '0;
        end
        if (TLAST_WIDTH > 0) begin
            tlast = packet[M_TLAST_OFFSET+:$bits(tlast_t)];
        end else begin
            tlast = '1;
        end
        if (TID_WIDTH > 0) begin
            tid = packet[M_TID_OFFSET+:$bits(tid_t)];
        end else begin
            tid = '0;
        end
    endtask

`ifndef LOGIC_MODPORT_DISABLED
    modport rx (
        input tvalid,
        input tuser,
        input tdest,
        input tid,
        input tlast,
        input tkeep,
        input tstrb,
        input tdata,
        output tready,
        import read
    );

    modport tx (
        output tvalid,
        output tuser,
        output tdest,
        output tid,
        output tlast,
        output tkeep,
        output tstrb,
        output tdata,
        input tready,
        import write,
        import comb_write
    );

    modport monitor (
        input tvalid,
        input tuser,
        input tdest,
        input tid,
        input tlast,
        input tkeep,
        input tstrb,
        input tdata,
        input tready,
        import read
    );
`endif

`ifndef SYNTHESIS
    clocking cb_rx @(posedge aclk);
        output tvalid;
        output tuser;
        output tdest;
        output tid;
        output tlast;
        output tkeep;
        output tstrb;
        output tdata;
        input tready;
    endclocking

    modport cb_rx_modport (
        input areset_n,
        clocking cb_rx
    );

    clocking cb_tx @(posedge aclk);
        input tvalid;
        input tuser;
        input tdest;
        input tid;
        input tlast;
        input tkeep;
        input tstrb;
        input tdata;
        inout tready;
    endclocking

    modport cb_tx_modport (
        input areset_n,
        clocking cb_tx
    );

    clocking cb_monitor @(posedge aclk);
        input tvalid;
        input tuser;
        input tdest;
        input tid;
        input tlast;
        input tkeep;
        input tstrb;
        input tdata;
        input tready;
    endclocking

    modport cb_monitor_modport (
        input areset_n,
        clocking cb_monitor
    );
`endif

`ifdef VERILATOR
    logic _unused_ports = &{1'b0, aclk, areset_n, 1'b0};
`endif
endinterface
