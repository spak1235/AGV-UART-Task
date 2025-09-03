module rx_header (
    input clk,
    input serial,
    output reg general_dv,
    output reg [15:0] s_header,
    output reg [7:0] s_CT,
    output reg [15:0] s_FSA,
    output reg [15:0] s_LSA,
    output reg [15:0] s_sample
);

    localparam idle = 4'b0000;
    localparam header_1 = 4'b0001;
    localparam ct = 4'b0010;
    localparam fsa = 4'b0100;
    localparam fsa_1 = 4'b0101;
    localparam lsa = 4'b0110;
    localparam lsa_1 = 4'b0111;
    localparam sample = 4'b1000;
    localparam sample_1 = 4'b1001;
    wire [7:0] wi_general;
    wire wi_dv;
    reg [3:0] state = 4'b0000; 
    reg [7:0] t_general = 8'h00;
    
    reg [15:0] sample_mem [255:0];
    reg [7:0] sample_index = 0;
    reg [7:0] sample_expected;
    reg [15:0] obs_alert = 0;
    reg [7:0] max_dist_index = 0;
    reg [7:0] min_dist_index = 0;
    reg [15:0] max_dist = 16'b0000000000000000;
    reg [15:0] min_dist = 16'b1111111111111111;
    reg [15:0] max_dist_angle;
    reg [15:0] min_dist_angle;

    integer file;
    integer i;
    initial begin 
        file = $fopen("sample_mem.mem", "w");
    end

    uart_rx general( clk, serial, wi_dv, wi_general);

    always @(posedge clk) begin
        t_general <= wi_general;
        general_dv <= wi_dv;
        case(state)
            idle: begin
                if (wi_dv == 1'b1) begin
                    if (wi_general == 8'h55) begin
                        s_header[7:0] <= wi_general;
                        state <= header_1;
                    end
                    else begin
                        state <= idle;
                    end
                end
                else begin
                    state <= idle;
                end
            end
            
            header_1: begin
                if (wi_dv == 1'b1) begin
                    if (wi_general == 8'hAA) begin
                        s_header[15:8] <= wi_general;
                        state <= ct;
                    end
                end
                else begin
                    state <= header_1;
                end
            end

            ct: begin
                if (wi_dv == 1'b1) begin
                    s_CT <= wi_general;
                    state <= fsa;
                    sample_expected <= wi_general;
                    sample_index <= 0;
                end
            end

            fsa: begin
                if (wi_dv == 1'b1) begin
                    s_FSA[7:0] <= wi_general;
                    state <= fsa_1;
                end
            end
            
            fsa_1: begin
                if (wi_dv == 1'b1) begin
                    s_FSA[15:8] <= wi_general;
                    state <= lsa;
                end
            end

            lsa: begin
                if (wi_dv == 1'b1) begin
                    s_LSA[7:0] <= wi_general;
                    state <= lsa_1;
                end
            end
            
            lsa_1: begin
                if (wi_dv == 1'b1) begin
                    s_LSA[15:8] <= wi_general;
                    state <= sample;
                end
            end

            sample: begin
                if (wi_dv == 1'b1) begin
                    s_sample[7:0] <= wi_general;
                    state <= sample_1;
                end
            end
            
            sample_1: begin
                if (wi_dv == 1'b1) begin
                    s_sample[15:8] <= wi_general;
                    
                    sample_mem[sample_index] <= s_sample;
                    if (sample_index < 16) begin
                        if (sample_mem[sample_index] < 102.4) begin
                            obs_alert <= obs_alert | (1<<sample_index);
                        end
                    end

                    if(sample_mem[sample_index] > max_dist) begin
                        max_dist <= sample_mem[sample_index];
                        max_dist_index <= sample_index;
                    end

                    if(sample_mem[sample_index] < min_dist) begin
                        min_dist <= sample_mem[sample_index];
                        min_dist_index <= sample_index;
                    end

                    sample_index <= sample_index+1;
                    
                    if (sample_index == sample_expected) begin
                        max_dist_angle = s_FSA + max_dist_index*((s_LSA-s_FSA)/(s_CT-1));
                        min_dist_angle = s_FSA + min_dist_index*((s_LSA-s_FSA)/(s_CT-1));
                        for (i = 0; i < s_CT; i=i+1) begin
                            $fdisplay(file, "%16b", sample_mem[i]);
                        end
                        state <= idle;
                    end
                    else begin
                        state <= sample;
                    end
                end
            end
            
        endcase
    end

endmodule 