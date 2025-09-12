module RxD #(
    parameter N = 1,
    parameter CLKS_PER_BIT = 87
)(
    input clk,
    input i_rx_s,
    output reg o_Rx_DV = 0,
    output reg [7:0] o_Rx_Byte = 8'b0
);

    localparam idle = 3'b000;
    localparam start = 3'b001;
    localparam data = 3'b010;
    localparam stop = 3'b011;
    localparam cleanup = 3'b100;

    reg [2:0] state = idle;
    reg [7:0] r_clock = 0;
    reg [2:0] r_index = 0;
    reg [7:0] rx_byte = 0;
    reg rx_data = 1;

    always @(posedge clk) begin
        rx_data <= i_rx_s;
    end

    always @(posedge clk) begin
        case (state)
            idle: begin
                o_Rx_DV <= 1'b0;
                r_clock <= 0;
                r_index <= 0;
                if (rx_data == 1'b0)
                    state <= start;
                else
                    state <= idle;
            end

            start: begin
                if (r_clock == (CLKS_PER_BIT-1)/2) begin
                    if (rx_data == 1'b0) begin
                        r_clock <= 0;
                        state <= data;
                    end else begin
                        state <= idle;
                    end
                end else begin
                    r_clock <= r_clock + 1;
                end
            end

            data: begin
                if (r_clock < CLKS_PER_BIT-1) begin
                    r_clock <= r_clock + 1;
                end else begin
                    r_clock <= 0;
                    rx_byte[r_index] <= rx_data;
                    if (r_index < 7) begin
                        r_index <= r_index + 1;
                    end else begin
                        r_index <= 0;
                        state <= stop;
                    end
                end
            end

            stop: begin
                if (r_clock < CLKS_PER_BIT-1) begin
                    r_clock <= r_clock + 1;
                end else begin
                    o_Rx_DV   <= 1'b1;
                    r_clock <= 0;
                    state <= cleanup;
                    o_Rx_Byte <= rx_byte;
                end
            end

            cleanup: begin
                state <= idle;
                o_Rx_DV <= 1'b0;
            end

            default: 
                state <= idle;
        endcase
    end

endmodule
