`ifndef LOGIC_AVALON_ST_SVH
`define LOGIC_AVALON_ST_SVH

`define LOGIC_AVALON_ST_IF_ASSIGN(lhs, rhs) \
    always_comb lhs``.valid = rhs``.valid; \
    always_comb lhs``.startofpacket = rhs``.startofpacket; \
    always_comb lhs``.endofpacket = rhs``.endofpacket; \
    always_comb lhs``.data = rhs``.data; \
    always_comb lhs``.empty = rhs``.empty; \
    always_comb lhs``.error = rhs``.error; \
    always_comb lhs``.channel = rhs``.channel; \
    always_comb rhs``.ready = lhs``.ready

`define LOGIC_AVALON_ST_IF_RX_ASSIGN(lhs, rhs) \
    always_comb lhs``.valid = rhs``_valid; \
    always_comb lhs``.startofpacket = rhs``_startofpacket; \
    always_comb lhs``.endofpacket = rhs``_endofpacket; \
    always_comb lhs``.data = rhs``_data; \
    always_comb lhs``.empty = rhs``_empty; \
    always_comb lhs``.error = rhs``_error; \
    always_comb lhs``.channel = rhs``_channel; \
    always_comb rhs``_ready = lhs``.ready

`define LOGIC_AVALON_ST_IF_TX_ASSIGN(lhs, rhs) \
    always_comb lhs``_valid = rhs``.valid; \
    always_comb lhs``_startofpacket = rhs``.startofpacket; \
    always_comb lhs``_endofpacket = rhs``.endofpacket; \
    always_comb lhs``_data = rhs``.data; \
    always_comb lhs``_empty = rhs``.empty; \
    always_comb lhs``_error = rhs``.error; \
    always_comb lhs``_channel = rhs``.channel; \
    always_comb rhs``.ready = lhs``_ready

`endif /* LOGIC_AVALON_ST_SVH */
