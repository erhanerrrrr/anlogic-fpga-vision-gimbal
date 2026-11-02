`timescale 1ns/1ps
module tb_calibration_status_view;
    reg clk=0;always #5 clk=~clk;
    reg [53:0] stimulus=0;
    wire [50:0] packet;
    wire rst_n,known,sreq,sdone,done,ok,applied,pending,busy;
    wire [2:0] reason;
    wire [15:0] cfg;
    wire [1:0] color;
    wire [7:0] main,d1,d2;
    assign {rst_n,known,sreq,sdone,done,ok,applied,pending,busy,reason,cfg,color,main,d1,d2}=stimulus;
    calibration_status_view dut(.clk(clk),.rst_n(rst_n),.c_status_valid(known),.sample_req(sreq),.sample_done(sdone),
        .calibration_done(done),.calibration_ok(ok),.cfg_applied(applied),.pending_valid(pending),.busy(busy),
        .calibration_reason(reason),.active_cfg_id(cfg),.active_color(color),.active_main(main),.active_diff_1(d1),.active_diff_2(d2),.status_packet(packet));
    integer f,ret,count=0;
    reg [50:0] expected;
    initial begin
        f=$fopen("status_vectors.txt","r");if(!f)$fatal(1,"vectors missing");
        @(negedge clk);
        while(!$feof(f))begin
            ret=$fscanf(f,"%h %h\n",stimulus,expected);
            if(ret!=2)$fatal(1,"vector parse");
            @(posedge clk);#1;
            if(packet!==expected)$fatal(1,"status case %0d actual=%h expected=%h",count,packet,expected);
            count=count+1;@(negedge clk);
        end
        if(count<30)$fatal(1,"too few vectors");
        $display("PASS CALIBRATION_STATUS: cases=%0d",count);$finish;
    end
endmodule
