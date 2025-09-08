`timescale 1ns/1ps

module tb_lidar_system;
    // parameters
    localparam CLK_FREQ = 100_000_000; // Hz
    localparam BAUD     = 115200;
    localparam integer CLK_PERIOD_NS = 1000000000 / CLK_FREQ; // 10 ns
    localparam integer BAUD_TICKS = CLK_FREQ / BAUD;           // ~868
    localparam integer BIT_PERIOD_NS = BAUD_TICKS * CLK_PERIOD_NS; // ~8680 ns

    // Timeout settings (in clock cycles)
    localparam integer MAX_WAIT_CYCLES = 1_000_000; // generous timeout

    // DUT interface signals
    reg clk;
    reg rst;
    reg rx;               // input to DUT (driven by TB)
    wire tx;              // DUT output (we sample)
    wire [15:0] dbg_max_idx, dbg_min_idx, dbg_max_dist, dbg_min_dist, dbg_obs_alert, dbg_max_angle, dbg_min_angle;
    wire dbg_angle_done;
    
    // Sticky flag to capture the single-cycle angle_done pulse
    reg angle_done_seen;

    // helper test variables (module-scope)
    integer test_no;
    integer i, j, wait_cycles;
    reg [7:0] got_lo, got_hi;
    reg [15:0] got_angle;
    
    // Testbench variables to hold expected values
    reg [15:0] exp_max_idx;
    reg [15:0] exp_min_idx;
    reg [15:0] exp_max_dist;
    reg [15:0] exp_min_dist;
    reg [15:0] exp_obs;
    reg [7:0]  rb;

    // instantiate DUT
    lidar_system_top dut (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .tx(tx),
        .dbg_max_idx(dbg_max_idx),
        .dbg_min_idx(dbg_min_idx),
        .dbg_max_dist(dbg_max_dist),
        .dbg_min_dist(dbg_min_dist),
        .dbg_obs_alert(dbg_obs_alert),
        .dbg_max_angle(dbg_max_angle),
        .dbg_min_angle(dbg_min_angle),
        .dbg_angle_done(dbg_angle_done)
    );

    // clock generator: 100 MHz
    initial begin
        clk = 0;
        forever #(CLK_PERIOD_NS/2) clk = ~clk;
    end

    // sample buffer
    reg [15:0] samples [0:31];

    // helper: send UART byte (LSB first) on rx line, aligned to the DUT clock
    task uart_send_byte(input [7:0] b);
        integer k;
        begin
            @(posedge clk);
            rx = 1'b0;
            #(BIT_PERIOD_NS);
            for (k = 0; k < 8; k = k + 1) begin
                rx = b[k];
                #(BIT_PERIOD_NS);
            end
            rx = 1'b1;
            #(BIT_PERIOD_NS);
            #(BIT_PERIOD_NS/4);
        end
    endtask

    // send a full LiDAR frame (CT, FSA, LSA, samples)
    task send_lidar_frame(input integer CT, input [15:0] FSA, input [15:0] LSA);
        integer idx;
        begin
            $display("TB: sending frame CT=%0d FSA=%0d LSA=%0d", CT, FSA, LSA);
            uart_send_byte(8'h55);
            uart_send_byte(8'hAA);
            uart_send_byte(CT[7:0]);
            uart_send_byte(FSA[7:0]); uart_send_byte(FSA[15:8]);
            uart_send_byte(LSA[7:0]); uart_send_byte(LSA[15:8]);
            for (idx = 0; idx < CT; idx = idx + 1) begin
                uart_send_byte(samples[idx][7:0]);
                uart_send_byte(samples[idx][15:8]);
            end
            $display("TB: frame sent (CT=%0d)", CT);
        end
    endtask

    // receive a byte from DUT's tx with timeout (in clock cycles)
    task uart_recv_byte(output [7:0] b, input integer timeout_cycles);
        integer waited;
        integer k;
        begin
            b = 8'h00;
            waited = 0;
            // Wait for start bit
            while (tx !== 1'b0 && waited < timeout_cycles) begin
                @(posedge clk);
                waited = waited + 1;
            end
            if (waited >= timeout_cycles) begin
                $display("TB ERROR: timeout waiting for TX start bit");
                b = 8'hxx;
                disable uart_recv_byte;
            end
            // sample middle of first bit
            #(BIT_PERIOD_NS/2);
            for (k = 0; k < 8; k = k + 1) begin
                #(BIT_PERIOD_NS);
                b[k] = tx;
            end
            // allow stop bit interval
            #(BIT_PERIOD_NS);
        end
    endtask
    
    // Wait for start of next transmitted byte on tx (synchronised to clk)
    task wait_for_tx_start;
        begin
            // sync to clock, then wait for tx to be idle (high)
            @(posedge clk);
            while (tx === 1'b0) @(posedge clk);  // wait until line goes idle (if it isn't)
            // now wait for the next start-bit (falling edge)
            @(negedge tx);
        end
    endtask

    // compute expected angle given CT and index
    function [15:0] expected_angle;
        input [15:0] FSA;
        input [15:0] LSA;
        input integer CT;
        input integer idx;
        integer span;
        integer delta;
        begin
            if (LSA >= FSA) span = LSA - FSA;
            else span = (LSA + 36000) - FSA;
            delta = span / CT;
            expected_angle = FSA + idx * delta;
        end
    endfunction

    // helper to compute expected max/min and obs mask from samples[]
    task compute_expectations(input integer CT);
        integer k;
        begin
            exp_max_idx = 0;
            exp_min_idx = 0;
            exp_max_dist = 0;
            exp_min_dist = 16'hFFFF;
            exp_obs = 16'h0000;
            for (k = 0; k < CT; k = k + 1) begin
                if (samples[k] > exp_max_dist) begin
                    exp_max_dist = samples[k];
                    exp_max_idx = k;
                end
                if (samples[k] < exp_min_dist) begin
                    exp_min_dist = samples[k];
                    exp_min_idx = k;
                end
                if (k < 16) begin
                    if (samples[k] < 16'd1024) exp_obs[k] = 1'b1;
                end
            end
        end
    endtask

    // Monitor for the single-cycle angle_done pulse and latch it.
    reg dbg_angle_done_d;
    always @(posedge clk) begin
        dbg_angle_done_d <= dbg_angle_done;
        if (dbg_angle_done && !dbg_angle_done_d) begin
            angle_done_seen <= 1'b1;
            $display("DUT: angle_done asserted at %0t -> max_idx=%0d max_dist=%0d  min_idx=%0d min_dist=%0d obs=0x%04h",
                $time, dbg_max_idx, dbg_max_dist, dbg_min_idx, dbg_min_dist, dbg_obs_alert);
        end
    end

    // Also print every few ms a heartbeat so long sims are visible
    initial begin
        forever begin
            #(BIT_PERIOD_NS * 1000);
            $display("TB heartbeat at time %0t", $time);
        end
    end

    // main test sequence
    initial begin
        $dumpfile("tb_lidar_system.vcd");
        $dumpvars(0, tb_lidar_system);

        // init
        rst = 1;
        rx  = 1'b1; // uart idle high
        #(BIT_PERIOD_NS * 6);

        // release reset
        @(posedge clk);
        rst = 0;
        repeat (200) @(posedge clk); // warm-up

        // ------ TEST A: CT=8 baseline ------
        test_no = 1;
        $display("\nTEST %0d: CT=8", test_no);
        samples[0] = 16'd1000;
        samples[1] = 16'd700;
        samples[2] = 16'd1400;
        samples[3] = 16'd1200; // expected max idx 3
        samples[4] = 16'd800;
        samples[5] = 16'd500;  // expected min idx 5
        samples[6] = 16'd1100;
        samples[7] = 16'd900;

        $display("TB: samples (CT=8):");
        for (i = 0; i < 8; i = i + 1) $display("  sample[%0d] = %0d", i, samples[i]);
        compute_expectations(8);
        $display("TB expect: max_idx=%0d max_dist=%0d  min_idx=%0d min_dist=%0d obs=0x%04h",
                 exp_max_idx, exp_max_dist, exp_min_idx, exp_min_dist, exp_obs);

        angle_done_seen = 1'b0; // Clear the sticky flag
        send_lidar_frame(8, 16'd1000, 16'd2600);

        wait_cycles = 0;
        while (!angle_done_seen && wait_cycles < MAX_WAIT_CYCLES) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
        end
        if (wait_cycles >= MAX_WAIT_CYCLES) begin
            $display("TIMEOUT waiting for angle_done (test %0d). Dumping debug and aborting.", test_no);
            $display("DUT debug: max_idx=%0d min_idx=%0d max_dist=%0d min_dist=%0d obs=0x%04h",
                     dbg_max_idx, dbg_min_idx, dbg_max_dist, dbg_min_dist, dbg_obs_alert);
            $finish;
        end
        $display("TB: angle_done observed after %0d cycles", wait_cycles);

        wait_for_tx_start();
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_lo = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_hi = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        got_angle = {got_hi, got_lo};
        $display("TX returned max_angle = %0d (expected %0d)", got_angle, expected_angle(1000,2600,8,exp_max_idx));

        wait_for_tx_start();
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_lo = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_hi = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        got_angle = {got_hi, got_lo};
        $display("TX returned min_angle = %0d (expected %0d)", got_angle, expected_angle(1000,2600,8,exp_min_idx));
        
        $display("DUT reported angles: max_angle=%0d min_angle=%0d", dbg_max_angle, dbg_min_angle);
        $display("DUT reported obs_mask = 0x%04h (expected 0x%04h)", dbg_obs_alert, exp_obs);

        #(BIT_PERIOD_NS * 8);

        // ------ TEST B: CT=4 wrap-around ------
        test_no = 2;
        $display("\nTEST %0d: CT=4", test_no);
        samples[0] = 16'd800;
        samples[1] = 16'd900;
        samples[2] = 16'd1200; // max idx 2
        samples[3] = 16'd1000;
        for (i = 0; i < 4; i = i + 1) $display("  sample[%0d]=%0d", i, samples[i]);
        compute_expectations(4);
        $display("TB expect: max_idx=%0d max_dist=%0d  min_idx=%0d min_dist=%0d obs=0x%04h",
                 exp_max_idx, exp_max_dist, exp_min_idx, exp_min_dist, exp_obs);

        angle_done_seen = 1'b0; // Clear the sticky flag
        send_lidar_frame(4, 16'd35000, 16'd100);

        wait_cycles = 0;
        while (!angle_done_seen && wait_cycles < MAX_WAIT_CYCLES) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
        end
        if (wait_cycles >= MAX_WAIT_CYCLES) begin
            $display("TIMEOUT waiting for angle_done (test %0d). Dumping debug and aborting.", test_no);
            $display("DUT debug: max_idx=%0d min_idx=%0d max_dist=%0d min_dist=%0d obs=0x%04h",
                     dbg_max_idx, dbg_min_idx, dbg_max_dist, dbg_min_dist, dbg_obs_alert);
            $finish;
        end

        wait_for_tx_start();
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_lo = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_hi = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        got_angle = {got_hi, got_lo};
        $display("TX returned max_angle = %0d (expected %0d)", got_angle, expected_angle(35000,100,4,exp_max_idx));

        wait_for_tx_start();
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_lo = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_hi = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        got_angle = {got_hi, got_lo};
        $display("TX returned min_angle = %0d (expected %0d)", got_angle, expected_angle(35000,100,4,exp_min_idx));

        $display("DUT reported angles: max_angle=%0d min_angle=%0d", dbg_max_angle, dbg_min_angle);
        $display("DUT reported obs_mask = 0x%04h (expected 0x%04h)", dbg_obs_alert, exp_obs);

        #(BIT_PERIOD_NS * 8);

        // ------ TEST C: CT=1 single sample ------
        test_no = 3;
        $display("\nTEST %0d: CT=1", test_no);
        samples[0] = 16'd300;
        $display("  sample[0]=%0d", samples[0]);
        compute_expectations(1);
        $display("TB expect: max_idx=%0d max_dist=%0d  min_idx=%0d min_dist=%0d obs=0x%04h",
                 exp_max_idx, exp_max_dist, exp_min_idx, exp_min_dist, exp_obs);

        angle_done_seen = 1'b0;
        send_lidar_frame(1, 16'd0, 16'd35999);

        wait_cycles = 0;
        while (!angle_done_seen && wait_cycles < MAX_WAIT_CYCLES) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
        end
        if (wait_cycles >= MAX_WAIT_CYCLES) begin
            $display("TIMEOUT waiting for angle_done (test %0d). Dumping debug and aborting.", test_no);
            $display("DUT debug: max_idx=%0d min_idx=%0d max_dist=%0d min_dist=%0d obs=0x%04h",
                     dbg_max_idx, dbg_min_idx, dbg_max_dist, dbg_min_dist, dbg_obs_alert);
            $finish;
        end

        wait_for_tx_start();
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_lo = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_hi = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        got_angle = {got_hi, got_lo};
        $display("TX returned max_angle = %0d (expected %0d)", got_angle, expected_angle(0,35999,1,exp_max_idx));
        wait_for_tx_start();
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_lo = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_hi = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        got_angle = {got_hi, got_lo};
        $display("TX returned min_angle = %0d (expected %0d)", got_angle, expected_angle(0,35999,1,exp_min_idx));
        $display("DUT reported obs_mask = 0x%04h (expected 0x%04h)", dbg_obs_alert, exp_obs);

        #(BIT_PERIOD_NS * 8);

        // ------ TEST D: CT=16 (bigger) ------
        test_no = 4;
        $display("\nTEST %0d: CT=16", test_no);
        for (i = 0; i < 16; i = i + 1) samples[i] = 16'd600;
        samples[0] = 16'd1100;
        samples[1] = 16'd400;
        samples[2] = 16'd600;
        samples[3] = 16'd1300;
        samples[4] = 16'd400;   // close => obs bit 2
        samples[5] = 16'd200;
        samples[6] = 16'd1100;   // close => obs bit 5
        samples[7] = 16'd1400;
        samples[8] = 16'd400;
        samples[9] = 16'd1500;
        samples[10] = 16'd1600;
        samples[11] = 16'd400;
        samples[12] = 16'd300;
        samples[13] = 16'd200;
        samples[14] = 16'd1200;  // max idx 7
        samples[15] = 16'd100;  // min idx 15
        for (i = 0; i < 16; i = i + 1) $display("  sample[%0d]=%0d", i, samples[i]);
        compute_expectations(16);
        $display("TB expect: max_idx=%0d max_dist=%0d  min_idx=%0d min_dist=%0d obs=0x%04h",
                 exp_max_idx, exp_max_dist, exp_min_idx, exp_min_dist, exp_obs);

        angle_done_seen = 1'b0;
        send_lidar_frame(16, 16'd0, 16'd1600);

        wait_cycles = 0;
        while (!angle_done_seen && wait_cycles < MAX_WAIT_CYCLES) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
        end
        if (wait_cycles >= MAX_WAIT_CYCLES) begin
            $display("TIMEOUT waiting for angle_done (test %0d). Dumping debug and aborting.", test_no);
            $display("DUT debug: max_idx=%0d min_idx=%0d max_dist=%0d min_dist=%0d obs=0x%04h",
                     dbg_max_idx, dbg_min_idx, dbg_max_dist, dbg_min_dist, dbg_obs_alert);
            $finish;
        end

        wait_for_tx_start();
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_lo = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_hi = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        got_angle = {got_hi, got_lo};
        $display("TX returned max_angle = %0d (expected %0d)", got_angle, expected_angle(0,1600,16,exp_max_idx));
        wait_for_tx_start();
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_lo = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_hi = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        got_angle = {got_hi, got_lo};
        $display("TX returned min_angle = %0d (expected %0d)", got_angle, expected_angle(0,1600,16,exp_min_idx));

        $display("DUT reported obs_mask = 0x%04h (expected 0x%04h)", dbg_obs_alert, exp_obs);

        #(BIT_PERIOD_NS * 8);

        // ------ TEST E: CT=2 small ------
        test_no = 5;
        $display("\nTEST %0d: CT=2", test_no);
        samples[0] = 16'd600;
        samples[1] = 16'd1200; // min idx 1
        for (i = 0; i < 2; i = i + 1) $display("  sample[%0d]=%0d", i, samples[i]);
        compute_expectations(2);
        $display("TB expect: max_idx=%0d max_dist=%0d  min_idx=%0d min_dist=%0d obs=0x%04h",
                 exp_max_idx, exp_max_dist, exp_min_idx, exp_min_dist, exp_obs);

        angle_done_seen = 1'b0;
        send_lidar_frame(2, 16'd100, 16'd200);

        wait_cycles = 0;
        while (!angle_done_seen && wait_cycles < MAX_WAIT_CYCLES) begin
            @(posedge clk);
            wait_cycles = wait_cycles + 1;
        end
        if (wait_cycles >= MAX_WAIT_CYCLES) begin
            $display("TIMEOUT waiting for angle_done (test %0d). Dumping debug and aborting.", test_no);
            $display("DUT debug: max_idx=%0d min_idx=%0d max_dist=%0d min_dist=%0d obs=0x%04h",
                     dbg_max_idx, dbg_min_idx, dbg_max_dist, dbg_min_dist, dbg_obs_alert);
            $finish;
        end
        
        wait_for_tx_start();

        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_lo = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_hi = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        got_angle = {got_hi, got_lo};
        $display("TX returned max_angle = %0d (expected %0d)", got_angle, expected_angle(100,200,2,exp_max_idx));
        wait_for_tx_start();
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_lo = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        uart_recv_byte(rb, MAX_WAIT_CYCLES); got_hi = rb;
        $display("TB RX raw byte = 0x%02h at time %0t", rb, $time);
        got_angle = {got_hi, got_lo};
        $display("TX returned min_angle = %0d (expected %0d)", got_angle, expected_angle(100,200,2,exp_min_idx));
        $display("DUT reported obs_mask = 0x%04h (expected 0x%04h)", dbg_obs_alert, exp_obs);
        $display("\nALL TESTS DONE (verbose). Finishing.");
        #1000;
        $finish;
    end
endmodule