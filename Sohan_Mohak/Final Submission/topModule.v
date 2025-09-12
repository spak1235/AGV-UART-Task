`timescale 1ns/1ps
//Don't forget to import your module files here

module topModule(
    input wire receiveData,
    input wire reset,
    input wire clk,
    output wire transmitData,
    output wire [15:0] max_dist_angle,
    output wire [15:0] min_dist_angle,
    output wire [15:0] obs_alert
    // We don't think you will need any other inputs and outputs, but feel free to add what you want here, and mention it while submitting your code
);
    wire wi_dv;
    wire [7:0] wi_general;
    wire rx_dv;
    wire [7:0] s_CT;
    wire [15:0] s_LSA;
    wire [15:0] s_FSA;
    //wire [15:0] obs_alert;
    //wire [15:0] max_dist_angle;
    //wire [15:0] min_dist_angle;

    RxD R0(clk, receiveData, wi_dv, wi_general);
    distanceProcess D0(clk, reset, wi_dv, wi_general, rx_dv, s_CT, s_FSA, s_LSA, obs_alert, max_dist_angle, min_dist_angle);
    TxD T0(clk, reset, rx_dv, max_dist_angle, min_dist_angle, obs_alert, transmitData);

endmodule
