`timescale 1ns/1ps
module tb_sobel_arithmetic;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,v=0;
    reg [71:0] patch=0;
    reg [10:0] threshold=0;
    wire ov;
    wire signed [10:0] gx,gy;
    wire [10:0] mag;
    wire [7:0] edge_pixel;
    integer f,rc,iv,egx,egy,em,ee,tests=0;
    sobel_core dut(clk,rst_n,v,patch,threshold,ov,gx,gy,mag,edge_pixel);
    initial begin
        f=$fopen("sobel_vectors.txt","r");if(!f)$fatal(1,"Missing vectors");
        repeat(3)@(negedge clk);rst_n=1;
        while(!$feof(f))begin
            @(negedge clk);rc=$fscanf(f,"%d %h %h %d %d %d %d\n",iv,patch,threshold,egx,egy,em,ee);
            if(rc!=7)$fatal(1,"Malformed vector");v=iv;
            @(posedge clk);#1;
            if(ov!==v || $signed(gx)!=egx || $signed(gy)!=egy || mag!=em || edge_pixel!=ee)
                $fatal(1,"Sobel arithmetic mismatch %d gx=%d gy=%d mag=%d edge=%d",tests,gx,gy,mag,edge_pixel);
            tests=tests+1;
        end
        @(negedge clk);rst_n=0;#1;
        if(ov || gx || gy || mag || edge_pixel)$fatal(1,"Sobel reset failed");
        $display("PASS SOBEL_ARITHMETIC: vectors=%0d",tests);$finish;
    end
endmodule
