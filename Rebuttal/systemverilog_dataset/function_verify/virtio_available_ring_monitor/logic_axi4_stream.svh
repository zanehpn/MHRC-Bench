`ifndef LOGIC_AXI4_STREAM_SVH
`define LOGIC_AXI4_STREAM_SVH

`define LOGIC_AXI4_STREAM_IF_ASSIGN(lhs, rhs) \
    always_comb lhs``.tvalid = rhs``.tvalid; \
    always_comb lhs``.tlast = rhs``.tlast; \
    always_comb lhs``.tdata = rhs``.tdata; \
    always_comb lhs``.tstrb = rhs``.tstrb; \
    always_comb lhs``.tkeep = rhs``.tkeep; \
    always_comb lhs``.tdest = rhs``.tdest; \
    always_comb lhs``.tuser = rhs``.tuser; \
    always_comb lhs``.tid = rhs``.tid; \
    always_comb rhs``.tready = lhs``.tready

`define LOGIC_AXI4_STREAM_IF_RX_ASSIGN(lhs, rhs) \
    always_comb lhs``.tvalid = rhs``_tvalid; \
    always_comb lhs``.tlast = rhs``_tlast; \
    always_comb lhs``.tdata = rhs``_tdata; \
    always_comb lhs``.tstrb = rhs``_tstrb; \
    always_comb lhs``.tkeep = rhs``_tkeep; \
    always_comb lhs``.tdest = rhs``_tdest; \
    always_comb lhs``.tuser = rhs``_tuser; \
    always_comb lhs``.tid = rhs``_tid; \
    always_comb rhs``_tready = lhs``.tready

`define LOGIC_AXI4_STREAM_IF_TX_ASSIGN(lhs, rhs) \
    always_comb lhs``_tvalid = rhs``.tvalid; \
    always_comb lhs``_tlast = rhs``.tlast; \
    always_comb lhs``_tdata = rhs``.tdata; \
    always_comb lhs``_tstrb = rhs``.tstrb; \
    always_comb lhs``_tkeep = rhs``.tkeep; \
    always_comb lhs``_tdest = rhs``.tdest; \
    always_comb lhs``_tuser = rhs``.tuser; \
    always_comb lhs``_tid = rhs``.tid; \
    always_comb rhs``.tready = lhs``_tready

`endif /* LOGIC_AXI4_STREAM_SVH */
