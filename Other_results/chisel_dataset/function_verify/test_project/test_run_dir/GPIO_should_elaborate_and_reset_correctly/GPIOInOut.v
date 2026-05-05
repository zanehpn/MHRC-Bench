// This module is inspired by Lucas Teske's Riscow digital port
// https://github.com/racerxdl/riskow/blob/main/devices/digital_port.v
//
module GPIOInOut (
  inout   [7:0] dataIO,
  input   [7:0] dataIn,
  output  [7:0] dataOut,
  input   [7:0] dir);

  generate
    genvar idx;
    for(idx = 0; idx < 8; idx = idx+1) begin: register
      `ifdef SIMULATION
      assign dataIO[idx] = dir[idx] ? dataIn[idx] : 1'b0;
      `else
      assign dataIO [idx]= dir[idx] ? dataIn[idx] : 1'bZ;
      `endif
     end
  endgenerate
  assign dataOut = dataIO;

endmodule
