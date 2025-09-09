
module div(input [23:0]big,
        input [7:0]smal,
        input flash_inp,
        input clk,
        input reset,
        output reg [15:0]lessbig,
        output reg flash);

    localparam IDLE = 3'o0;localparam IVAL = 3'o1;localparam FLAG = 3'o2;
    reg[23:0] biginp;
    reg[7:0] smallinp;
    
    reg [2:0] state;
    reg [3:0] counter;
    always @(posedge clk) begin
        if (!reset) begin
            case (state)
                IDLE: begin
                    flash <=0;
                    biginp <= big;
                    smallinp <= smal;
                    if (flash_inp) begin
                        state <= IVAL;
                    end
                    end
                IVAL: begin
                    if (biginp >= (smallinp<<counter)) begin
                        biginp <= biginp - (smallinp<<counter);
                        lessbig[counter] <= 1'b1;
                    end
                    if (counter == 0) state = FLAG;
                    else counter <= counter -1;
                end
                FLAG : begin
                    flash <= 1'b1;
                    counter <= 4'hF;
                    state <= IDLE;
                end

            endcase;
        end
        else begin
            state <= 3'o0;
            counter <= 4'hF;
            lessbig <= 16'h0000;
            flash <= 1'b0;
            biginp <= 24'h000000;
            smallinp <= 8'h00;
        end

    end
endmodule