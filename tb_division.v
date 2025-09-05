`timescale 1ns/1ps

module tb_division();
//iverilog -o division_tb tb_division.v division.v
//vvp division_tb
//gtkwave division_tb.vcd

    // DUT signals
    reg clk;
    reg rst;
    reg [31:0] N, D;
    wire [31:0] quo, rem;
    wire busy, done;
    wire [5:0] counter;
    wire [63:0] d,r;

    // Instantiate DUT
    division uut (
        .clk(clk),
        .rst(rst),
        .N(N),
        .D(D),
        .quo(quo),
        .rem(rem),
        .busy(busy),
        .done(done),
        .counter(counter),
        .d(d),
        .r(r)
    );

    // Clock generation (100MHz, period=10ns)
    initial clk = 0;
    always #5 clk = ~clk;

    // Task to run one division test
    task run_test(input [31:0] num, input [31:0] den);
        reg [31:0] exp_quo, exp_rem;
        begin
            @(negedge clk);
            N   = num;
            D   = den;
            rst = 1;
            @(negedge clk);
            rst = 0;

            // Wait until done
            wait(done == 1);

            exp_quo = num / den;
            exp_rem = num % den;

            $display("--------------------------------------------------");
            $display("N=0x%08h, D=0x%08h", num, den);
            $display("Hardware : Quo=%d (0x%08h), Rem=%d (0x%08h)", 
                      quo, quo, rem, rem);
            $display("Expected : Quo=%d (0x%08h), Rem=%d (0x%08h)", 
                      exp_quo, exp_quo, exp_rem, exp_rem);
            $display("Counter final=%0d, d=0x%h", counter, d);

            if (quo !== exp_quo || rem !== exp_rem) begin
                $display("❌ MISMATCH!");
            end else begin
                $display("✅ PASS");
            end
        end
    endtask

    // Stimulus
    initial begin
        // VCD dump for GTKWave
        $dumpfile("division_tb.vcd");
        $dumpvars(0, tb_division);

        // init
        N=0; D=0; rst=0;
        #20;

        // Run test cases
        run_test(100, 7);
        run_test(12345, 123);
        run_test(32'hFFFF_FFFF, 255);
        run_test(500, 10);
        run_test(1000, 3);

        // Requested hex test cases
        run_test(32'h00000120, 32'h00000007); // 288 / 7
        run_test(32'h000002D0, 32'h00000007); // 720 / 7

        #100;
        $finish;
    end

endmodule
