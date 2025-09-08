module ext_clock (
    input wire clock,
    input wire reset,
    input wire enable,
    output reg ext_clk
);
parameter CYCLES = 4;
reg [3:0] count = 4'b0;
always @(posedge clock or posedge reset) begin
    if(reset || !enable) begin
        count <= 4'b0;
        ext_clk <= 0;
    end
    else begin
        if(count > 0) begin
            count <= count -1;
        end
        else if(count == 0) begin
            ext_clk <= ~ext_clk;
            count <= CYCLES-1;
        end
    end
end
endmodule

module main_clock (
    input wire clock,
    input wire reset,
    input wire enable,
    output reg main_clk
);
parameter CYCLE = 434;
reg [23:0] count = 24'b0;

always @(posedge clock or posedge reset) begin
    if(reset || !enable) begin
        count <= 24'b0;
        main_clk <= 0;
    end
    else begin
        if(count > 0) begin
            count <= count -1;
        end
        else if(count == 0) begin
            main_clk <= ~main_clk;
            count <= CYCLE-1;
        end
    end
end
endmodule

module timed_pulse (  
    input wire clock,
    input wire reset,
    input wire enable,
    output reg timed_pulse
);
    parameter CYCLE = 3*434;
    reg state;
    reg [23:0] count;
    always @(posedge clock or posedge reset) begin
        if(reset) begin
            state <= 1'b0;
            timed_pulse <= 0;
            count <= 24'b0;
        end
        else begin
        case (state)
            1'b0 : begin
                timed_pulse <= 0;
                if(enable) begin count <= CYCLE-1; timed_pulse <= 0; state <= 1'b1; end
            end
            1'b1 : begin
                if(!enable) begin 
                    state <= 1'b0; 
                    timed_pulse <= 0;
                    count <= 24'b0; 
                end
                else if(count > 24'b0) begin
                    timed_pulse <= 0;
                    count <= count-1;
                end
                else begin
                    timed_pulse <= 1;
                    count <= 24'b0;
                end
            end
            default : begin
                state <= 1'b0;
                timed_pulse <= 0;
                count <= 24'b0;
            end
        endcase
        end
    end
endmodule




/*
module testbench;
    parameter BPS = 115200;
    reg clock, reset, enable;
    wire main_clk, ext_clk, half_pulse;
    main_clock test_main_clock (
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .main_clk(main_clk)
    );
    ext_clock test_ext_clock (
        .clock(main_clk),
        .reset(reset),
        .enable(enable),
        .ext_clk(ext_clk)
    );
    timed_pulse test_half_pulse(
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .timed_pulse(half_pulse)
    );
    initial #10000000 $finish;
    initial begin
    clock = 1; // 100MHz clock with 50% duty cycle
    forever #5 clock = ~clock;
    end
    initial fork
        reset = 1;
        enable = 0;
        #1000 reset = 0;
        #10000 enable = 1;
        #300000 reset = 1;
        #350000 reset = 0;
        #700000 enable = 0;
        #750000 enable = 1;
        #1500000 enable = 0;
    join

    // For waveform generation
    initial begin
    $dumpfile("timer.vcd");
    $dumpvars(0, testbench);
    end
endmodule
*/