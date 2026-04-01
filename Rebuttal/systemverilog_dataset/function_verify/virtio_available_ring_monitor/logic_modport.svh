`ifndef LOGIC_MODPORT_SVH
`define LOGIC_MODPORT_SVH

`ifndef LOGIC_MODPORT_DISABLED
    `define LOGIC_MODPORT(_interface, _modport) \
        _interface.``_modport
`else
    `define LOGIC_MODPORT(_interface, _modport) \
        _interface
`endif

`endif /* LOGIC_MODPORT_SVH */
