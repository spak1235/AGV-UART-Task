module TxD #(
    parameter CLKS_PER_BIT = 87
)(
    input clk,
    input reset,                    
    input start_signal_bit,
    input [15:0] max_distance_angle,
    input [15:0] min_distance_angle,
    input [15:0] obs_alert,
    output reg Tx,
    output reg [47:0] shift_reg,
    output reg [7:0] r_clock
);

    localparam Idle        = 5'b00000;
    localparam Start       = 5'b00001;
    localparam Transmission_mad_1 = 5'b00010;
    localparam Transmission_mad_2 = 5'b10010;
    localparam Transmission_mid_1 = 5'b00011;
    localparam Transmission_mid_2 = 5'b10011;
    localparam Transmission_obs_1 = 5'b00100;
    localparam Transmission_obs_2 = 5'b10100;
    localparam trans_end_1 = 5'b01000;
    localparam trans_end_2 = 5'b01001;
    localparam trans_end_3 = 5'b01010;
    localparam trans_end_4 = 5'b01011;
    localparam trans_end_5 = 5'b01100;
    localparam trans_start_1 = 5'b11000;
    localparam trans_start_2 = 5'b11001;
    localparam trans_start_3 = 5'b11010;
    localparam trans_start_4 = 5'b11011;
    localparam trans_start_5 = 5'b11100;
    localparam Stop        = 5'b11111;

    reg [4:0] state;  
    reg [3:0] counter = 0; 
    always @(negedge start_signal_bit) begin
        shift_reg[15:0] <= max_distance_angle;
        shift_reg[31:16] <= min_distance_angle;
        shift_reg[47:32] <= obs_alert;
    end    

    always @(posedge clk) begin
        if (reset) begin
            Tx        <= 1'b1;     
            state     <= Idle;      
            shift_reg <= 0;    
            counter   <= 0;
            r_clock <= 0;    
        end else begin
            case (state)
                Idle: begin
                    Tx <= 1'b1;
                    if (start_signal_bit) begin
                        state <= Start;
                        counter <= 6'd0;
                    end
                end
                Start: begin
                    if (r_clock == CLKS_PER_BIT-1) begin
                        Tx    <= 1'b0; 
                        state <= Transmission_mad_1;
                        counter <= 0;
                    end
                end

                Transmission_mad_1: begin
                    if (r_clock == CLKS_PER_BIT-1) begin
                        Tx <= shift_reg[counter];  
                        if (counter == 7) begin
                            state <= trans_end_1;  
                            counter <= 0;       
                        end else begin
                            counter <= counter + 1'b1;
                        end
                    end
                end

                Transmission_mad_2: begin
                    if (r_clock == CLKS_PER_BIT-1) begin
                        Tx <= shift_reg[8+counter];  
                        if (counter == 7) begin
                            state <= trans_end_2; 
                            counter <= 0;        
                        end else begin
                            counter <= counter + 1'b1;
                        end
                    end
                end

                Transmission_mid_1: begin
                    if (r_clock == CLKS_PER_BIT-1) begin
                        Tx <= shift_reg[16+counter];  
                        if (counter == 7) begin
                            state <= trans_end_3;
                            counter <= 0;        
                        end else begin
                            counter <= counter + 1'b1;
                        end
                    end
                end

                Transmission_mid_2: begin
                    if (r_clock == CLKS_PER_BIT-1) begin
                        Tx <= shift_reg[24+counter];  
                        if (counter == 7) begin
                            state <= trans_end_4;
                            counter <= 0;         
                        end else begin
                            counter <= counter + 1'b1;
                        end
                    end
                end

                Transmission_obs_1: begin
                    if (r_clock == CLKS_PER_BIT-1) begin
                        Tx <= shift_reg[32+counter];  
                        if (counter == 7) begin
                            state <= trans_end_5;
                            counter <= 0;         
                        end else begin
                            counter <= counter + 1'b1;
                        end
                    end
                end

                Transmission_obs_2: begin
                    if (r_clock == CLKS_PER_BIT-1) begin
                        Tx <= shift_reg[40+counter];  
                        if (counter == 7) begin
                            state <= Stop;
                            counter <= 0;         
                        end else begin
                            counter <= counter + 1'b1;
                        end
                    end
                end

                trans_end_1: begin
                    if (r_clock == CLKS_PER_BIT-1) begin
                        Tx <= 1'b1;
                        state <= trans_start_1;
                    end
                end

                trans_end_2: begin
                    if (r_clock == CLKS_PER_BIT-1) begin
                        Tx <= 1'b1;
                        state <= trans_start_2;
                    end
                end

                trans_end_3: begin
                    if (r_clock == CLKS_PER_BIT-1) begin
                        Tx <= 1'b1;
                        state <= trans_start_3;
                    end
                end

                trans_end_4: begin
                    if (r_clock == CLKS_PER_BIT-1) begin
                        Tx <= 1'b1;
                        state <= trans_start_4;
                    end
                end

                trans_end_5: begin
                    if (r_clock == CLKS_PER_BIT-1) begin
                        Tx <= 1'b1;
                        state <= trans_start_5;
                    end
                end
                
                trans_start_1: begin
                    if (r_clock == CLKS_PER_BIT-1) begin
                        Tx <= 1'b0;
                        state <= Transmission_mad_2;
                    end
                end

                trans_start_2: begin
                    if (r_clock == CLKS_PER_BIT-1) begin
                        Tx <= 1'b0;
                        state <= Transmission_mid_1;
                    end
                end

                trans_start_3: begin
                    if (r_clock == CLKS_PER_BIT-1) begin
                        Tx <= 1'b0;
                        state <= Transmission_mid_2;
                    end
                end

                trans_start_4: begin
                    if (r_clock == CLKS_PER_BIT-1) begin
                        Tx <= 1'b0;
                        state <= Transmission_obs_1;
                    end
                end

                trans_start_5: begin
                    if (r_clock == CLKS_PER_BIT-1) begin
                        Tx <= 1'b0;
                        state <= Transmission_obs_2;
                    end
                end

                Stop: begin
                    if (r_clock == CLKS_PER_BIT-1) begin
                        Tx    <= 1'b1; 
                        state <= Idle; 
                    end
                end

                default: begin
                    state <= Idle;
                end
            endcase
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            r_clock <= 0;
        end
        else begin
            if (r_clock == CLKS_PER_BIT-1) begin
                r_clock <= 0;
            end
            else begin
                r_clock <= r_clock + 1'b1;
            end
        end
    end

endmodule