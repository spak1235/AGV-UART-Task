module distanceProcess (
    input clk,
    input serial,
    input reset,
    output reg rx_dv,
    output reg [7:0] s_CT,
    output reg [15:0] s_FSA,
    output reg [15:0] s_LSA,
    output reg [15:0] obs_alert,
    output reg [15:0] max_dist_angle,
    output reg [15:0] min_dist_angle
);

    localparam idle     = 4'b0000;
    localparam header_1 = 4'b0001;
    localparam ct       = 4'b0010;
    localparam fsa      = 4'b0100;
    localparam fsa_1    = 4'b0101;
    localparam lsa      = 4'b0110;
    localparam lsa_1    = 4'b0111;
    localparam sample   = 4'b1000;
    localparam sample_1 = 4'b1001;
    localparam writing  = 4'b1100;
    localparam cleanup  = 4'b1111;

    wire [7:0] wi_general;
    wire wi_dv;

    reg [3:0] state; 
    reg [7:0] t_general;
    reg [15:0] sample_mem [255:0];
    reg [7:0]  sample_index;
    reg [7:0]  sample_expected;
    reg [15:0] s_header;
    reg [15:0] s_sample;
    reg general_dv;

    reg [7:0]  min_dist_index;
    reg [7:0]  max_dist_index;
    reg [3:0]  k;
    reg [15:0] max_dist;
    reg [15:0] min_dist;

    integer i;

    RxD general( clk, serial, wi_dv, wi_general);

    always @(posedge clk) begin
        if (reset) begin
            rx_dv <= 1'b0;
            general_dv <= 1'b0;
            state <= idle;
            t_general <= 8'h00;
            sample_index <= 8'h00;
            sample_expected <= 8'h00;
            s_header <= 16'h0000;
            s_sample <= 16'h0000;
            obs_alert <= 16'h0000;
            max_dist <= 16'h0000;
            min_dist <= 16'hFFFF;
            max_dist_index <= 8'h00;
            min_dist_index <= 8'h00;
            k <= 4'h0;
            max_dist_angle <= 16'h0000;
            min_dist_angle <= 16'h0000;
        end 
        
        else begin
            t_general <= wi_general;
            general_dv <= wi_dv;

            case (state)
                idle: begin
                    max_dist <= 16'h0000;
                    min_dist <= 16'hFFFF;
                    if (wi_dv) begin
                        if (wi_general == 8'h55) begin
                            s_header[7:0] <= wi_general;
                            state <= header_1;
                            obs_alert <= 16'h0000;
                        end else begin
                            state <= idle;
                        end
                    end else begin
                        state <= idle;
                    end
                end

                header_1: begin
                    if (wi_dv) begin
                        if (wi_general == 8'hAA) begin
                            s_header[15:8] <= wi_general;
                            state <= ct;
                        end else begin
                            state <= idle;
                        end
                    end
                end

                ct: begin
                    if (wi_dv) begin
                        s_CT <= wi_general;
                        sample_expected <= wi_general;
                        sample_index <= 8'h00;
                        case (wi_general)
                            8'd1: k <= 0;
                            8'd2: k <= 1;
                            8'd4: k <= 2;
                            8'd8: k <= 3;
                            8'd16: k <= 4;
                            8'd32: k <= 5;
                            8'd64: k <= 6;
                            8'd128: k <= 7;
                            default: k <= 0;
                        endcase
                        state <= fsa;
                    end
                end

                fsa: begin
                    if (wi_dv) begin
                        s_FSA[7:0] <= wi_general;
                        state <= fsa_1;
                    end
                end

                fsa_1: begin
                    if (wi_dv) begin
                        s_FSA[15:8] <= wi_general;
                        state <= lsa;
                    end
                end

                lsa: begin
                    if (wi_dv) begin
                        s_LSA[7:0] <= wi_general;
                        state <= lsa_1;
                    end
                end

                lsa_1: begin
                    if (wi_dv) begin
                        s_LSA[15:8] <= wi_general;
                        state <= sample;
                    end
                end

                sample: begin
                    if (wi_dv) begin
                        s_sample[7:0] <= wi_general;
                        state <= sample_1;
                    end
                end

                sample_1: begin
                    if (wi_dv) begin
                        s_sample[15:8] <= wi_general;
                        state <= writing;
                    end
                end

                writing: begin
                    sample_mem[sample_index] <= s_sample;
                    if (sample_index < sample_expected) begin
                        if (sample_index < 16) begin
                            if (s_sample <16'd102) begin
                                obs_alert <= obs_alert | (16'h1 << sample_index);
                            end
                        end

                        if (s_sample < min_dist) begin
                            min_dist <= s_sample;
                            min_dist_index <= sample_index;
                        end

                        if (s_sample > max_dist) begin
                            max_dist <= s_sample;
                            max_dist_index <= sample_index;
                        end
                    end

                    if (sample_index == sample_expected - 1) begin
                        max_dist_angle <= s_FSA + (max_dist_index * ((s_LSA - s_FSA) >> k));
                        min_dist_angle <= s_FSA + (min_dist_index * ((s_LSA - s_FSA) >> k));
                        rx_dv <= 1'b1;
                        state <= cleanup;
                    end else begin
                        sample_index <= sample_index + 1;
                        state <= sample;
                    end
                end

                cleanup: begin
                    rx_dv <= 1'b0;
                    sample_index <= 8'h00;
                    state <= idle;
                end

                default: begin
                    state <= idle;
                end
            endcase
        end
    end

endmodule
