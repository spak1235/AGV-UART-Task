module FSM_implementation #(
    parameter N = 2
)(
    input clk,
    input rst_n,
    input [N-1:0] req,
    output reg [N-1:0] gnt
);
    localparam IDEAL = 2'b00;
    localparam GNT_0 = 2'b01;
    localparam GNT_1 = 2'b10;
    reg [1:0] state;
    wire [1:0] next_state;

    assign next_state = fsm_function(state, req);
    
    function [1:0] fsm_function;
        input [1:0] state;
        input [1:0] req;
        case(state)
            IDEAL: begin
                case(req)
                    2'b00: begin
                        fsm_function = IDEAL;
                    end
                    2'b01: begin
                        fsm_function = GNT_0;
                    end
                    2'b10: begin
                        fsm_function = GNT_1;
                    end
                endcase
            end

            GNT_0: begin
                case(req[0])
                    1'b0: begin
                        fsm_function = IDEAL;
                    end
                    1'b1: begin
                        fsm_function = GNT_0;
                    end
                endcase
            end

            GNT_1: begin
                case(req[1])
                    1'b0: begin
                        fsm_function = IDEAL;
                    end
                    1'b1: begin
                        fsm_function = GNT_1;
                    end
                endcase
            end

            default: begin
                fsm_function = IDEAL;
            end
        endcase
    endfunction

    always@(posedge(clk)) begin
        if(rst_n == 1'b1) begin
            state <= IDEAL;
        end
        else begin
            state <= next_state;
        end
    end

    always@(posedge(clk)) begin
        if(rst_n == 1'b1) begin
            gnt <= 2'b00;
        end

        else begin
            case(state)
                IDEAL: gnt <= 2'b00;
                GNT_0: gnt <= 2'b01;
                GNT_1: gnt <= 2'b10;
                default: gnt <= 2'b00;
            endcase
        end
    end

endmodule