
`include "DIV.v"

module distanceProcess(input wire clock,
    input wire [7:0]datain,
    input wire flashin,
    input wire reset,
    output reg[15:0] lowest,
    output reg[15:0] highest,
    output reg[15:0] hitvector,
    output reg flashout);
    //lil one coming first
    reg [7:0]length; 
    reg [8:0]lengthcopy;
    reg [3:0] trimmed_length;
    reg [15:0]FSA;
    reg [15:0]LSA;
    reg [15:0]data[255:0];
    reg [3:0] execstate;
    reg [8:0] datastate;//so many locs
    reg [7:0] counter;

    //used for the multiplication circuitary
    wire [23:0] multipliedval1;
    wire [23:0] multipliedval2;
    reg [7:0] lowestcount;
    reg [7:0] highestcount;
    assign multipliedval1 = (FSA*(length-lowestcount-8'h01) + LSA*(lowestcount));
    assign multipliedval2 = (FSA*(length-highestcount-8'h01) + LSA*(highestcount));

    reg [2:0]ignore_adress;
    reg trig_div;
    wire div_res1;
    wire div_res2;
    wire [15:0]lowest_out;
    wire [15:0]highest_out;
    div divider1(multipliedval1,length-8'h01,trig_div,clock,reset,lowest_out,div_res1);
    div divider2(multipliedval2,length-8'h01,trig_div,clock,reset,highest_out,div_res2);

    integer i;

    localparam IDLE = 4'b0000;
    localparam L_IN = 4'b0001;
    localparam FSA1 = 4'b0010;
    localparam FSA2 = 4'b0011;
    localparam LSA1 = 4'b0100;
    localparam LSA2 = 4'b0101;//6 is skipped woops....
    localparam DATA = 4'b0111;
    localparam LOWA = 4'b1000;
    localparam HIGA = 4'b1001;
    localparam DIVD = 4'b1010;
    localparam DIST = 4'b1011;

    always @(posedge clock) begin // runs on the supa fast clock
        if (!reset) begin
            if (flashin) begin
                case(execstate)
                    IDLE: begin
                        if (ignore_adress == 2) begin
                        length <= datain;
                        lengthcopy <= 2*datain;// used for looping through elements
                        if (datain > 4'b1111) begin trimmed_length <= 4'b1111;end
                        else begin trimmed_length <= datain[3:0]; end
                        execstate <=L_IN; ignore_adress <= 3'b000;
                        end
                        else ignore_adress <= ignore_adress+1;
                    end
                    L_IN: begin
                        FSA[7:0] <= datain;
                        execstate <=FSA1;

                    end
                    FSA1: begin
                        FSA[15:8] <= datain;
                        execstate <=FSA2;                        
                    end
                    FSA2: begin
                        LSA[7:0] <= datain;
                        execstate <=LSA1;                        
                    end
                    LSA1: begin
                        LSA[15:8] <= datain;
                        execstate <=LSA2;
                        datastate <= 9'o000;                        
                    end

                    LSA2: begin
                        //$display("%h",data[datastate[8:1]-1]);
                        datastate <= datastate+1;
                        if (datastate[0]) begin
                        data[datastate[8:1]][15:8] <= datain;
                        end
                        else begin
                        data[datastate[8:1]][7:0] <= datain;    
                        end
                        if (datastate == lengthcopy-1) 
                        begin execstate <= DATA;
                        //lengthcopy <= 2*length; 
                        counter <= 8'h00; 
                        end
                    end


                endcase
            end
            case (execstate)
                    IDLE: begin
                        counter <= 8'h00;
                        lowest <= 16'h0000;
                        lowestcount <= 8'h00;
                        highest <= 16'h0000;;
                        highestcount <= 8'h00;
                        hitvector <= 16'h0000;
                        flashout <= 0;
                    end
                    DATA: begin
                            counter <= counter + 1;
                            if (counter == length-1) begin execstate <= LOWA; counter <= 8'h00;end
                            if (counter == 0) begin
                                lowestcount <= 8'h00;
                                lowest <= data[0];
                            end
                            else begin
                                if (data[counter] < lowest) begin
                                    lowest <= data[counter];
                                    lowestcount <= counter;
                                end
                            end
                    end
                    LOWA: begin
                        counter <= counter + 1;
                        if (counter == length-1) begin execstate <= HIGA;trig_div<=1'b1; counter <= 8'h00; end;
                        if (counter == 0) begin
                            highestcount <= 8'h00;
                            highest <= data[0];
                        end
                        else begin
                            if (data[counter] > highest) begin
                                highest <= data[counter];
                                highestcount  <= counter;
                            end
                        end
                    end
                    HIGA : begin
                        trig_div <= 0;
                        if (div_res1 == 1 && div_res2 == 1) begin
                            lowest <= lowest_out;
                            highest <= highest_out;
                            execstate <= DIVD;
                        end
                    end

                    DIVD : begin
                        counter <= counter + 1;
                        if (counter == trimmed_length-1) begin 
                            execstate <= DIST; counter <= 8'h00;
                        end//im assuming least count is 0.1mm and not 1 mm
                        if (data[counter] < 16'h400) begin
                            hitvector[counter] <= 1'b1;
                        end
                        else hitvector[counter] <= 1'b0;
                    end
                    DIST : begin
                        flashout <=1;
                        if (counter) execstate <= IDLE;
                        else counter <= 8'h01;
                    end

                    

                endcase
            end
            else begin
                flashout <=0;
                execstate <= IDLE;
                datastate <= 9'o000;
                length <= 8'h00;
                lengthcopy <= 9'h00;
                trimmed_length <= 4'h0;
                FSA <= 16'h0000;
                LSA <= 16'h0000;
                hitvector <= 16'h0000;
                counter <= 8'h00;
                lowest <= 16'h0000;
                highest <= 16'h0000; 
                lowestcount <= 8'h00;
                highestcount <= 8'h00;
                trig_div <= 1'b0;
                ignore_adress <= 3'b000;
                for (i =0;i<256;i++) begin
                    data[i] <= 16'h0000;
                end
            end
    end
endmodule