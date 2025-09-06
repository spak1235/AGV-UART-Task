module reciever_header_tb;

    // Parameters
    localparam CLK_FREQ_HZ = 10000000;
    localparam BAUD_RATE = 115200;
    localparam CLKS_PER_BIT = 87;
    localparam BIT_PERIOD = CLKS_PER_BIT;

    reg tb_Clock;
    reg tb_Rx_Serial;
    reg reset;
    wire [7:0] tb_Rx_Byte_2;
    wire [15:0] tb_Rx_Byte_3;
    wire [15:0] tb_Rx_Byte_4;
    wire [15:0] obs_alert;
    wire [15:0] mad;
    wire [15:0] mia;
    wire data_validation;
    wire rx_dv;
    wire Tx;
    wire dv;
    wire [47:0] shift;
    wire [7:0] r_clock;
    // Instantiate UART RX
    rx_header dut (tb_Clock, tb_Rx_Serial, rx_dv, dv, tb_Rx_Byte_2, tb_Rx_Byte_3, tb_Rx_Byte_4);
    distanceProcess dis(tb_Clock, rx_dv, tb_Rx_Byte_2, tb_Rx_Byte_3, tb_Rx_Byte_4, data_validation, obs_alert, mad, mia);
    TxD tx(tb_Clock, reset, data_validation, mad, mia, obs_alert, Tx, shift, r_clock);

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
        reset = 1'b0;
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

    end

endmodule
