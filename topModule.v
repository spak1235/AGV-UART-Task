`timescale 1ns/1ps
module division (
    input clk,
    input rst,
    input [31:0] N,
    input [31:0] D,
    output reg [31:0] quo,
    output reg busy, done
);
    reg [5:0] counter;
    reg [63:0] d;
    reg [63:0] r;
    always @(posedge(clk)) begin
        if(rst)begin
            counter <= 6'd32;
            r <= {32'd0,N};
            d <= D<<32;//cehck rough nb
            counter <= 6'd32;
            done <= 1'b0;
            busy <= 1'b1;
            quo <= 0;
        end
        else begin
            if (counter>0) begin
                    if((r<<1) >= d) begin
                        quo[counter-1] <= 1'b1;
                        r <= (r<<1)-d;
                    end else begin
                        quo[counter-1] <= 1'b0;
                        r <= (r<<1);
                    end
                    counter <= counter-1;
            end else begin
                done <= 1;
                busy <= 0;
            end
        end
    end
endmodule

module distanceProcess (
    input [7:0] data,
    input clk,//processor clock
    input rst,
    input takeData, //takeData tells us if we should interpret the data or not.
    //takeData will go 1 for 1 clk cycle or sm
    //takeData will be used only when data variable is being used
    output reg [15:0] max_distance_angle, min_distance_angle, obs_alert,
    output reg sendData
);
     reg rst_state;
     reg [1:0] headCheck;
     reg [7:0] CT,counter2,headerA,headerB,temp;
     reg [15:0] FSA,LSA,obs_distance;
     reg [15:0] min_distance,max_distance,AtHand,min_distance_idx,max_distance_idx;
     reg [2:0] counter1; //counter1 is used during FSA,LSA and CT
     reg divider_reset;
     reg microCounter;//We will use this when interpreting data of 2N size
     reg [31:0] numerator_min,numerator_max;
     reg clkDelayer,hipHop,anotherClkDelayer;
     wire [31:0] quo_min,rem_min,quo_max,rem_max;
     wire busy_min,busy_max,division_done_min,division_done_max;
     reg [1:0] quo_rem_reg;
     wire divider_reset_wire;
    //Make a reset state, which assigns values to when it is ON
    //We will call reset once a signal is done processing to prepare for the next signal
    always @(posedge(clk) or posedge(rst) or posedge(rst_state)) begin
        if(rst|rst_state) begin
            headCheck <= 2'b00;
            headerA <= 8'h55;
            headerB <= 8'hAA;
            rst_state <= 1'b0;
            counter1 <= 3'b000;
            counter2 <= 8'h00;
            microCounter <= 1'b0;
            //clockCheck <= 1'b0;
            AtHand <= 16'h0000;
            obs_distance <= 16'h0080;
            max_distance <= 16'h0000;
            min_distance <= 16'hFFFF;
            obs_alert <= 16'h0000;
            sendData <= 1'b0;
            divider_reset<=1'b1;
            quo_rem_reg <= 2'b0;
            clkDelayer <= 1'b1;
            anotherClkDelayer <= 1'b1;
        end
    end
    //See if headCheck is 0
    always @(posedge(clk)) begin
        if(takeData) begin
        if(!(rst|rst_state)) begin
            if(!headCheck[0]) begin
                //Now we will check for header
                //If header is found then headCheck will become 11
                //ensure headCheck[1] is not non zero else we chopped
                if(!headCheck[1]) begin
                    if(data==headerA) begin
                        headCheck[0] <= 1'b1;
                    end
                end else begin
                    rst_state <= 1'b1;
                end
            end else begin
                if(!headCheck[1]) begin
                    //we have already established that headCheck[0] is 1, hence now we immediately check
                    //if data==headerB else we will immediately rst since signal was not good enough
                    if(data==headerB)begin
                        headCheck[1] <= 1'b1;
                    end else begin
                        rst_state <= 1'b1;
                    end
                end
            end
        end
        end
    end
    always @(posedge(clk)) begin
        if(headCheck[1]) begin
            //This is the next section of the code
            //This will run once headCheck is sorted
            //The next byte of data is CT
        if(takeData) begin
            if(counter1==3'b000)begin
                CT <= data;
                counter1 <= counter1+1;
            end else
            if(counter1==3'b001)begin
                temp <= data;
                counter1 <= counter1+1;
            end else
            if(counter1==3'b010)begin
                FSA <= {data,temp};//Is this little endian??
                counter1 <= counter1+1;
            end else
            if(counter1==3'b011)begin
                temp <= data;
                counter1 <= counter1+1;
            end else
            if(counter1==3'b100)begin
                LSA <= {data,temp};//Is this little endian??
                counter1 <= counter1+1;
            end
        end
        end
    end
    //Next we will move to the actual reading of distances
    always @(posedge clk) begin

        // if(takeData) begin
        // if((counter1==3'b101))begin
        //     //if(!clockCheck) begin
        //     if(counter2<CT)begin
        //         if(!microCounter) begin
        //             temp <= data;
        //             microCounter <= ~microCounter;
        //         end else begin
        //             AtHand <= {data,temp};//Is this little endian??
        //             if(AtHand!=16'h0000 & AtHand<min_distance)begin
        //                 min_distance <= AtHand;
        //                 min_distance_idx <= counter2;
        //                 counter2 <= counter2+1;
        //                 //We will use a division algorithm to actually find the values of these results
        //             end
        //             if(AtHand>max_distance)begin
        //                 max_distance <= AtHand;
        //                 max_distance_idx <= counter2;
        //                 counter2 <= counter2+1;
        //                 //We will use a division algorithm to actually find the values of these results
        //             end else if (AtHand!=16'h0000) begin
        //                 counter2 <= counter2+1;
        //             end
        //             if(AtHand!=16'h0000 & counter2<=4'hF)begin
        //                 if(AtHand<obs_distance)begin
        //                     obs_alert <= (obs_alert >> 1)|(16'h8000);
        //                 end else begin
        //                     obs_alert <= obs_alert >> 1;
        //                 end
        //             end
        //             microCounter <= ~microCounter;
        //         end
        //     end
        //     //end
        // end
        // end
        if(takeData) begin
        if(counter1==3'b101) begin
        if(counter2<CT)begin
            if(!microCounter) begin
                temp <= data;
                microCounter <= ~microCounter;
            end else begin
                AtHand <= {data,temp};
                hipHop <= 1'b1;//I HAVE NOT DECLRED THIS VAR YET
                //HipHop goes to 0 once processing is done
                microCounter <= ~microCounter;
            end
        end
        end
        end
        if (hipHop) begin
            hipHop <= 1'b0;
            //counter should go 1 only when we process the data to preserve the next few states
            if(AtHand!=16'h0000 & AtHand<min_distance)begin
                min_distance <= AtHand;
                min_distance_idx <= counter2;
                counter2 <= counter2+1;
                //We will use a division algorithm to actually find the values of these results
            end
            if(AtHand>max_distance)begin
                max_distance <= AtHand;
                max_distance_idx <= counter2;
                counter2 <= counter2+1;
                //We will use a division algorithm to actually find the values of these results
            end else if (AtHand!=16'h0000) begin
                counter2 <= counter2+1;
            end
            if(AtHand!=16'h0000 & counter2<=4'hF)begin
                if(AtHand<obs_distance)begin
                    obs_alert <= (obs_alert >> 1)|(16'h8000);
                end else begin
                    obs_alert <= obs_alert >> 1;
                end
            end
        end
    end
//the moment all data is read, we have about 64 cycles to compute everything. We will simultaneously find both min and max angle dist
//In the worst case, this operation will take 16 cycles (not cooked tho)
//Now that data input is done, we will reset needed counter variables, but we will be careful not to reset min_distance, max_distance
//and other such variables until absolutely required. Should we define a new reset module specifically for this task??
//Or we can send a reset signal again, make edits in the signal to not change these values, and only assign them sefaults right before when
//They are about to enter their functionality
//We can also introduce new registers if we want to and name them something like prev
//Right now there is no issue in continuing since (baud rate)/8 is low enough
assign divider_reset_wire = divider_reset;
division min_divider(
    .clk(clk),
    .rst(divider_reset_wire),
    .N(numerator_min),
    .D({24'd0,CT}-1),
    .quo(quo_min),
    .busy(busy_min),
    .done(division_done_min)
);
division max_divider(
    .clk(clk),
    .rst(divider_reset_wire),
    .N(numerator_max),
    .D({24'd0,CT}-1),
    .quo(quo_max),
    .busy(busy_max),
    .done(division_done_max)
);
always @(posedge(clk)) begin
        if (counter2==CT) begin
        if (clkDelayer) begin
            clkDelayer <= ~clkDelayer;
        end else if (anotherClkDelayer) begin
            numerator_min <= min_distance_idx*(LSA-FSA);
            numerator_max <= max_distance_idx*(LSA-FSA);
            anotherClkDelayer <= ~anotherClkDelayer;
        end else begin
        divider_reset <= 1'b0;
        if ((!divider_reset)&(division_done_max)&(division_done_min)&(quo_rem_reg==2'b00)) begin
            min_distance_angle <= FSA+quo_min;
            max_distance_angle <= FSA+quo_max;
            quo_rem_reg <= 2'b01;
        end if(quo_rem_reg==2'b01) begin
            min_distance_angle <= FSA+quo_min;
            max_distance_angle <= FSA+quo_max;
            quo_rem_reg <= 2'b11;
        end if(quo_rem_reg==2'b11) begin
            sendData <= 1'b1;
        end
        end
        end
    end
endmodule

module RxD (
    input  clk,
    input  reset,
    input  rx_pin,
    output reg [7:0] parallel_data,
    output reg byte_packed
);

    reg [2:0] rx_state; 
    reg [2:0] bit_counter;
    reg [6:0] baud_counter;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_state      <= 0;   // move to idle state
            bit_counter   <= 0;
            baud_counter  <= 0;
            parallel_data <= 0;
            byte_packed   <= 0;
        end else begin
            byte_packed <= 0;

            case(rx_state)
                // waiting for falling edge
                3'd0: begin
                    if (rx_pin == 0) begin
                        rx_state     <= 1;   // move to start state
                        baud_counter <= 0;
                    end
                end

                // start bit search
                3'd1: begin
                    baud_counter <= baud_counter + 1;
                    if (baud_counter == 43) begin
                        rx_state     <= 2;  // move to data read state
                        baud_counter <= 0;
                        bit_counter  <= 0;
                    end
                end

                // sample 8 bits
                3'd2: begin
                    baud_counter <= baud_counter + 1;

                    if (baud_counter == 43) begin
                        parallel_data[bit_counter] <= rx_pin;
                    end

                    if (baud_counter == 86) begin
                        baud_counter <= 0;
                        if (bit_counter == 7) begin
                            rx_state <= 3; // after last bit, move to stop state
                        end else begin
                            bit_counter <= bit_counter + 1;
                        end
                    end
                end

                // wait one bit time and then flag ready
                3'd3: begin
                    baud_counter <= baud_counter + 1;
                    if (baud_counter == 86) begin
                        rx_state     <= 0;   // back to IDLE
                        baud_counter <= 0;
                        byte_packed  <= 1;   // signal valid byte
                    end
                end
            endcase
        end
    end
endmodule

module TxD(
    input clk,
    input reset,
    input [7:0] byte_processed,
    input receiveData,
    output reg serial_output,
    output reg [3:0] bit_counter, //4 bit because of overflow error
    output reg baud_clk
);
    reg dataReady;
    reg [7:0]Data;
    reg [9:0] baud_counter;
    reg reset_internal;

    always@(posedge clk) begin
        if(receiveData) begin
            Data <= byte_processed; dataReady <= 1;
        end
    end

    always@(posedge clk or posedge reset or posedge reset_internal) begin
        if(reset | reset_internal) begin
            baud_counter<=0; baud_clk<=0;
        end
        if(baud_counter<434) begin
            baud_counter<= baud_counter+1;
        end

        if(baud_counter==434) begin
            baud_clk <= ~baud_clk;
            baud_counter <= 0;
        end
    end

    always @(posedge baud_clk or posedge reset or posedge reset_internal) begin
        if (reset | reset_internal) begin
            baud_counter <= 0;
            bit_counter <= 0;
            serial_output <= 1;
            dataReady <= 0;
            reset_internal<=0;
        end else begin
                if(dataReady==1 && bit_counter<=8) begin
                    //start bit
                    if(bit_counter==0) begin
                        serial_output <= 0;
                        bit_counter <= bit_counter + 1;
                    end
                    //1st bit
                    if(bit_counter==1) begin
                        serial_output <= Data[8-bit_counter];
                        bit_counter <= bit_counter + 1;
                    end
                    //2nd bit
                    else if(bit_counter==2) begin
                        serial_output <= Data[8-bit_counter];
                        bit_counter <= bit_counter + 1;
                    end
                    //3rd bit
                    else if(bit_counter==3) begin
                        serial_output <= Data[8-bit_counter];
                        bit_counter <= bit_counter + 1;
                    end
                    //4th bit
                    else if(bit_counter==4) begin
                        serial_output <= Data[8-bit_counter];
                        bit_counter <= bit_counter + 1;
                    end
                    //5th bit
                    else if(bit_counter==5) begin
                        serial_output <= Data[8-bit_counter];
                        bit_counter <= bit_counter + 1;
                    end
                    //6th bit
                    else if(bit_counter==6) begin
                        serial_output <= Data[8-bit_counter];
                        bit_counter <= bit_counter + 1;
                    end
                    //7th bit
                    else if(bit_counter==7) begin
                        serial_output <= Data[8-bit_counter];
                        bit_counter <= bit_counter + 1;
                    end
                    //8th bit
                    else if(bit_counter==8) begin
                        serial_output <= Data[8-bit_counter];
                        bit_counter <= bit_counter + 1;
                    end
                    else reset_internal<=1;
                end
                //idle state
                else begin
                    if (dataReady == 1) begin
                        bit_counter <= 0;
                        baud_counter <= 43;
                        serial_output <= 0;
                        dataReady <= 0;
                    end

                    else begin
                        serial_output <= 1;
                    end
                end
        end
    end
endmodule

module topModule(
    input wire receiveData,
    input wire clk,
    output wire transmitData
    // We don't think you will need any other inputs and outputs, but feel free to add what you want here, and mention it while submitting your code
);

    // Include your submodules for receiving, processing and transmitting your data here, we have included sample modules without any inputs and outputs for now
    RxD R0();
    distanceProcess D0();
    TxD T0();

endmodule
