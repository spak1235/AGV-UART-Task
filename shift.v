module shiftreg#(parameter MSB =8)(
        input wire stream,
        input wire clk,
        input wire trueclk,
        input wire latch,
        input wire reset,
        output reg [MSB-1:0]out);//latch =1 freezes value

    always @(posedge trueclk && reset) begin
        out <={(MSB-1){1'b0}};
    end
    always @ (posedge clk) begin
        if (!reset) begin
            if (!latch)
            out <= {stream,out[MSB-1:1]};
        end
        else
            out <={(MSB-1){1'b0}};
    end
endmodule

module counter#(parameter size=3)(
    input wire clk,
    input wire trueclk,
    input wire trigger,
    input wire reset,
    output reg trig);
    reg [size-1:0]store;

    always @(posedge trueclk && reset) begin
        store <= {size{1'b0}};
        trig <= 1'b0;
    end
    always@(posedge clk) begin
        if (!reset) begin
            if (trigger==1'b1) begin
                if (store == {size{1'b1}}) begin 
                    trig <= 1'b1;
                    store<= {size{1'b0}};
                end
                else trig <= 1'b0;
            end
            else begin
                store <= {size{1'b0}};
                trig <= 1'b0;
            end
            store +=1;
        end
        else begin
            store <= {size{1'b0}};
            trig <= 1'b0;
        end
    end
endmodule

