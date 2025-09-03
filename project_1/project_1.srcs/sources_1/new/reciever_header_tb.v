module reciever_header_tb;

    // Parameters
    localparam CLK_FREQ_HZ = 10000000;        // 10 MHz system clock
    localparam BAUD_RATE   = 115200;          // UART baud rate
    localparam CLKS_PER_BIT = 87;             // Must match uart_rx parameter
    localparam BIT_PERIOD = CLKS_PER_BIT;     // Clock cycles per UART bit

    reg tb_Clock;
    reg tb_Rx_Serial;
    wire [7:0] tb_Rx_Byte_2;
    wire [15:0] tb_Rx_Byte_3;
    wire [15:0] tb_Rx_Byte_4;
    wire [15:0] obs_alert;
    wire [15:0] mad;
    wire [15:0] mia;
    wire data_validation;
    wire tick;
    wire Tx;
    wire dv;

    // Instantiate UART RX
    rx_header dut (tb_Clock, tb_Rx_Serial, dv, tb_Rx_Byte_2, tb_Rx_Byte_3, tb_Rx_Byte_4);
    distanceProcess dis(tb_Clock, tb_Rx_Byte_2, tb_Rx_Byte_3, tb_Rx_Byte_4, data_validation, obs_alert, mad, mid);
    baud_generator baud(tb_Clock, tick);
    TxD tx(tb_Clock, data_validation, tick, mda, mia, obs_alert, Tx);

    // Clock generation: 10 MHz
    initial tb_Clock = 0;
    always #50 tb_Clock = ~tb_Clock; // 100ns period for 10MHz

    // Task to send one UART byte (start bit + data bits + stop bit)
    task uart_send_byte;
        input [7:0] data;
        integer i;
        begin
            // Start bit (LOW)
            tb_Rx_Serial = 0;
            repeat(BIT_PERIOD) @(posedge tb_Clock);

            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                tb_Rx_Serial = data[i];
                repeat(BIT_PERIOD) @(posedge tb_Clock);
            end

            // Stop bit (HIGH)
            tb_Rx_Serial = 1;
            repeat(BIT_PERIOD) @(posedge tb_Clock);
        end
    endtask

    initial begin
        // Initialize input
        tb_Rx_Serial = 1;

        // Wait for reset
        repeat(10) @(posedge tb_Clock);

        // Send test bytes
        uart_send_byte(8'b01010101); // Test for pattern 0xAA
        repeat(9*BIT_PERIOD) @(posedge tb_Clock);

        uart_send_byte(8'b10101010); // Test for pattern 0x55
        repeat(10*BIT_PERIOD) @(posedge tb_Clock);

        uart_send_byte(8'b00000001); // Test for pattern 0x55
        repeat(10*BIT_PERIOD) @(posedge tb_Clock);

        uart_send_byte(8'b01101001); // Test for pattern 0x55
        repeat(10*BIT_PERIOD) @(posedge tb_Clock);

        uart_send_byte(8'b11111111); // Test for pattern 0x55
        repeat(10*BIT_PERIOD) @(posedge tb_Clock);
        
        uart_send_byte(8'b00110010); // Test for pattern 0x55
        repeat(10*BIT_PERIOD) @(posedge tb_Clock);

        uart_send_byte(8'b10110001); // Test for pattern 0x55
        repeat(10*BIT_PERIOD) @(posedge tb_Clock);
        
        uart_send_byte(8'b00001111); // Test for pattern 0x55
        repeat(10*BIT_PERIOD) @(posedge tb_Clock);

        uart_send_byte(8'b00110001); // Test for pattern 0x55
        repeat(10*BIT_PERIOD) @(posedge tb_Clock);

        // Finish simulation
        $finish;
    end

endmodule
