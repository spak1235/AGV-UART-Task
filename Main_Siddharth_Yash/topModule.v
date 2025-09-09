`timescale 1ns/1ps
//Don't forget to import your module files here
`include "shift.v"
//`include "Mod1.v"
//`include "ModProcess.v"
`include "newrdx.v"
`include "newdx.v"


module topModule(
    input wire receiveData,
    input wire clk,
    input reset,
    output wire transmitData
    // We don't think you will need any other inputs and outputs, but feel free to add what you want here, and mention it while submitting your code
);

    // Include your submodules for receiving, processing and transmitting your data here, we have included sample modules without any inputs and outputs for now
    wire [7:0]RDX_InfoPulse;
    wire RDX_infotime;

    RxD R0(receiveData,clk,reset,RDX_InfoPulse,RDX_infotime);

    wire [15:0]DX_LOWEST;
    wire [15:0]DX_HIGHEST;
    wire [15:0]DX_HITOUT;
    wire DX_flashout;
    distanceProcess D0(clk,RDX_InfoPulse,RDX_infotime,reset,DX_LOWEST,DX_HIGHEST,DX_HITOUT,DX_flashout);

    TxD T0(clk,reset,16'hAA55,{DX_LOWEST,DX_HIGHEST,DX_HITOUT},DX_flashout,transmitData);
endmodule
