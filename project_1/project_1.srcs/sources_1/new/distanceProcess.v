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
    reg [15:0] temp_obs = 16'b0000000000000000;
    reg [7:0] max_dist_index = 0;
    reg [7:0] min_dist_index = 0;
    reg [15:0] max_dist = 16'b0000000000000000;
    reg [15:0] min_dist = 16'b1111111111111111;
    integer i;
    integer j;
    integer k;

    initial begin
        $readmemh("memory_data.mem", sample_mem);
    end

    always @(posedge clk) begin
        for (j=0; j<8; j=j+1) begin
            if (ct[j] == 1'b1) begin
                k <= j;
            end
        end

        for (i=0; i<ct; i=i+1) begin
            if (i < 16) begin
                if (sample_mem[i] < 102.4) begin
                    temp_obs <= temp_obs | (1<<i); 
                end
            end

            if(sample_mem[i] > max_dist) begin
                max_dist <= sample_mem[i];
                max_dist_index <= i;
            end

            if(sample_mem[i] < min_dist) begin
                min_dist <= sample_mem[i];
                min_dist_index <= i;
            end

            min_dist_angle = FSA + min_dist_index*((LSA-FSA)<<k);
            max_dist_angle = FSA + max_dist_index*((LSA-FSA)<<k);
        end
        
        if (max_dist_angle == 16'bxxxxxxxxxxxxxxxx || min_dist_angle == 16'bxxxxxxxxxxxxxxxx || temp_obs == 16'bxxxxxxxxxxxxxxxx) begin
            data_validation <= 1'b0;
        end
        else begin
            data_validation <= 1'b1;
        end
        obs_alert <= temp_obs;
    end
endmodule