`timescale 1ns/1ps
module tb_new_frame_unit;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,s=0;reg [3:0] fid=0;reg [31:0] payload=0;
    wire rs;wire [3:0] rf;wire [31:0] data;
    result_new_frame #(.FRAME_WIDTH(4),.PAYLOAD_WIDTH(32)) dut(clk,rst_n,s,fid,payload,rs,rf,data);
    integer src,dst,n,i,reset_value,strobe_value,id_value;reg [31:0] word;
    initial begin #1000000;$fatal(1,"watchdog");end
    initial begin
        src=$fopen("unit.txt","r");dst=$fopen("unit_actual.csv","w");
        if(!src || !dst) $fatal(1,"file open failed");
        $fdisplay(dst,"index,strobe,frame_id,payload");
        while(!$feof(src)) begin
            n=$fscanf(src,"%d %d %d %d %h\n",i,reset_value,strobe_value,id_value,word);
            if(n!=5) $fatal(1,"bad vector");
            @(negedge clk);rst_n=reset_value;s=strobe_value;fid=id_value;payload=word;
            #1;if(!rst_n && {rs,rf,data}!==37'b0) $fatal(1,"async reset failure");
            @(posedge clk);#1;
            if((^{rs,rf,data})===1'bx) $fatal(1,"unknown output");
            $fdisplay(dst,"%0d,%0d,%0d,%0d",i,rs,rf,data);
        end
        $fclose(src);$fclose(dst);$display("C7_UNIT_COMPLETE");$finish;
    end
endmodule
