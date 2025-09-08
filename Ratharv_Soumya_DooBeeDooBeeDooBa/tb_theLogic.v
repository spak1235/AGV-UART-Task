`timescale 1ns/1ps
module tb_theLogic ();
//iverilog -o tb_theLogic.vvp theLogic.v tb_theLogic.v division.v
//vvp tb_theLogic.vvp
//gtkwave tb_theLogic.vcd

    // Inputs to DUT
    reg clk;
    reg rst;
    reg [7:0] data;
    reg takeData;

    // Outputs from DUT (declare as wires in TB)
    wire [15:0] max_distance_angle;
    wire [15:0] min_distance_angle;
    wire [15:0] obs_alert;
    wire sendData;

    // Extra outputs (for TB visibility) - match widths from module
    // wire rst_state;
    // wire [1:0] headCheck;
    // wire [7:0] CT, counter2, headerA, headerB, temp;
    // wire [15:0] FSA, LSA, obs_distance;
    // wire [31:0] quo_reg_min, quo_reg_max, rem_reg_min, rem_reg_max;
    // wire [15:0] min_distance, max_distance, AtHand, min_distance_idx, max_distance_idx;
    // wire [2:0] counter1;
    // wire divider_reset;
    // wire microCounter;
    // wire [31:0] numerator_min,numerator_max;
    // wire clkDelayer,hipHop,anotherClkDelayer;
    // wire [15:0] LSA_wire,FSA_wire;
    // wire [31:0] quo_min,rem_min,quo_max,rem_max;
    // wire busy_min,busy_max,division_done_min,division_done_max;
    // wire [1:0] quo_rem_reg;
    // wire divider_reset_wire;
    // wire [1:0] waiting_min,waiting_max;
    // wire [32:0] A_min,A_max,A_prev_max,A_prev_min;
    // wire [7:0] M_min,M_max;
    // wire [31:0] Q_min,Q_max;
    // wire [5:0] n_min,n_max;
    // Timeout variable: DECLARE AT MODULE SCOPE
    integer timeout;

    // UART-like spacing: number of cycles between bytes
    localparam SYMBOL_CYCLES = 8680; // ≈ 100 MHz / 11520 baud

    // Instantiate Device Under Test (DUT)
    theLogic uut (
        .data(data),
        .clk(clk),
        .rst(rst),
        .takeData(takeData),
        .max_distance_angle(max_distance_angle),
        .min_distance_angle(min_distance_angle),
        .obs_alert(obs_alert),
        .sendData(sendData)
        // tb-only outputs
        // .rst_state(rst_state),
        // .headCheck(headCheck),
        // .CT(CT),
        // .counter2(counter2),
        // .headerA(headerA),
        // .headerB(headerB),
        // .temp(temp),
        // .FSA(FSA),
        // .LSA(LSA),
        // .obs_distance(obs_distance),
        // .min_distance(min_distance),
        // .max_distance(max_distance),
        // .AtHand(AtHand),
        // .min_distance_idx(min_distance_idx),
        // .max_distance_idx(max_distance_idx),
        // .counter1(counter1),
        // .divider_reset(divider_reset),
        // .microCounter(microCounter),
        // .numerator_min(numerator_min),
        // .numerator_max(numerator_max),
        // .clkDelayer(clkDelayer),
        // .anotherClkDelayer(anotherClkDelayer),
        // .hipHop(hipHop),
        // .LSA_wire(LSA_wire),
        // .FSA_wire(FSA_wire),
        // .quo_min(quo_min),
        // .rem_min(rem_min),
        // .quo_max(quo_max),
        // .rem_max(rem_max),
        // .busy_min(busy_min),
        // .busy_max(busy_max),
        // .division_done_min(division_done_min),
        // .division_done_max(division_done_max),
        // .quo_rem_reg(quo_rem_reg),
        // .divider_reset_wire(divider_reset_wire)
    );

    // 10 ns clock (100 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Helper tasks: send data spaced by SYMBOL_CYCLES
    task send_byte(input [7:0] b);
        integer i;
    begin
        @(posedge clk);
        data <= b;
        takeData <= 1'b1;
        @(posedge clk);
        takeData <= 1'b0;

        // Wait remaining cycles of the symbol period
        for (i = 0; i < SYMBOL_CYCLES-2; i = i+1)
            @(posedge clk);
    end
    endtask

    task send_word16(input [15:0] w);
    begin
        // Module expects low byte first, then high byte
        send_byte(w[7:0]);    // low byte
        send_byte(w[15:8]);   // high byte
    end
    endtask

    // Test vector
    initial begin
        // Initialize
        rst <= 1'b1;
        data <= 8'h00;
        takeData <= 1'b0;

        // Hold reset for a few cycles
        repeat (5) @(posedge clk);
        rst <= 1'b0;

        // ---- Build packet ----
        // Header A (0x55), Header B (0xAA)
        send_byte(8'h55);
        send_byte(8'hAA);

        // CT = number of distance samples (choose 8)
        send_byte(8'd8);

        // FSA = 16 (0x0010)
        send_word16(16'h0010);

        // LSA = 160 (0x00A0)
        send_word16(16'h00A0);

        // Now send 8 distances (low then high)
        send_word16(16'd100); // idx 0
        send_word16(16'd150); // idx 1
        send_word16(16'd500);  // idx 2 -> expected min
        send_word16(16'd120); // idx 3
        send_word16(16'd110); // idx 4
        send_word16(16'd10); // idx 5
        send_word16(16'd200); // idx 6 -> expected max
        send_word16(16'd030); // idx 7

        // Wait for sendData to assert (with timeout)
        timeout = 0;
        while (!sendData && timeout < 200000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        #2000 $finish;
    end

    // Monitor important signals (print concise trace)
    initial begin
        $dumpfile("tb_theLogic.vcd");
        $dumpvars(0, tb_theLogic);
    end

endmodule
