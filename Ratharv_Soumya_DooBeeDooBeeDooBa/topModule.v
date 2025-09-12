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
    output reg sendData,
    // tb checking
    output reg [1:0] headCheck,
    output reg [7:0] CT,
    output reg [15:0] FSA,LSA,
    output reg [2:0] counter1,
    output reg [7:0] counter2,
    output reg [15:0] min_distance,max_distance,AtHand,min_distance_idx,max_distance_idx,
    output reg [2:0] quo_rem_reg
);
     reg rst_state;
     
     reg [7:0] headerA,headerB,temp;
     reg [15:0] obs_distance;
     
      //counter1 is used during FSA,LSA and CT
     reg divider_reset;
     reg microCounter;//We will use this when interpreting data of 2N size
     reg [31:0] numerator_min,numerator_max;
     reg clkDelayer,hipHop,anotherClkDelayer;
     wire [31:0] quo_min,rem_min,quo_max,rem_max;
     wire busy_min,busy_max,division_done_min,division_done_max;
     wire divider_reset_wire;
     reg sendDataReg;
    //Make a reset state, which assigns values to when it is ON
    //We will call reset once a signal is done processing to prepare for the next signal
    always @(posedge(clk) or posedge(rst) or posedge(rst_state)) begin
        if(rst|rst_state) begin
            headCheck <= 2'b00;
            headerA <= 8'hAA;
            headerB <= 8'h55;
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
            quo_rem_reg <= 3'b000;
            clkDelayer <= 1'b1;
            anotherClkDelayer <= 1'b1;
        end
        if(rst) begin
            sendDataReg <= 1'b0;
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
        if ((!divider_reset)&(division_done_max)&(division_done_min)&(quo_rem_reg==3'b000)) begin
            min_distance_angle <= FSA+quo_min;
            max_distance_angle <= FSA+quo_max;
            quo_rem_reg <= 3'b001;
        end if(quo_rem_reg==3'b001) begin
            min_distance_angle <= FSA+quo_min;
            max_distance_angle <= FSA+quo_max;
            quo_rem_reg <= 3'b011;
        end if(quo_rem_reg==3'b011) begin
            sendData <= 1'b1;
            quo_rem_reg <= 3'b100;
        end if(quo_rem_reg==3'b100) begin
            sendData <= 1'b0;
        end
        end
        end
    end
endmodule

module RxD (
    input  clk,
    input  reset,
    input  serial_input,
    output reg [7:0] parallel_data,
    output reg byte_packed,
    output reg state,
    output reg [3:0] bit_counter
);
    //once done processing 1 surge of reset_internal
    reg [8:0] baud_counter;
    reg startBaud;
    reg reset_internal;
    reg baud_clk;
    reg delayOneMomentPliz;

    always@(posedge clk) begin
    if(startBaud) begin
    if(baud_counter<434) begin
        baud_counter<= baud_counter+1;
    end

    if(baud_counter==434) begin
        baud_clk <= ~baud_clk;
        baud_counter <= 0;
    end
    end
    end
    always @(posedge(clk) or posedge(reset) or posedge(reset_internal)) begin
        if(reset | reset_internal) begin
            startBaud <= 0;
            baud_counter <= 0;
            state <= 0;
            reset_internal <= 0;
            baud_clk <= 0;
            parallel_data <= 8'd0;
            bit_counter <= 0;
            byte_packed <= 0;
            delayOneMomentPliz <= 0;

        end
    end
    always @(posedge clk) begin
        case(state)
        0: begin
            //represents idle
            if(serial_input == 0) begin
            startBaud <= 1;
            end
        end
        1: begin
            if(bit_counter==8) begin
                byte_packed <= 1;
                delayOneMomentPliz <= 1;
            end
        end
        endcase
    end
    always @(posedge baud_clk) begin
        case(state)
        0: begin
            //represents idle
            if(serial_input == 0) begin
                state <= 1;
            end
        end
        1: begin
            if(bit_counter<8) begin
            parallel_data[7-bit_counter] <= serial_input;
            bit_counter <= bit_counter+1;
            end
        end
        endcase
    end
    always @(posedge baud_clk) begin
        if(delayOneMomentPliz) begin
            reset_internal <= 1;
        end
    end
    //To be or not to be, that is the question
    //To do is to be
    //To be is to do
    //Doo Bee Doo Bee Doo Ba
endmodule

module TxD(
    input clk,
    input reset,
    input [7:0] byte_processed,
    input receiveData,
    input baud_clk,
    output reg serial_output,
    output reg sending_done,
    output reg busy,
    output reg [1:0] state,
    output reg startTheSending
);
    reg reset_internal;
    reg [3:0] bit_counter;
    //we have baud, but some things must be done on clk

    always@(posedge(clk) or posedge(reset) or posedge(reset_internal)) begin
        if(reset | reset_internal) begin
            serial_output <= 1'b1;
            bit_counter <= 4'b0000;
            sending_done <= 1'b0;
            busy <= 1'b0;
            state <= 2'b00;
        end
    end
    //no need to store Data anymore since we have controlToTxD now
    always@(posedge(baud_clk)) begin
        //only related to data sending
        //also state is updated here
        case (state)
            2'd0: begin
                serial_output <= 1'b1;
                if(startTheSending) begin
                    state <= 2'd1;
                end
            end
            2'd1: begin
                serial_output <= 1'b0;
                state <= 2'd2;
                bit_counter <= 4'd0;
            end
            2'd2: begin
                serial_output <= byte_processed[bit_counter];
                bit_counter <= bit_counter + 4'd1;
                if(bit_counter==4'd7) begin
                    state <= 2'd3;
                end
            end
        endcase
    end
    always@(posedge(clk)) begin
        //only related to data sending
        //also state is updated here
        case (state)
            2'd0: begin
                sending_done<= 1'b0;
                if(receiveData) begin
                    busy <= 1'b1;
                    startTheSending <= 1'b1;
                end
            end
            2'd1: begin
                startTheSending <= 1'b0;
                serial_output <= 1'b0;
            end
            2'd2: begin
                serial_output <= byte_processed[bit_counter];
            end
            2'd3: begin
                sending_done <= 1;
                state <= 2'd0;
                serial_output <= 1'b1;
                startTheSending <= 0;
                busy <= 0;
            end
        endcase
    end
endmodule

module controlToTxD (
    input clk,
    input rst,
    input sendData,
    input [15:0] min_distance_angle, max_distance_angle,obs_alert,
    output serial_output,
    output sendingDone,
    //TB
    output reg [2:0] steps,
    output wire busy,
    output reg receiveData,
    output reg [15:0] min_distance_angle_local,
    output reg TxD_reset,
    output [1:0] state,
    output startTheSending,
    output reg baud_clk
);
    //store values of CT, min_dist etc in local regs to ensure we can start the next cycle
    reg [15:0] max_distance_angle_local,obs_alert_local;
    reg [7:0] byteAtHandReg;
    wire [7:0] byteAtHand;
    reg internalReset;
    reg [8:0] baud_counter;
    reg extraCounter;
    reg receiveDataWait;
    wire baud_clk_wire,TxD_reset_wire;
    assign baud_clk_wire = baud_clk;
    assign byteAtHand = byteAtHandReg;
    assign TxD_reset_wire = TxD_reset;
    TxD transmiterr(
        .clk(clk),
        .reset(TxD_reset_wire),
        .baud_clk(baud_clk_wire),
        .byte_processed(byteAtHand),
        .receiveData(receiveData),
        .sending_done(sendingDone),//ensure this is ON only for 1 clk
        .serial_output(serial_output),
        .busy(busy),//add an output reg named busy that I can use here
        .state(state),
        .startTheSending(startTheSending)
    );
    //create a baud clock here for reference, we will use that as reference in the future
    always@(posedge clk) begin
    if(baud_counter<434) begin
        baud_counter<= baud_counter+1;
    end

    if(baud_counter==434) begin
        baud_clk <= ~baud_clk;
        baud_counter <= 0;
    end
    end
    always@(posedge(clk)) begin
        if (rst | internalReset) begin
            //write reset conditions
            steps <= 3'b111;
            TxD_reset <= 1'b1;
            internalReset <= 1'b0;
            baud_clk <= 0;
            baud_counter <= 0;
        end else begin
        if(sendData) begin
            obs_alert_local <= obs_alert;
            min_distance_angle_local <= min_distance_angle;
            max_distance_angle_local <= max_distance_angle;
            byteAtHandReg <= obs_alert[7:0];
            TxD_reset <= 1'b1;
            extraCounter <= 1'b1;
            baud_clk <= 0;
            baud_counter <= 0;
        end else begin
        if(extraCounter) begin
            steps <= 3'b000;
            extraCounter <= 0;
            TxD_reset <= 1'b0;
        end
        if(steps==3'b000) begin
            if((!busy) & (!sendingDone)) begin
                receiveData <= 1'b1;
                receiveDataWait <= 1'b0;
            end else if (busy) begin
                //now transmitter is busy
                receiveDataWait <= 1'b1;
                if(receiveDataWait==0) begin
                    receiveData <= 1'b0;
                end
            end if (sendingDone) begin
                steps <= 3'b001;
                TxD_reset <= 1'b1;
                byteAtHandReg <= obs_alert_local[15:8];
            end
        end
        if(steps==3'b001) begin
            if(TxD_reset) begin
                TxD_reset <= 1'b0;
            end else begin
            if((!busy) & (!sendingDone)) begin
                receiveData <= 1'b1;
            end else if (busy) begin
                //now transmitter is busy
                receiveData <= 1'b0;
            end if (sendingDone) begin
                steps <= 3'b010;
                TxD_reset <= 1'b1;
                byteAtHandReg <= min_distance_angle_local[7:0];
            end
            end
        end
        if(steps==3'b010) begin
            if(TxD_reset) begin
                TxD_reset <= 1'b0;
            end else begin
            if((!busy) & (!sendingDone)) begin
                receiveData <= 1'b1;
            end else if (busy) begin
                //now transmitter is busy
                receiveData <= 1'b0;
            end if (sendingDone) begin
                steps <= 3'b011;
                TxD_reset <= 1'b1;
                byteAtHandReg <= min_distance_angle_local[15:8];
            end
            end
        end
        if(steps==3'b011) begin
            if(TxD_reset) begin
                TxD_reset <= 1'b0;
            end else begin
            if((!busy) & (!sendingDone)) begin
                receiveData <= 1'b1;
            end else if (busy) begin
                //now transmitter is busy
                receiveData <= 1'b0;
            end if (sendingDone) begin
                steps <= 3'b100;
                TxD_reset <= 1'b1;
                byteAtHandReg <= max_distance_angle_local[7:0];
            end
            end
        end
        if(steps==3'b100) begin
            if(TxD_reset) begin
                TxD_reset <= 1'b0;
            end else begin
            if((!busy) & (!sendingDone)) begin
                receiveData <= 1'b1;
            end else if (busy) begin
                //now transmitter is busy
                receiveData <= 1'b0;
            end if (sendingDone) begin
                steps <= 3'b101;
                TxD_reset <= 1'b1;
                byteAtHandReg <= max_distance_angle_local[15:8];
            end
            end
        end
        if(steps==3'b101) begin
            //sending is done, now reset this module
            internalReset <= 1'b1;
        end
        end
        end
    end
endmodule

module topModule(
    input wire receiveData,
    input wire clk,
    output wire transmitData,
    output wire reset
);

// module RxD (
//     input  clk,
//     input  reset,
//     input  serial_input,
//     output reg [7:0] parallel_data,
//     output reg byte_packed
// );

// module distanceProcess (
//     input [7:0] data,
//     input clk,//processor clock
//     input rst,
//     input takeData, //takeData tells us if we should interpret the data or not.
//     //takeData will go 1 for 1 clk cycle or sm
//     //takeData will be used only when data variable is being used
//     output reg [15:0] max_distance_angle, min_distance_angle, obs_alert,
//     output reg sendData
// );

// module controlToTxD (
//     input clk,
//     input rst,
//     input sendData,
//     input [15:0] min_distance_angle, max_distance_angle,obs_alert
//     output serial_output
// );
    wire [7:0] parallel_data;
    wire byte_packed;
    wire [15:0] min_distance_angle,max_distance_angle,obs_alert;
    wire sendData;
    RxD Bulbasaur(
        .clk(clk),
        .reset(reset),
        .serial_input(receiveData),
        .parallel_data(parallel_data),
        .byte_packed(byte_packed)
    );
    distanceProcess Charmander(
        .data(parallel_data),
        .clk(clk),
        .rst(reset),
        .takeData(byte_packed),
        .min_distance_angle(min_distance_angle),
        .max_distance_angle(max_distance_angle),
        .obs_alert(obs_alert),
        .sendData(sendData)
    );
    controlToTxD Squirlte(
        .clk(clk),
        .rst(reset),
        .sendData(sendData),
        .min_distance_angle(min_distance_angle),
        .max_distance_angle(max_distance_angle),
        .obs_alert(obs_alert),
        .serial_output(transmitData)
    );
endmodule
