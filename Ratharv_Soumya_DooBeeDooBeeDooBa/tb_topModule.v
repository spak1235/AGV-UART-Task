`timescale 1ns/1ps

module tb_topModule;

    // DUT signals
    reg clk;
    reg receiveData;    // serial input to DUT
    wire transmitData;
    reg reset;  // serial output from DUT
    wire reset1;
    wire [7:0] parallel_data;
    wire byte_packed;
    wire [15:0] min_distance_angle;
    wire [15:0] max_distance_angle;
    wire [15:0] obs_alert;
    wire sendData;
    wire [1:0]headCheck;
     wire [7:0] CT;
     wire [15:0] FSA,LSA;
      wire [2:0] counter1;
     wire [7:0] counter2;
     wire [15:0] min_distance,max_distance,AtHand;
     wire sendingDone;
     wire [2:0] steps;
     wire extraCounter;
     wire [2:0] quo_rem_reg;
     wire busy;
     wire receiveDataPliz;
     wire [15:0] min_distance_angle_local;
     wire TxD_reset;
     wire [1:0] state;
     wire startTheSending;
     wire baud_clk;

    assign reset1 = reset;
    // Instantiate DUT
    topModule DUT (
        .clk(clk),
        .receiveData(receiveData),
        .transmitData(transmitData),
        .reset(reset1)
        // .parallel_data(parallel_data),
        // .byte_packed(byte_packed),
        // .min_distance_angle(min_distance_angle),
        // .max_distance_angle(max_distance_angle),
        // .obs_alert(obs_alert),
        // .sendData(sendData),
        // .headCheck(headCheck),
        // .CT(CT),
        // .LSA(LSA),
        // .FSA(FSA),
        // .counter1(counter1),
        // .counter2(counter2),
        // .min_distance(min_distance),
        // .max_distance(max_distance),
        // .AtHand(AtHand),
        // .sendingDone(sendingDone),
        // .steps(steps),
        // .quo_rem_reg(quo_rem_reg),
        // .busy(busy),
        // .receiveDataPliz(receiveDataPliz),
        // .min_distance_angle_local(min_distance_angle_local),
        // .TxD_reset(TxD_reset),
        // .state(state),
        // .startTheSending(startTheSending),
        // .baud_clk(baud_clk)
        // // .extraCounter(extraCounter)
    );

    // Clock generation: 100 MHz (10 ns period)
    initial begin
        clk = 0;
        reset = 1;
        #50 reset = 0;

        forever #5 clk = ~clk;  // 100 MHz
    end

    // UART parameters
    localparam BAUD_RATE   = 115200;
    localparam BIT_PERIOD  = 1_000_000_000 / BAUD_RATE; // ~8680 ns

    // UART transmitter task (to drive RxD input)
    task uart_send_byte(input [7:0] data);
        integer i;
        begin
            // Start bit
            receiveData = 0;
            #(BIT_PERIOD);

            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                receiveData = data[i];
                #(BIT_PERIOD);
            end

            // Stop bit
            receiveData = 1;
            #(BIT_PERIOD);
            #100;
        end
    endtask

    // Stimulus
    initial begin
        // Idle line high initially
        receiveData = 1;
        #100000; // wait 100 us for reset/stabilization

        // Send UART frames (goes into RxD inside DUT)
        uart_send_byte(8'h55);  // 01010101
        uart_send_byte(8'hAA);  // 10101010
        uart_send_byte(8'h40);  // 00001111
        uart_send_byte(8'hF0);  // 11110000
        uart_send_byte(8'hAA);
        uart_send_byte(8'h90);
        uart_send_byte(8'h15);
        uart_send_byte(8'h44);
        uart_send_byte(8'h04);
        uart_send_byte(8'h44);
        uart_send_byte(8'h04);
        uart_send_byte(8'h44);
        uart_send_byte(8'h04);
        uart_send_byte(8'h44);
        uart_send_byte(8'h04);
        uart_send_byte(8'h44);
        uart_send_byte(8'h04);


        // wait for processing and TxD output
        #2000000;

        $finish;
    end

    // Dump VCD for GTKWave
    initial begin
        $dumpfile("tb_topModule.vcd");
        $dumpvars(0, tb_topModule);
    end

endmodule