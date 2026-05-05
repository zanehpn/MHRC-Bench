`ifndef LOGIC_AVALON_MM_SVH
`define LOGIC_AVALON_MM_SVH

`define LOGIC_AVALON_MM_IF_ASSIGN(lhs, rhs) \
    always_comb lhs``.read = rhs``.read; \
    always_comb lhs``.write = rhs``.write; \
    always_comb lhs``.address = rhs``.address; \
    always_comb lhs``.writedata = rhs``.writedata; \
    always_comb lhs``.byteenable = rhs``.byteenable; \
    always_comb rhs``.response = lhs``.response; \
    always_comb rhs``.readdata = lhs``.readdata; \
    always_comb rhs``.waitrequest = lhs``.waitrequest; \
    always_comb rhs``.readdatavalid = lhs``.readdatavalid; \
    always_comb rhs``.writeresponsevalid = lhs``.writeresponsevalid

`define LOGIC_AVALON_MM_IF_SLAVE_ASSIGN(lhs, rhs) \
    always_comb lhs``.read = rhs``_read; \
    always_comb lhs``.write = rhs``_write; \
    always_comb lhs``.address = rhs``_address; \
    always_comb lhs``.writedata = rhs``_writedata; \
    always_comb lhs``.byteenable = rhs``_byteenable; \
    always_comb rhs``_response = lhs``.response; \
    always_comb rhs``_readdata = lhs``.readdata; \
    always_comb rhs``_waitrequest = lhs``.waitrequest; \
    always_comb rhs``_readdatavalid = lhs``.readdatavalid; \
    always_comb rhs``_writeresponsevalid = lhs``.writeresponsevalid

`define LOGIC_AVALON_MM_IF_MASTER_ASSIGN(lhs, rhs) \
    always_comb lhs``_read = rhs``.read; \
    always_comb lhs``_write = rhs``.write; \
    always_comb lhs``_address = rhs``.address; \
    always_comb lhs``_writedata = rhs``.writedata; \
    always_comb lhs``_byteenable = rhs``.byteenable; \
    always_comb rhs``.response = lhs``_response; \
    always_comb rhs``.readdata = lhs``_readdata; \
    always_comb rhs``.waitrequest = lhs``_waitrequest; \
    always_comb rhs``.readdatavalid = lhs``_readdatavalid; \
    always_comb rhs``.writeresponsevalid = lhs``_writeresponsevalid

`endif /* LOGIC_AVALON_MM_SVH */
