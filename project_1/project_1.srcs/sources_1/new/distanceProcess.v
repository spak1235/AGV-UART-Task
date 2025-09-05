module distanceProcess (
    input clk,
    input [7:0] ct,
    input [15:0] FSA,
    input [15:0] LSA,
    output reg data_validation,
    output reg [15:0] obs_alert,
    output reg [15:0] max_dist_angle,
    output reg [15:0] min_dist_angle
);

    reg [15:0] sample_mem [255:0];
    reg [15:0] temp_obs;
    reg [7:0] max_dist_index;
    reg [7:0] min_dist_index;
    reg [15:0] max_dist;
    reg [15:0] min_dist;
    
    localparam ct_idle = 1'b0;
    localparam ct_start = 1'b1;
    reg ct_state;
    reg [7:0] ct_counter;
    reg [3:0] k;

    integer i;

    initial begin
        $readmemh("sample_mem.mem", sample_mem);
        obs_alert <= 0;
        max_dist_angle <= 0;
        min_dist_angle <= 0;
    end

    always @(posedge clk) begin
        case (ct_state)
            ct_idle: begin
                ct_counter <= 0;
                data_validation <= 1'b0;
                temp_obs <= 16'h0000;
                max_dist <= 0;
                min_dist <= 16'hFFFF;
                max_dist_index <= 0;
                min_dist_index <= 0;
                k <= 0;
                ct_state <= ct_start;
            end

            ct_start: begin
                if (ct_counter < ct) begin
                    if (ct_counter < 8 && ct[ct_counter]) begin
                        k <= ct_counter[3:0];
                    end

                    if (ct_counter < 16) begin
                        if (sample_mem[ct_counter] < 102.4) begin
                            temp_obs <= temp_obs | (1 << ct_counter);
                            obs_alert <= temp_obs;
                        end
                    end

                    if (sample_mem[ct_counter] > max_dist) begin
                        max_dist <= sample_mem[ct_counter];
                        max_dist_index <= ct_counter[7:0];
                    end

                    if (sample_mem[ct_counter] < min_dist) begin
                        min_dist       <= sample_mem[ct_counter];
                        min_dist_index <= ct_counter[7:0];
                    end
                end

                if (ct_counter == ct-1) begin
                    data_validation <= 1'b1;
                    ct_state <= ct_idle;
                end

                ct_counter <= ct_counter + 1;
            end
            
            default begin
                ct_state <= ct_idle;
            end
        endcase
    end

    always @(posedge clk) begin
        if (data_validation) begin
            obs_alert <= temp_obs;
            max_dist_angle <= FSA + max_dist_index * ((LSA - FSA) << k);
            min_dist_angle <= FSA + min_dist_index * ((LSA - FSA) << k);
        end
    end

endmodule