module RxD (
    input  clk,
    input  reset,
    input  rx_pin,
    output reg [7:0] parallel_data,
    output reg byte_packed
);

    reg [2:0] rx_state; 
    reg [2:0] bit_counter;
    reg [6:0] baud_counter;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_state      <= 0;   // move to idle state
            bit_counter   <= 0;
            baud_counter  <= 0;
            parallel_data <= 0;
            byte_packed   <= 0;
        end else begin
            byte_packed <= 0;

            case(rx_state)
                // waiting for falling edge
                3'd0: begin
                    if (rx_pin == 0) begin
                        rx_state     <= 1;   // move to start state
                        baud_counter <= 0;
                    end
                end

                // start bit search
                3'd1: begin
                    baud_counter <= baud_counter + 1;
                    if (baud_counter == 43) begin
                        rx_state     <= 2;  // move to data read state
                        baud_counter <= 0;
                        bit_counter  <= 0;
                    end
                end

                // sample 8 bits
                3'd2: begin
                    baud_counter <= baud_counter + 1;

                    if (baud_counter == 43) begin
                        parallel_data[bit_counter] <= rx_pin;
                    end

                    if (baud_counter == 86) begin
                        baud_counter <= 0;
                        if (bit_counter == 7) begin
                            rx_state <= 3; // after last bit, move to stop state
                        end else begin
                            bit_counter <= bit_counter + 1;
                        end
                    end
                end

                // wait one bit time and then flag ready
                3'd3: begin
                    baud_counter <= baud_counter + 1;
                    if (baud_counter == 86) begin
                        rx_state     <= 0;   // back to IDLE
                        baud_counter <= 0;
                        byte_packed  <= 1;   // signal valid byte
                    end
                end
            endcase
        end
    end
endmodule