`timescale 1ns/1ps

// -------------------------- UART Reciever Module -----------------------------------------
// INPUTS - clk, rst, rx - from LIDAR UART
// OUTPUTS - data (1 byte), data_valid (If data stored successfully) - To Distance processor

module RxD (
    input  wire       clk,
    input  wire       rx,       // asynchronous uart input (when idle, rx pulled high)
    input  wire       rst,      // reset
    output reg [7:0]  data,
    output reg        data_valid
);
    parameter CLK_FREQ = 100_000_000;           // clock frequency in Hz
    parameter BAUD     = 115200;
    localparam integer BAUD_TICKS = 868;        // clock cycles per bit
    localparam integer HALF_BAUD  = 434;        // Data mid sampling

    reg [15:0] counter = 0;                     // Counts baud ticks 
    reg [3:0]  bit_index = 0;                   // Counts indices dealt with
    reg [9:0]  shift_reg = 10'b1111111111;      // Empty reg (all high)
    reg [9:0]  next_shift;                      
    reg        receiving = 1'b0;                // rec status

    // Dual flip flop two stage synchronisation mechanism (async control)
    reg rx_ff1, rx_ff2; 
    wire rx_sync;
    always @(posedge clk) begin
        if (rst) begin
            rx_ff1 <= 1'b1;
            rx_ff2 <= 1'b1;
        end else begin
            rx_ff1 <= rx;
            rx_ff2 <= rx_ff1;
        end
    end
    assign rx_sync = rx_ff2;

    always @(posedge clk) begin
        if (rst) begin                          // Reset conditon
            receiving  <= 1'b0;
            counter    <= 0;
            bit_index  <= 0;
            shift_reg  <= 10'b1111111111;
            data       <= 8'h00;
            data_valid <= 1'b0;
        end else begin
            data_valid <= 1'b0;                 // No data currently 

            if (!receiving) begin               // Currently not recieveing data - fit to recieve new data
                if (rx_sync == 1'b0) begin
                    receiving <= 1'b1;          // Change status to recieving (won't trigger new data again)
                    counter   <= HALF_BAUD;     // sample start bit in middle (baud_ticks/2)
                    bit_index <= 0;             // first index = 0
                end
            end else begin                      // Currently recieving, so continue recieving
                if (counter == BAUD_TICKS - 1) begin    //  End of the baud time period 
                    counter <= 0;               // Reset counter

                    // Build the "next" shift register value
                    next_shift = {rx_sync, shift_reg[9:1]};

                    // Commit to shift_reg (non-blocking assignment)
                    shift_reg <= next_shift;

                    // If this is the last expected sample (start + 8 data + stop = 10 samples)
                    if (bit_index == 9) begin   // Last sample detected
                        receiving  <= 1'b0;
                        data       <= next_shift[8:1];      // unload latest sample into data
                        data_valid <= 1'b1;                 // Validate data             
                    end

                    bit_index <= bit_index + 1;     // Increment index
                end else begin
                    counter <= counter + 1;         // Increment counter
                end
            end
        end
    end

endmodule



// -------------------------- UART Transmitter Module -----------------------------------------
// INPUTS - clk, rst, send - From LIDAR and distance_process module
// OUTPUTS - tx - back to LIDAR
module TxD (
    input wire clk,
    input wire [7:0] data,
    input wire send,
    input wire rst,
    output reg tx,
    output reg busy
);
    // System Parameters
    parameter CLK_FREQ = 100000000; // 50 MHz
    parameter BAUD     = 115200;
    localparam integer BAUD_TICKS = 868;

    // Internal state registers
    reg [15:0] counter   = 0;
    reg [3:0]  bit_index = 0;
    reg [9:0]  shift_reg = 10'b1111111111;

    // This block now includes synchronous reset logic
    always @(posedge clk) begin
        if (rst) begin
            busy      <= 1'b0;                 
            tx        <= 1'b1;                 
            counter   <= 0;
            bit_index <= 0;
            shift_reg <= 10'b1111111111;
        end 
        else begin
            if (!busy) begin
                tx <= 1'b1; // Keep line high when idle
                if (send) begin
                    $display("TxD LOAD byte = 0x%02h at time %0t", data, $time);
                    // Load the UART frame: 1 stop bit, 8 data bits, 1 start bit.
                    shift_reg <= {1'b1, data, 1'b0}; 
                    busy      <= 1'b1;
                    counter   <= 0;
                    bit_index <= 0;
                end
            end 
            else begin 
                if (counter == BAUD_TICKS - 1) begin
                    counter   <= 0;
                    tx        <= shift_reg[0]; // Send the LSB of the shift register
                    shift_reg <= {1'b1, shift_reg[9:1]}; // Shift right to prepare the next bit
                    bit_index <= bit_index + 1;
                    
                    // After 10 bits (1 start, 8 data, 1 stop), the transmission is done.
                    if (bit_index == 9) begin
                        busy <= 1'b0; 
                    end
                end 
                else begin
                    counter <= counter + 1;
                end
            end
        end
    end
endmodule


// -------------------------- Data Parsing Module --------------------------------------------
// Meaningfully segments the bytes of raw data into different components
// INPUT - Raw data (in bytes) - from RxD
// OUTPUT - Header x2, CT x1, FSA x2, LSA x2, Sample_Value x2*CT (bytes) - to sample_processor

module data_parser (
    input  wire        clk,
    input  wire        rst,

    input  wire [7:0]  data_in,             // Input data
    input  wire        data_valid,          // If data_in is valid (complete)

    output reg  [7:0]  CT_out,              // Output data
    output reg [15:0]  FSA_out,
    output reg [15:0]  LSA_out,

    output reg         start_frame,         // Monitors if the particular data frame has been fully parsed
    output reg         frame_done,

    output reg         sample_valid,        // Validity of one particular distance sample
    output reg [15:0]  sample_value,        // The sample value itself
    output reg [15:0]  sample_idx          // Current index of the sample
    
);
    // States of execution the data parser (for each output data being processed)
    localparam S_HDR1      = 4'd0;          
    localparam S_HDR2      = 4'd1;
    localparam S_CT        = 4'd2;
    localparam S_FSA_LO    = 4'd3;
    localparam S_FSA_HI    = 4'd4;
    localparam S_LSA_LO    = 4'd5;
    localparam S_LSA_HI    = 4'd6;
    localparam S_SAMPLE_LO = 4'd7;
    localparam S_SAMPLE_HI = 4'd8;

    reg [3:0] state;                        // Stores the current state of the algorithm

    reg [7:0] sample_lo;                    // Buffer to store LSB section while MSB being processed

    reg [15:0] next_sample_idx;             // internal next sample counter

    // pipeline buffer for the completed sample (visible to consumer one cycle after assembly)
    reg [15:0] sample_value_buf;
    reg [15:0] sample_idx_buf;

    reg        sample_ready;         // set when buffer has a new sample (will be emitted next cycle)
    reg        frame_done_pending;   // set when last-sample was captured (emitted together with sample_valid)


    always @(posedge clk) begin
        if (rst) begin                      // Defining default states and values
            state            <= S_HDR1;
            CT_out           <= 8'd0;
            FSA_out          <= 16'd0;
            LSA_out          <= 16'd0;
            start_frame      <= 1'b0;
            sample_valid     <= 1'b0;
            sample_value     <= 16'd0;
            sample_idx       <= 16'd0;
            frame_done       <= 1'b0;
            sample_lo        <= 8'd0;
            next_sample_idx  <= 16'd0;
            sample_value_buf <= 16'd0;
            sample_idx_buf   <= 16'd0;
            sample_ready     <= 1'b0;
            frame_done_pending<=1'b0;
        end else begin                      // default: single-cycle pulses cleared unless set below
            start_frame  <= 1'b0;
            sample_valid <= 1'b0;
            frame_done   <= 1'b0;
            
            // If buffer was filled in the previous cycle, emit it now so consumer sees stable data.
            if (sample_ready) begin
                sample_valid <= 1'b1;
                sample_value <= sample_value_buf;
                sample_idx   <= sample_idx_buf;
                if (frame_done_pending) begin
                    frame_done <= 1'b1;
                end
                // clear the pending flags (they were emitted now)
                sample_ready      <= 1'b0;
                frame_done_pending<= 1'b0;
            end

            // The Finite State Machine
            case (state)
                // Checks for the header 1 signal (0x55) and moves on to header 2 state
                S_HDR1: if (data_valid && data_in == 8'h55) state <= S_HDR2;      

                // Checks for the header 2 signal (0xAA) and moves on
                S_HDR2: if (data_valid) begin                       
                    if (data_in == 8'hAA) state <= S_CT;
                    else if (data_in == 8'h55) state <= S_HDR2;     // Fail safe incase data was resent suddenly
                    else state <= S_HDR1;                           // Any other invalid data resets the state 
                end

                S_CT: if (data_valid) begin             // Parsing CT and starting the frame once headers verified
                    CT_out <= data_in;
                    start_frame <= 1'b1;
                    state <= S_FSA_LO;
                end

                S_FSA_LO: if (data_valid) begin         // Parsing first 8 bits of FSA
                    FSA_out[7:0] <= data_in;
                    state <= S_FSA_HI;
                end

                S_FSA_HI: if (data_valid) begin         // Parsing last 8 bits of FSA
                    FSA_out[15:8] <= data_in;
                    state <= S_LSA_LO;
                end

                S_LSA_LO: if (data_valid) begin         // Parsing first 8 bits of LSA
                    LSA_out[7:0] <= data_in;
                    state <= S_LSA_HI;
                end

                S_LSA_HI: if (data_valid) begin         // Parsing first 8 bits of FSA
                    LSA_out[15:8] <= data_in;
                    next_sample_idx <= 16'd0;           // Once the samples are ready to be started, set their index to 0 
                    state <= S_SAMPLE_LO;
                end

                S_SAMPLE_LO: if (data_valid) begin      // Stores first 8 bits into a buffer
                    sample_lo <= data_in;
                    state <= S_SAMPLE_HI;
                end

                S_SAMPLE_HI: if (data_valid) begin
                    sample_value_buf <= {data_in, sample_lo};       // Assembing the data sample and storing it along with the index
                    sample_idx_buf   <= next_sample_idx;
                    sample_ready     <= 1'b1;

                    
                    if (next_sample_idx + 1 == CT_out) begin        // if this is the last sample, mark pending frame_done and wrap index and state
                        frame_done_pending <= 1'b1;
                        next_sample_idx <= 16'd0;
                        state <= S_HDR1;
                    end else begin
                        next_sample_idx <= next_sample_idx + 1;     // Or else, simply increment the index and move back to SAMPLE_LO
                        state <= S_SAMPLE_LO;
                    end
                end

                default: state <= S_HDR1;                           // In case of any mismatch, default to the header state
            endcase
        end
    end
endmodule

// -------------------------- Sample Processing Module --------------------------------------------
// Processes the sampled data 
// INPUT - Header x2, CT x1, FSA x2, LSA x2, Sample_Value x2*CT (bytes) - from data_parser
// OUTPUT - Mininum and maximum distances, the corresponding indices and obs_alert - to the angle_calc_simple

module sample_processor (
    input  wire        clk,
    input  wire        rst,
    input  wire        start_frame,
    input  wire        sample_valid,
    input  wire [15:0] sample_value,
    input  wire [15:0] sample_idx_in,
    output reg  [15:0] max_idx,
    output reg  [15:0] min_idx,
    output reg  [15:0] max_dist,
    output reg  [15:0] min_dist,
    output reg  [15:0] obs_alert
);

    // Threshold 1024 (mm)
    reg [10:0] THRESH = 16'b10000000000;

    // Combinational helpers (mask and is_close)
    wire is_close = sample_value < THRESH;

    // Creates a masking consisting of all 1's till the sample_idx_in, and then all 0's
    wire [15:0] mask = (sample_idx_in < 16) ? (16'h1 << sample_idx_in) : 16'h0;

    always @(posedge clk) begin
        if (rst) begin                      // Reset 
            max_idx  <= 16'd0;
            min_idx  <= 16'd0;
            max_dist <= 16'd0;
            min_dist <= 16'hFFFF;
            obs_alert<= 16'd0;
        end else if (start_frame) begin
            max_idx  <= 16'd0;                      // also reset when a new frame starts
            min_idx  <= 16'd0;
            max_dist <= 16'd0;
            min_dist <= 16'hFFFF;
            obs_alert<= 16'd0;
        end else if (sample_valid) begin
            if (sample_value > max_dist) begin      // update max and min indices and distances
                max_dist <= sample_value;
                max_idx  <= sample_idx_in;
            end
            if (sample_value < min_dist) begin
                min_dist <= sample_value;
                min_idx  <= sample_idx_in;
            end

            // sticky or behavior: once set, the following bit remains set till the frame is done
            // Masking was done to expose the concerned bit 
            // mask is zero if sample_idx_in exceeds 16 anyways, so out-of-range indices are ignored.
            obs_alert <= obs_alert | (mask & {16{is_close}});
        end
    end
endmodule

// -------------------------- Angle Calculating Module --------------------------------------------
// Simple angle calculator for given CT (2^n forms ONLY)
// Modelling: angle(idx) = FSA + idx * ((LSA - FSA)/CT)  for idx = 0..CT-1
// Assumptions - FSA is the 1st angle, and LSA is the (CT+1)th angle - there are CT angle segments in between
// INPUT - FSA, LSA, CT, Mininum and maximum distances and the corresponding indices - from the sample_processor
// OUTPUT - Minimum and Maximum angles (or propely worded: angles corresponding to max and min distances)

module angle_calc_simple (
    input  wire        clk,
    input  wire        rst,        // reset
    input  wire        start,      // marks start of the process (one cycle pulse)
    input  wire [15:0] FSA,
    input  wire [15:0] LSA,
    input  wire [7:0]  CT,         
    input  wire [15:0] max_idx, 
    input  wire [15:0] min_idx,
    output reg  [15:0] max_angle,
    output reg  [15:0] min_angle,
    output reg         done        // marks end of process (one cycle pulse)
);

    // simple LUT for a log2 function (CT = 2^N, where N from 0 to 7)
    function [4:0] ct_log2;
        input [7:0] in_ct;
        begin
            case (in_ct)
                8'd1:   ct_log2 = 5'd0;
                8'd2:   ct_log2 = 5'd1;
                8'd4:   ct_log2 = 5'd2;
                8'd8:   ct_log2 = 5'd3;
                8'd16:  ct_log2 = 5'd4;
                8'd32:  ct_log2 = 5'd5;
                8'd64:  ct_log2 = 5'd6;
                8'd128: ct_log2 = 5'd7;
                default: ct_log2 = 5'd0;
            endcase
        end
    endfunction

    // latching inputs (so that the values are stable during computation)
    reg [15:0] FSA_r, LSA_r;
    reg [7:0]  CT_r;
    reg [15:0] max_idx_r, min_idx_r;
    reg [31:0] span_r;   // Assumed from 0 to 359.99
    reg [4:0]  k_r;      // log2(CT)
    reg        do_calc;  // flag off for calc

    wire [31:0] delta_w;
    // delta = span / CT - one particular segment of the angle
    // NOTE - for it to not throw an error, k = 0 if CT is NOT a power of two
    assign delta_w = (k_r == 5'd0) ? span_r : (span_r >> k_r);

    // angle range above FSA
    wire [47:0] prod_max_w = delta_w * max_idx_r;
    wire [47:0] prod_min_w = delta_w * min_idx_r;

    // Add to FSA (extra padding for hundreths places)
    wire [47:0] sum_max_w = prod_max_w + {32'd0, FSA_r};
    wire [47:0] sum_min_w = prod_min_w + {32'd0, FSA_r};

    // adjusting in case the angle wraps around 359.99 degrees
    wire [47:0] sum_max_adj_w = (sum_max_w >= 48'd36000) ? (sum_max_w - 48'd36000) : sum_max_w;
    wire [47:0] sum_min_adj_w = (sum_min_w >= 48'd36000) ? (sum_min_w - 48'd36000) : sum_min_w;

    always @(posedge clk) begin
        if (rst) begin                                  // reset
            FSA_r     <= 16'd0;
            LSA_r     <= 16'd0;
            CT_r      <= 8'd0;
            max_idx_r <= 16'd0;
            min_idx_r <= 16'd0;
            span_r    <= 32'd0;
            k_r       <= 5'd0;
            do_calc   <= 1'b0;
            max_angle <= 16'd0;
            min_angle <= 16'd0;
            done      <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start) begin                            // latch inputs
                FSA_r     <= FSA;
                LSA_r     <= LSA;
                CT_r      <= CT;
                max_idx_r <= max_idx;
                min_idx_r <= min_idx;

                if (LSA >= FSA) span_r <= LSA - FSA;    // compute span and wrap it around if more than
                else             span_r <= (LSA + 16'd36000) - FSA;

                k_r <= ct_log2(CT);
                do_calc <= 1'b1;
            end else if (do_calc) begin                 // output summed values truncated 
                max_angle <= sum_max_adj_w[15:0];
                min_angle <= sum_min_adj_w[15:0];

                done <= 1'b1;
                do_calc <= 1'b0;
            end
        end
    end
endmodule




// -------------------------- Distance Process Controller Module --------------------------------------------
// The entire controller module
// Integrator module of data_parser, sample_processer and sample processor
// Assumptions - FSA is the 1stangles (or propely worded: angles corresponding to max and min distances)
// INPUT - Raw data (in bytes) - from RxD
// OUTPUT - Minimum and Maximum angles and distances and obs_alert - to TxD
`timescale 1ns/1ps

module distance_process (
    input  wire        clk,
    input  wire        rst,
    input  wire [7:0]  data_in,
    input  wire        data_valid,

    output wire [15:0] max_idx,
    output wire [15:0] min_idx,
    output wire [15:0] max_dist,
    output wire [15:0] min_dist,
    output wire [15:0] obs_alert,
    output wire [15:0] max_angle,
    output wire [15:0] min_angle,
    output wire        angle_done
);

    // defining wires to connect all submodules together
    wire [7:0]  CT_w;
    wire [15:0] FSA_w, LSA_w;
    wire        start_frame_w;
    wire        sample_valid_w;
    wire [15:0] sample_value_w;
    wire [15:0] sample_idx_w;
    wire        frame_done_w;

    // instantiate data parser
    data_parser u_parser (
        .clk(clk),
        .rst(rst),
        .data_in(data_in),
        .data_valid(data_valid),
        .CT_out(CT_w),
        .FSA_out(FSA_w),
        .LSA_out(LSA_w),
        .start_frame(start_frame_w),
        .sample_valid(sample_valid_w),
        .sample_value(sample_value_w),
        .sample_idx(sample_idx_w),
        .frame_done(frame_done_w)
    );

    // instantiate sample processor
    sample_processor u_sp (
        .clk(clk),
        .rst(rst),
        .start_frame(start_frame_w),
        .sample_valid(sample_valid_w),
        .sample_value(sample_value_w),
        .sample_idx_in(sample_idx_w),
        .max_idx(max_idx),
        .min_idx(min_idx),
        .max_dist(max_dist),
        .min_dist(min_dist),
        .obs_alert(obs_alert)
    );

    // NOTE - the start wire of the angle calc pulses one cycle after the frame of the sample processor completes
    // Done so that sample_processor's registers which holds max_idx/min_idx have settled
    reg frame_done_d;
    reg angle_start_pulse;

    always @(posedge clk) begin
        if (rst) begin
            frame_done_d <= 1'b0;               // reset everything
            angle_start_pulse <= 1'b0;
        end else begin
            frame_done_d <= frame_done_w;       // angle_start_pulse pulses when previous cycle had its frame_done
            angle_start_pulse <= frame_done_d;
        end
    end

    // instantiate angle calculator
    angle_calc_simple u_angle (
        .clk(clk),
        .rst(rst),
        .start(angle_start_pulse),
        .FSA(FSA_w),
        .LSA(LSA_w),
        .CT(CT_w),
        .max_idx(max_idx),
        .min_idx(min_idx),
        .max_angle(max_angle),
        .min_angle(min_angle),
        .done(angle_done)
    );

endmodule



// -------------------------- LIDAR TOPMODULE --------------------------------------------
// The entire LIDAR top module
// Integrator module of RxD, TxD and the Controller
// INPUTS - clk, rst, rx - from LIDAR UART
// OUTPUTS - tx - back to LIDAR UART
`timescale 1ns/1ps
module lidar_system_top (
    input  wire clk,
    input  wire rst,
    input  wire rx,     // UART RX input (external)
    output wire tx,     // UART TX output (external)

    // debug wire outputs - to monitor all values at all given times
    output wire [15:0] dbg_max_idx,
    output wire [15:0] dbg_min_idx,
    output wire [15:0] dbg_max_dist,
    output wire [15:0] dbg_min_dist,
    output wire [15:0] dbg_obs_alert,
    output wire [15:0] dbg_max_angle,
    output wire [15:0] dbg_min_angle,
    output wire        dbg_angle_done
);

    // ----- UART RX -----
    wire [7:0] rx_data;
    wire       rx_valid;

    RxD u_rxd (
        .clk(clk),
        .rx(rx),
        .rst(rst),
        .data(rx_data),
        .data_valid(rx_valid)
    );

    // ----- Distance processing -----
    wire [15:0] max_idx, min_idx, max_dist, min_dist, obs_alert;
    wire [15:0] max_angle, min_angle;
    wire        angle_done;

    distance_process u_dp (
        .clk(clk),
        .rst(rst),
        .data_in(rx_data),
        .data_valid(rx_valid),
        .max_idx(max_idx),
        .min_idx(min_idx),
        .max_dist(max_dist),
        .min_dist(min_dist),
        .obs_alert(obs_alert),
        .max_angle(max_angle),
        .min_angle(min_angle),
        .angle_done(angle_done)
    );

    // ----- UART TX -----
    reg [7:0] tx_data;              // The byte of data up for transmission
    reg       tx_send;              // Tells the transmitter to load tx_data on the line
    wire      tx_busy;              // Pulled high when tx is busy transmitting a frame
    reg [31:0] tx_packet;           // Declaring a 4 byte packet from which to transmit - Max and Min angle

    TxD u_txd (
        .clk(clk),
        .rst(rst),
        .data(tx_data),
        .send(tx_send),
        .tx(tx),
        .busy(tx_busy)
    );

    // Declaring the Transmitter FSM states
    localparam TX_IDLE  = 3'd0; // When the line is idle
    localparam TX_PREP  = 3'd1; // prepare byte into tx_data
    localparam TX_SEND  = 3'd2; // assert send when tx_busy == 0
    localparam TX_WAIT  = 3'd3; // wait for tx_busy to finish (go back to 0)

    reg [2:0] tx_state;    // stores current state
    reg [1:0] byte_ptr;    // Which byte of the packet is being transmitted rn
    reg [15:0] send_word;  // Current 16 bit thing being sent

    // Delay the angle_done by one clock so angle outputs are stable (already talked about before)
    reg angle_done_d;
    always @(posedge clk) begin
        if (rst) angle_done_d <= 1'b0;
        else     angle_done_d <= angle_done;
    end

    // TX FSM: ensures tx_data is stable one cycle before asserting tx_send
    always @(posedge clk) begin
        if (rst) begin                          // reset
            tx_state   <= TX_IDLE;
            tx_send    <= 1'b0;
            tx_data    <= 8'd0;
            tx_packet  <= 32'd0;
            byte_ptr   <= 2'd0;
        end else begin
            // default: clear one-cycle send strobe
            tx_send <= 1'b0;

            case (tx_state)
                TX_IDLE: begin
                    // use edge-detected angle_done (angle_done_d is 1-cycle delayed)
                    if (angle_done_d) begin
                        // Loading the whole 4 byte packet
                        // store LSB then MSB order for max, then min
                        // tx_packet[7:0]   = max_lo
                        // tx_packet[15:8]  = max_hi
                        // tx_packet[23:16] = min_lo
                        // tx_packet[31:24] = min_hi
                        tx_packet <= { min_angle[15:8], min_angle[7:0], max_angle[15:8], max_angle[7:0] };
                        byte_ptr <= 2'd0;           // set to 0
                        tx_state <= TX_PREP;        // switch next state
                    end
                end

                TX_PREP: begin
                    // pick up the designated byte from the packet and load it in Tx
                    case (byte_ptr)                 
                        2'd0: tx_data <= tx_packet[7:0];    // max LSB
                        2'd1: tx_data <= tx_packet[15:8];   // max MSB
                        2'd2: tx_data <= tx_packet[23:16];  // min LSB
                        2'd3: tx_data <= tx_packet[31:24];  // min MSB
                        default: tx_data <= 8'h00;
                    endcase
                    tx_state <= TX_SEND;
                end

                TX_SEND: begin
                    if (!tx_busy) begin         // set the command to send once data has been loaded
                        tx_send <= 1'b1;
                        tx_state <= TX_WAIT;
                    end
                end

                TX_WAIT: begin                      // wait for transmitter to finish the byte (busy clears)
                    if (!tx_busy) begin
                        if (byte_ptr == 2'd3) begin // once finished all 4 bytes, reset for the next packed loading
                            byte_ptr <= 2'd0;
                            tx_state <= TX_IDLE;
                       end else begin               // if not done with it, move on
                            byte_ptr <= byte_ptr + 1'b1;
                            tx_state <= TX_PREP;
                        end
                    end
                end

                default: tx_state <= TX_IDLE;       // default to idle
            endcase
        end
    end


    // debug outputs
    assign dbg_max_idx   = max_idx;
    assign dbg_min_idx   = min_idx;
    assign dbg_max_dist  = max_dist;
    assign dbg_min_dist  = min_dist;
    assign dbg_obs_alert = obs_alert;
    assign dbg_max_angle = max_angle;
    assign dbg_min_angle = min_angle;
    assign dbg_angle_done = angle_done;

endmodule