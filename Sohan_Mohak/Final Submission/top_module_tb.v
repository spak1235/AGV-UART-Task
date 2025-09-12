`timescale 1ns/1ps

module top_module_tb;

    // Testbench signals
    reg clk;
    reg reset;
    reg receiveData;
    wire transmitData;
    wire [15:0] max_dist_angle;
    wire [15:0] min_dist_angle;
    wire [15:0] obs_alert;

    // Clock period (100 MHz = 10 ns)
    localparam CLK_PERIOD = 10;
    // UART params
    localparam CLKS_PER_BIT = 87;  // same as your design
    localparam BIT_PERIOD   = CLK_PERIOD * CLKS_PER_BIT;

    // Instantiate DUT
    topModule uut (
        .receiveData(receiveData),
        .reset(reset),
        .clk(clk),
        .transmitData(transmitData),
        .max_dist_angle(max_dist_angle),
        .min_dist_angle(min_dist_angle),
        .obs_alert(obs_alert)
    );

    // Clock generator
    always #(CLK_PERIOD/2) clk = ~clk;

    // UART transmit task (sends 1 byte serially)
    task uart_write_byte(input [7:0] data);
        integer i;
        begin
            // Start bit
            receiveData <= 1'b0;
            #(BIT_PERIOD);
            // Data bits (LSB first)
            for (i=0; i<8; i=i+1) begin
                receiveData <= data[i];
                #(BIT_PERIOD);
            end
            // Stop bit
            receiveData <= 1'b1;
            #(BIT_PERIOD);
        end
    endtask

    // Reset + stimulus
    initial begin
        clk = 0;
        reset = 1;
        receiveData = 1; // idle line high

        #(10*CLK_PERIOD);
        reset = 0;

        // ---------- SEND PACKET ----------
        // Format your packet: 0x55 0xAA <CT> <FSA[7:0]> <FSA[15:8]>
        //                     <LSA[7:0]> <LSA[15:8]> <sample0[7:0]> <sample0[15:8]> ...
        // Example: 4 samples
        uart_write_byte(8'h55);  // header1
        uart_write_byte(8'hAA);  // header2
        uart_write_byte(8'd4);   // CT = number of samples

        uart_write_byte(8'h10);  // FSA low
        uart_write_byte(8'h00);  // FSA high = 0x0010

        uart_write_byte(8'h50);  // LSA low
        uart_write_byte(8'h00);  // LSA high = 0x0050

        // Samples (16-bit each)
        uart_write_byte(8'd20);  // sample0 low
        uart_write_byte(8'd0);   // sample0 high

        uart_write_byte(8'd200); // sample1 low
        uart_write_byte(8'd0);   // sample1 high

        uart_write_byte(8'd80);  // sample2 low
        uart_write_byte(8'd0);   // sample2 high

        uart_write_byte(8'd150); // sample3 low
        uart_write_byte(8'd0);   // sample3 high

        // ----------------------------------

        // Wait for processing to complete
        #(100*BIT_PERIOD);

        // Send a second packet (different samples)
        uart_write_byte(8'h55);
        uart_write_byte(8'hAA);
        uart_write_byte(8'd4);
        uart_write_byte(8'h20);
        uart_write_byte(8'h00);
        uart_write_byte(8'h60);
        uart_write_byte(8'h00);
        uart_write_byte(8'd50);
        uart_write_byte(8'd0);
        uart_write_byte(8'd250);
        uart_write_byte(8'd0);
        uart_write_byte(8'd90);
        uart_write_byte(8'd0);
        uart_write_byte(8'd120);
        uart_write_byte(8'd0);

        #(200*BIT_PERIOD);
        $finish;
    end

    // Monitor output
    initial begin
        $monitor("Time=%0t | max_dist_angle=%0d | min_dist_angle=%0d | obs_alert=%h",
                  $time, max_dist_angle, min_dist_angle, obs_alert);
    end

endmodule

