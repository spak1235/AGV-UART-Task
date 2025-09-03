`timescale 1ns / 1ps

module baud_generator #(
    parameter clock_freq = 100000000,
    parameter baud_rate = 115200
)(
    input wire clk,
    output reg tick
);

localparam max_rate = clock_freq / (2*baud_rate * 16);
localparam cnt_width = $clog2(max_rate);

reg[cnt_width - 1:0] counter = 0;

initial begin
    tick = 1'b0;
end

always @(posedge clk) begin
    if(counter == max_rate[cnt_width-1:0]) begin
        counter <= 0;
        tick <= ~tick;
    end
    else begin
        counter <= counter + 1'b1;
    end
end

endmodule