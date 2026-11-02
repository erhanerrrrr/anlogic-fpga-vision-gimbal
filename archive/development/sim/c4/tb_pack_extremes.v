`timescale 1ns/1ps
module tb_pack_extremes;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,s=0;
    reg [19:0] count=0;
    reg [10:0] x0=0,x1=0,y0=0,y1=0;
    wire rs,v;
    wire [31:0] fid;wire [15:0] cfg;wire [1:0] tid;
    wire [19:0] a;wire [10:0] cx,cy,ox0,ox1,oy0,oy1;
    target_result_pack dut(clk,rst_n,s,32'd42,16'd0,2'd0,count,x0,x1,y0,y1,
        rs,v,fid,cfg,tid,a,cx,ox0,ox1,cy,oy0,oy1);
    task sample;
        input integer n,l,t,r,b,ex,ey;
        begin
            @(negedge clk);rst_n=1;s=1;count=n;x0=l;y0=t;x1=r;y1=b;
            @(posedge clk);#1;
            if(rs!==1 || v!==(n!=0) || cx!==ex || cy!==ey || a!==n || fid!==42 || cfg!==0 || tid!==0)
                $fatal(1,"extreme arithmetic mismatch");
            if(n==0 && {ox0,oy0,ox1,oy1}!==44'b0) $fatal(1,"invalid geometry not zero");
        end
    endtask
    initial begin
        #1;@(posedge clk);#1;
        sample(1,2047,2047,2047,2047,2047,2047);
        sample(2,2046,2044,2047,2047,2046,2045);
        sample(0,2047,2047,2047,2047,0,0);
        sample(4,10,20,11,21,10,20);
        sample(921600,0,0,1279,719,639,359);
        @(negedge clk);s=0;count=0;x0=0;x1=0;y0=0;y1=0;
        @(posedge clk);#1;
        if(rs!==0 || cx!==639 || cy!==359 || a!==921600) $fatal(1,"hold failed");
        $display("C4_EXTREMES_COMPLETE cases=5");$finish;
    end
    initial begin #10000;$fatal(1,"watchdog");end
endmodule
