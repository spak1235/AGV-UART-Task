`include "topModule.v"

module testbench;
    wire [7:0]out;
    reg reset =0;
    wire clk;
    masterclock cock(clk);
    wire connect;
    siggen sig(connect);
    wire [7:0]RDX_MEMA;
    wire [7:0]RDX_MEMB;
    wire RDX_half_clock;
    wire RDX_full_clock;
    wire [7:0]RDX_InfoPulse;
    wire infodump;
    wire [7:0]RDX_shiftSTORE;
    //RxD RRR(connect,clk,reset,RDX_InfoPulse,RDX_infotime);

    wire [15:0]DX_LOWEST;
    wire [15:0]DX_HIGHEST;
    wire [15:0]DX_HITOUT;
    wire DX_flashout;
    //distanceProcess DDD(clk,RDX_InfoPulse,RDX_infotime,reset,DX_LOWEST,DX_HIGHEST,DX_HITOUT,DX_flashout);
    wire [8:0] DX_DDDlength;
    wire [8:0] DX_DDDlengthnoncopy;
    wire [3:0] DX_DDDlengthlimit;
    wire [3:0] DX_execstate;
    wire [23:0] mult1;
    wire [23:0] mult2;
    wire [15:0] DX_quot;
/*
    wire [15:0] quotient;
    wire [23:0] BIG;
    wire divdone;
    reg flesh;
    div DIVIDE(24'h2BA891,8'h3A,flesh,clk,reset,quotient,divdone);
    assign BIG = DIVIDE.biginp;  */
    localparam TIME = 4340;
    wire [2:0]RDX_state;
    wire RDX_babydonthurtme;
    wire [2:0] RDX_babydonthurtmecount;
    wire [2:0]RDX_count;

    wire TXD_write;
    //TxD Transmit(clk,reset,16'hAA55,{DX_LOWEST,DX_HIGHEST,DX_HITOUT},DX_flashout,TXD_write);

    topModule T(connect,clk,reset,TXD_write);

    assign RDX_half_clock = T.R0.half_done;
    assign RDX_full_clock = T.R0.uart_clock_out;
    assign mult1 = T.D0.multipliedval1;
    assign mult2 = T.D0.multipliedval2;
    assign DX_DDDlength = T.D0.lengthcopy;
    assign DX_DDDlengthnoncopy = T.D0.length;
    assign DX_DDDlengthlimit = T.D0.trimmed_length;
    assign DX_execstate = T.D0.execstate;
    assign DX_quot = T.D0.divider1.lessbig;

    assign RDX_MEMA = T.R0.MEMA;
    assign RDX_MEMB = T.R0.MEMB;
    assign RDX_state = T.R0.state;
    assign RDX_shiftSTORE = T.R0.buffer.out;
    assign RDX_count = T.R0.BC.store;
    //assign RDX_babydonthurtme = T.R0.ignore_all;

    assign DX_LOWEST = T.DX_LOWEST;
    assign DX_HIGHEST = T.DX_HIGHEST;
    assign DX_HITOUT = T.DX_HITOUT;
    assign DX_flashout = T.DX_flashout;

    assign RDX_InfoPulse = T.RDX_InfoPulse;
    assign RDX_infotime = T.RDX_infotime;
    
    initial begin
        $dumpfile("testbench.vcd");
        $dumpvars(1,testbench);
        reset = 1;
        #(TIME);
        reset = 0;
        #(TIME);
        #(4000*TIME);
        $finish(1);
    end
endmodule

module clock(output reg out);
    reg dog;
    initial begin
        out =0;
        #0.5;
        dog=1;
    end
    always begin
        if (dog==1) begin
        #1 out = !out;
        end
        else #0.1;
    end
endmodule

module masterclock(output reg out);
    localparam TIME = 4340;
    initial begin
        out = 0;
    end
    always begin
        #5 out <= !out;
    end
endmodule

module siggen(output reg out);
    localparam TIME = 4340;
    reg [15:0]reg1 = 16'hAA55;
    reg [103:0]reg2 = 104'h78452390782211CDAB9CA1FB04;
    reg [359:0]amigay = 360'h117512342000212111110FAB11ABABCD112312340310029903000ABCAAAAA0BC00AB00070008FBAD3311001114; //womp womp sha356 aaa key
    
    reg [857:0]gaydarwhere = 856'h4761796461722041637469766174652E204761796461722073656E736520616D6F6E672075732E2E2E2E20486F742067617973206E65617220796F752E2077697468696E20312E35204B6D2E206E656172657374206761792061742037372064656772656573AA00110033;
    integer i;
    initial begin
        out = 1'b1;
        #(4*TIME);
        out =1'b0;
        #(2*TIME);
        for (i = 0;i<16;i++) begin
            out=reg1[i];
            #(2*TIME);
        end
        for (i = 0;i<858;i++) begin
            out=gaydarwhere[i];
            #(2*TIME);
        end
        assign out = 1'b1;#(2*TIME);
        
    end
endmodule