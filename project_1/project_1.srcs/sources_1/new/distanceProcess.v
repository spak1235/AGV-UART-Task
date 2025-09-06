module distanceProcess (
    input clk,
    input rx_dv, 
    input reset,             // input strobe that new data has arrived
    input [7:0] ct,           // sample count (must be power of 2)
    input [15:0] FSA,         // first scan angle
    input [15:0] LSA,         // last scan angle
    output reg dv,            // data valid (1-cycle pulse when outputs update)
    output reg [15:0] obs_alert,
    output reg [15:0] max_dist_angle,
    output reg [15:0] min_dist_angle
);

    // Sample storage
    reg [15:0] sample_mem [255:0];

    // Internal working registers
    reg [15:0] temp_obs;
    reg [7:0]  max_dist_index;
    reg [7:0]  min_dist_index;
    reg [15:0] max_dist;
    reg [15:0] min_dist;

    // Temporary computed values
    reg [15:0] t_obs_alert;
    reg [15:0] t_max_dist_angle;
    reg [15:0] t_min_dist_angle;

    // Control state machine
    localparam ct_idle  = 2'b00;
    localparam ct_start = 2'b01;
    localparam ct_write = 2'b10;
    reg [1:0] ct_state;

    reg [7:0] ct_counter;
    reg final_dv;

    reg [3:0] k;  // log2(ct)

    integer i;

    always @(posedge clk) begin
        dv <= 1'b0;
        if (reset) begin
            temp_obs <= 0;
            max_dist_index <= 0;
            min_dist_index <= 0;
            max_dist <= 0;
            min_dist <= 0;
            t_max_dist_angle <= 0;
            t_min_dist_angle <= 0;
            t_obs_alert <= 0;
            ct_state <= ct_idle;
            ct_counter <= 0;
            final_dv <= 0;
            k <= 0;
            obs_alert <= 0;
            max_dist_angle <= 0;
            min_dist <= 0;
        end

        else begin
            if (rx_dv) begin
                final_dv <= 1'b1;
                $readmemh("sample_mem.mem", sample_mem);

                // compute k = log2(ct)
                case (ct)
                    6'd1: k<= 0;
                    8'd2:   k <= 1;
                    8'd4:   k <= 2;
                    8'd8:   k <= 3;
                    8'd16:  k <= 4;
                    8'd32:  k <= 5;
                    8'd64:  k <= 6;
                    8'd128: k <= 7;
                    default: k <= 0;
                endcase
            end

            if (final_dv) begin
                case (ct_state)

                    // Reset counters and prep for scanning
                    ct_idle: begin
                        ct_counter     <= 8'h00;
                        temp_obs       <= 16'h0000;
                        max_dist       <= 0;
                        min_dist       <= 16'hFFFF;
                        max_dist_index <= 8'h00;
                        min_dist_index <= 8'h00;
                        ct_state       <= ct_start;
                    end

                    // Process samples
                    ct_start: begin
                        if (ct_counter < ct) begin
                            if (sample_mem[ct_counter] < 102) begin
                                temp_obs <= temp_obs | (1 << ct_counter);
                            end
                            
                            if (sample_mem[ct_counter] > max_dist) begin
                                max_dist       <= sample_mem[ct_counter];
                                max_dist_index <= ct_counter;
                            end
                            
                            if (sample_mem[ct_counter] < min_dist) begin
                                min_dist       <= sample_mem[ct_counter];
                                min_dist_index <= ct_counter;
                            end

                            ct_counter <= ct_counter + 1;
                        end else begin
                        
                            t_obs_alert      <= temp_obs;

                            t_max_dist_angle <= FSA + (max_dist_index * ((LSA - FSA) >> k));
                            t_min_dist_angle <= FSA + (min_dist_index * ((LSA - FSA) >> k));

                            ct_state <= ct_write;
                        end
                    end

                    ct_write: begin
                        obs_alert      <= t_obs_alert;
                        max_dist_angle <= t_max_dist_angle;
                        min_dist_angle <= t_min_dist_angle;
                        dv             <= 1'b1;      // 1-cycle strobe
                        ct_state       <= ct_idle;   // return to idle
                        final_dv       <= 1'b0;      // wait for next rx_dv
                    end

                    default: begin
                        ct_state <= ct_idle;
                    end
                endcase
            end
        end
    end

endmodule