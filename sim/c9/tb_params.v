`timescale 1ns/1ps
module tb_params;
    reg clk=0;always #5 clk=~clk;
    reg rst=0,pv=0,ok=0;reg [8:0] count=0;
    reg [7:0] mr,mg,mb,lr,lg,lb,hr,hg,hb;
    reg signed [9:0] sat_value;
    reg [23:0] rgb;reg [1:0] target;
    reg [7:0] tm,t1,t2;
    wire valid,mv,mask;wire [2:0] reason;wire [1:0] color;
    wire [7:0] main,d1,d2,sat;
    calibration_params dut(ok,count,mr,mg,mb,lr,lg,lb,hr,hg,hb,valid,reason,color,main,d1,d2);
    saturate_sub32 clamp(sat_value,sat);
    color_classifier_runtime pixel(tm,t1,t2,clk,rst,pv,rgb,target,mv,mask);
    integer src,out,n,index;
    initial begin #10000000;$fatal(1,"watchdog");end
    initial begin
        src=$fopen("params.txt","r");out=$fopen("params_actual.csv","w");
        $fdisplay(out,"index,valid,reason,color,main,d1,d2,sat,mv,mask");index=0;
        while(!$feof(src)) begin
            @(negedge clk);
            n=$fscanf(src,"%d %d %d %d %d %d %d %d %d %d %d %d %d %d %h %d %d %d %d\n",
                rst,pv,ok,count,mr,mg,mb,lr,lg,lb,hr,hg,hb,sat_value,rgb,target,tm,t1,t2);
            if(n!=19) $fatal(1,"bad params input");
            @(posedge clk);#1;
            $fdisplay(out,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",index,valid,reason,color,main,d1,d2,sat,mv,mask);
            index=index+1;
        end
        $display("C9_PARAMS_COMPLETE cycles=%0d",index);$fclose(src);$fclose(out);$finish;
    end
endmodule
