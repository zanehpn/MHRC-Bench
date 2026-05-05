`ifndef LOGIC_SVH
`define LOGIC_SVH

`ifdef SYNTHESIS
    `ifdef OVL_ASSERT_ON
        `undef OVL_ASSERT_ON
    `endif
`elsif VERILATOR
    `define SYNTHESIS
`endif

`include "logic_drc.svh"
`include "logic_axi4.svh"
`include "logic_avalon.svh"
`include "logic_modport.svh"

`ifdef OVL_ASSERT_ON
`define OVL_VERILOG
`define OVL_SVA_INTERFACE
`include "std_ovl_defines.h"
`endif

`endif /* LOGIC_SVH */
