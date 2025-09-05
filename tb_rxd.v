`timescale 1ns/1ps

module tb_rxd;
    reg clk;
    reg reset;
    reg rx_pin;
    wire [7:0] parallel_data;
    wire byte_packed;

    RxD DUT(
        .clk(clk),
        .reset(reset),
        .rx_pin(rx_pin),
        .parallel_data(parallel_data),
        .byte_packed(byte_packed)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task send_byte(input [7:0] data);
        integer i;
        begin
            // Start bit
            rx_pin = 0;
            #(860);

            // 8 data bits, LSB first
            for (i = 0; i < 8; i = i + 1) begin
                rx_pin = data[i];
                #(860);
            end

            // Stop bit
            rx_pin = 1;
            #(860);
        end
    endtask
    // Stimulus
    initial begin
    rx_pin = 1;   // idle
    reset  = 1;
    #1000 reset = 0;   // hold reset for >1 bit time

    // Send one byte: 0xA5
    send_byte(8'hBB);

    // Idle time before finish
    #(5000);
    $finish;
    end

    // Dump VCD
    initial begin
        $dumpfile("tb_rxd.vcd");
        $dumpvars(0, tb_rxd);
    end

    // Monitor
    initial begin
        $monitor("Time=%0t | reset=%b | rx_pin=%b | parallel_data=%h | byte_packed=%b",
                  $time, reset, rx_pin, parallel_data, byte_packed);
    end

endmodule