`timescale 1ns/1ps
//Don't forget to import your module files here

module topModule(
    input wire receiveData,
    input wire clk,
    output wire transmitData
    // We don't think you will need any other inputs and outputs, but feel free to add what you want here, and mention it while submitting your code
);

    // Include your submodules for receiving, processing and transmitting your data here, we have included sample modules without any inputs and outputs for now
    RxD R0();
    distanceProcess D0();
    TxD T0();

endmodule
