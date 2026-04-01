`Maxpool` depends on `BigBankReadData`, `SmallBankReadData`, `QuantedData`, and the wider `fpga_final_project` dataflow types.
The target logic is testable only with that surrounding banked-memory pipeline in place, so I did not fabricate a standalone local testbench here.
