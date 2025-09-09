`include "timer.v"



module TxD ( 
  input wire clock,
  input wire reset,
  input wire [15:0] lidar_header, //Containing the LiDAR header (0x55 0xAA) = 16 bits
  input wire [47:0] data,     // Containing the processed data to be transmitted - contains 6 bytes for the 3 variables
  input wire flashin, // To enable transmission process
  output reg transmitData // output
);
  // Internal Registers:
  reg [15:0] headout;
  reg [47:0] regout;  // regout will contain the final message to be transmitted. it will contain 8 bytes = 64 bits
  reg [1:0] state;
  // 00 = idle
  // 01 = regout filling state
  // 10 = transmission mode state
  // 11 = transmission compelte state
  reg [6:0] count; // counter
  wire main_clk;
  reg enbclk; //To enable the main clock
  // Main Clock Instance
  main_clock mainclk (
    .clock(clock),
    .reset(reset),
    .enable(enbclk),
    .main_clk(main_clk)
  );

  always @(posedge clock or posedge reset) begin
    if(reset) begin //Reset
      regout <= 48'b0; 
      count <= 7'b1000000;
      state <= 2'b00;
      transmitData <= 1'b1;
      enbclk <= 1'b0;
    end
    else begin
    // For constructing or transmitting themessage 
      // Send the message via UART
      // For state
      case(state)
        2'b00 : begin
          count <= 7'b1000000;
          transmitData <= 1'b1;
          if(flashin) begin 
            state <= 2'b01;
          end
        end
        2'b01 : begin
          //regout[65] <= state[1]; //Start bit
          headout[15:0] <= lidar_header[15:0]; // Set Header to 0x55 0xAA
          regout[47:32] <= data[15:0]; // Get _obs(2 bytes)
          regout[15:0] <= data[47:32];  // Get min_distance_angle (2 bytes)
          regout[31:16] <= data[31:16]; // Get max (2 bytes)
          //regout[0] <= state[0]; //Stop bit
          state <= 2'b11;
          enbclk <= 1'b1;
        end
      endcase
    end
  end

  always @(posedge main_clk or posedge reset) begin
    if(!reset) begin
      case (state)
        2'b10 : begin
          // Give address 
          if(count > 7'b0110000) begin
            $display(headout[15]);
            transmitData <= headout[15]; //MSB first
            headout <= headout << 1; // shift regout left
            count <= count - 1;
          end
          else if(count > 0) begin
            transmitData <= regout[0]; //LSB first
            $display(regout[0]);
            regout <= regout >> 1; // shift regout right
            count <= count - 1;
          end
          else if (count == 0) begin
            //transmitData <= regout[0]; //LSB first
            //regout <= regout >> 1; // shift regout right
            state <= 2'b00;
          end
        end
        2'b11 : begin     
          count <= 7'b1000000;
          transmitData <= 1'b0; //Start bit
          //transmitData <= regout[63]; //MSB first
          //regout <= regout << 1; // shift regout left
          state <= 2'b10; 
        end
      endcase;
    end
  end
endmodule



/*
module TxD ( 
  input wire clock,
  input wire reset,
  input wire [15:0] lidar_header, //Containing the LiDAR header (0x55 0xAA) = 16 bits
  input wire [47:0] data,     // Containing the processed data to be transmitted - contains 6 bytes for the 3 variables
  input wire flashin, // To enable transmission process
  output reg transmitData // output
);
  // Internal Registers:
  reg [65:0] regout;  // regout will contain the final message to be transmitted. it will contain 8 bytes = 64 bits
  reg [1:0] state;
  // 00 = idle
  // 01 = regout filling state
  // 10 = transmission mode state
  // 11 = transmission compelte state
  reg [6:0] count; // counter
  wire main_clk;
  reg enbclk; //To enable the main clock
  // Main Clock Instance
  main_clock mainclk (
    .clock(clock),
    .reset(reset),
    .enable(enbclk),
    .main_clk(main_clk)
  );

  always @(posedge clock or posedge reset) begin
    if(reset) begin //Reset
      regout <= 64'b0; 
      count <= 7'b1000010;
      state <= 2'b00;
      transmitData <= 1'b1;
      enbclk <= 1'b0;
    end
    else begin
    // For constructing or transmitting themessage 
      // Send the message via UART
      // For state
      case(state)
        2'b00 : begin
          count <= 7'b1000010; 
          transmitData <= 1'b1;
          if(flashin) begin 
            state <= 2'b01;
          end
        end
        2'b01 : begin
          regout <= {1'b1,
            data[15:0], // Get obs_alert (2 bytes)
            data[47:32], // Get min_distance_angle (2 bytes)
            data[31:16], // Get max_distance_angle (2 bytes)
            lidar_header[15:8], // Set Header to 0x55 0xAA. This can also be written in an initial block
            lidar_header[7:0],
            1'b0
          };
          state <= 2'b10;
          enbclk <= 1'b1;
        end
      endcase
    end
  end

  always @(posedge main_clk or posedge reset) begin
    if(!reset) begin
      case (state)
        2'b10 : begin
            if(count > 0) begin
              transmitData <= regout[0]; //MSB first
              regout <= regout >> 1; // shift regout left
              count <= count - 1;
              $display(regout[0]);
            end
            else if (count==0) begin
              transmitData <= regout[0]; //MSB first
              regout <= regout >> 1; // shift regout left
              state <= 2'b11;
              $display(regout[0]);
            end
          end
          2'b11 : begin
              enbclk <= 1'b0;
            state <= 2'b10;
          end
      endcase;
    end
  end
endmodule
*/