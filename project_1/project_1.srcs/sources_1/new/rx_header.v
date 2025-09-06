module rx_header (
    input clk,
    input serial,
    input reset,
    output reg rx_dv,
    output reg general_dv,
    output reg [7:0] s_CT,
    output reg [15:0] s_FSA,
    output reg [15:0] s_LSA
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
    localparam writing = 4'b1100;
    localparam cleanup = 4'b1111;
    wire [7:0] wi_general;
    wire wi_dv;
    reg [3:0] state; 
    reg [7:0] t_general;
    reg [15:0] sample_mem [255:0];
    reg [7:0] sample_index = 0;
    reg [7:0] sample_expected;
    reg [15:0] s_header;
    reg [15:0] s_sample;

    integer file;
    integer i;

    uart_rx general( clk, serial, wi_dv, wi_general);

    always @(posedge clk) begin
        if (reset) begin
            file = $fopen("sample_mem.mem", "w");
            for (i=0; i<256; i=i+1) begin
                sample_mem[i] <= 16'h0000;
            end
            rx_dv <= 1'b0;
            state <= idle;
            t_general <= 0;
            sample_index <= 0;
            sample_expected <= 0;
            s_header <= 0;
            s_sample <= 0;
        end

        else begin
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
                        state <= writing;
                    end
                end

                writing: begin
                    sample_mem[sample_index] <= s_sample;
                    $fdisplay(file, "%16b", s_sample);

                    if (sample_index == sample_expected - 1) begin
                        rx_dv <= 1'b1;
                        state <= cleanup;
                    end else begin
                        sample_index <= sample_index + 1;
                        state <= sample;
                    end
                end

                cleanup: begin
                    rx_dv <= 1'b0;
                    state <= idle;
                end

                default: begin
                    state <= idle;
                end
                
            endcase
        end
    end

endmodule 