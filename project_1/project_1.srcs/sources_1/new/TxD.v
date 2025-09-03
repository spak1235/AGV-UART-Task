`timescale 1ns / 1ps

module TxD (
    input clk,
    input start_signal_bit,
    input baud_tick,
    input [15:0] max_distance_angle,
    input [15:0] min_distance_angle,
    input [15:0] obs_alert,
    output reg Tx
);

    localparam Idle  = 2'b00;
    localparam Start = 2'b01;
    localparam Transmission  = 2'b10;
    localparam Stop  = 2'b11;
    reg [1:0] state = Idle;
    reg [47:0] shift_reg; 
    reg [5:0] counter;
    always @(posedge clk) begin
        if(baud_tick) begin
            if(state == Idle) begin
                Tx <= 1'b1;
                if(start_signal_bit) begin
                    state = Start;
                    shift_reg[15:0]   <= max_distance_angle;
                    shift_reg[31:16]  <= min_distance_angle;
                    shift_reg[47:32]  <= obs_alert;
                end
            end
            if(state == Start) begin
                Tx <= 1'b0;
                state <= Transmission;
                counter <= 0;
            end
            if(state == Transmission) begin
                Tx <= shift_reg[counter];
                if(counter == 47) begin
                    state <= Stop; 
                end
                else begin
                    counter <= counter + 1;
                end
            end
            if(state == Stop) begin
                Tx <= 1'b1;
                state <= Idle;
            end
        end
    end
endmodule