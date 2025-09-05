// module division(
//     input [31:0] N,
//     input [7:0] D,
//     output reg [31:0] quo,rem,
//     input clk, rst,
//     output reg busy,done,
//     output reg [1:0] waiting,
//     output reg [32:0] A,A_prev,
//     output reg [7:0] M,
//     output reg [31:0] Q,
//     output reg [4:0] n
// );
//     always @(posedge(clk))begin
//         if(rst)begin
//             Q <= N;
//             M <= D;
//             A <= 33'd0;
//             A_prev <= 33'd0;
//             busy <= 1'b1;
//             n <= 5'd31;
//             waiting <= 2'b00;
//             done <= 1'b0;
//         end else if (busy) begin
//         if (waiting==2'b00) begin
//             A <= {A[31:0],Q[31]};
//             Q <= {Q[30:0],1'b1};
//             waiting <= 2'b01;
//         end if(waiting==2'b01) begin
//             A <= A-{25'd0,M};
//             A_prev <= A;
//             waiting <= 2'b10;
//         end if(waiting==2'b10) begin
//             if(A[32]==1'b1) begin
//                 Q[0] <= 1'b0;
//                 A <= A_prev;
//             end
//             n <= n-5'd1;
//             waiting <= 2'b11;
//         end if(waiting == 2'b11) begin
//             if(n==5'd0) begin
//                 quo <= Q;
//                 rem <= A;
//                 busy <= 1'b0;
//                 done <= 1'b1;
//             end else begin
//                 waiting <= 2'b00;
//             end
//         end
//         end
//     end
// endmodule

// module division #(parameter WIDTH=32) ( // width of numbers in bits
//     input wire logic clk,              // clock
//     input wire logic rst,              // reset
//     input wire logic start,            // start calculation
//     output     logic busy,             // calculation in progress
//     output     logic done,             // calculation is complete (high for one tick)
//     output     logic valid,            // result is valid
//     output     logic dbz,              // divide by zero
//     input wire logic [WIDTH-1:0] a,    // dividend (numerator)
//     input wire logic [WIDTH-1:0] b,    // divisor (denominator)
//     output     logic [WIDTH-1:0] val,  // result value: quotient
//     output     logic [WIDTH-1:0] rem   // result: remainder
//     );

//     logic [WIDTH-1:0] b1;             // copy of divisor
//     logic [WIDTH-1:0] quo, quo_next;  // intermediate quotient
//     logic [WIDTH:0] acc, acc_next;    // accumulator (1 bit wider)
//     logic [$clog2(WIDTH)-1:0] i;      // iteration counter

//     // division algorithm iteration
//     always @(*) begin
//         if (acc >= {1'b0, b1}) begin
//             acc_next = acc - b1;
//             {acc_next, quo_next} = {acc_next[WIDTH-1:0], quo, 1'b1};
//         end else begin
//             {acc_next, quo_next} = {acc, quo} << 1;
//         end
//     end

//     // calculation control
//     always @(posedge clk) begin
//         done <= 0;
//         if (start) begin
//             valid <= 0;
//             i <= 0;
//             if (b == 0) begin  // catch divide by zero
//                 busy <= 0;
//                 done <= 1;
//                 dbz <= 1;
//             end else begin
//                 busy <= 1;
//                 dbz <= 0;
//                 b1 <= b;
//                 {acc, quo} <= {{WIDTH{1'b0}}, a, 1'b0};  // initialize calculation
//             end
//         end else if (busy) begin
//             if (i == WIDTH-1) begin  // we're done
//                 busy <= 0;
//                 done <= 1;
//                 valid <= 1;
//                 val <= quo_next;
//                 rem <= acc_next[WIDTH:1];  // undo final shift
//             end else begin  // next iteration
//                 i <= i + 1;
//                 acc <= acc_next;
//                 quo <= quo_next;
//             end
//         end
//         if (rst) begin
//             busy <= 0;
//             done <= 0;
//             valid <= 0;
//             dbz <= 0;
//             val <= 0;
//             rem <= 0;
//         end
//     end
// endmodule

//FINALLY THIS WAS USED

// module division (
//     input clk,
//     input rst,
//     input [31:0] N,
//     input [31:0] D,
//     output reg [31:0] quo,
//     output reg busy, done
// );
//     reg [5:0] counter;
//     reg [63:0] d;
//     reg [63:0] r;
//     always @(posedge(clk)) begin
//         if(rst)begin
//             counter <= 6'd32;
//             r <= {32'd0,N};
//             d <= D<<32;//cehck rough nb
//             counter <= 6'd32;
//             done <= 1'b0;
//             busy <= 1'b1;
//             quo <= 0;
//         end
//         else begin
//             if (counter>0) begin
//                     if((r<<1) >= d) begin
//                         quo[counter-1] <= 1'b1;
//                         r <= (r<<1)-d;
//                     end else begin
//                         quo[counter-1] <= 1'b0;
//                         r <= (r<<1);
//                     end
//                     counter <= counter-1;
//             end else begin
//                 done <= 1;
//                 busy <= 0;
//             end
//         end
//     end
// endmodule
