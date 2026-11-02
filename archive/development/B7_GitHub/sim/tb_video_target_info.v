`timescale 1ns/1ps
module tb_video_target_info;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,stream_abort=0;
    reg in_valid=0,in_sof=0,in_eol=0,in_eof=0;
    reg [10:0] in_x=0,in_y=0;
    reg [23:0] in_rgb=0;
    reg [31:0] in_refresh_id=0;
    reg completed_ready=0;
    reg [31:0] completed_refresh_id=0;
    reg [15:0] expected_cfg_id=1;
    reg [1:0] expected_target_id=0;
    reg result_strobe=0;
    reg [159:0] incoming=0;
    wire target_valid;
    wire [31:0] result_frame_id;
    wire [15:0] result_cfg_id;
    wire [1:0] result_target_id;
    wire [19:0] area;
    wire [10:0] xmin,ymin,xmax,ymax,cx,cy;
    wire [2:0] reason;
    wire [7:0] labels_used;
    wire [11:0] components;
    assign {result_frame_id,result_cfg_id,result_target_id,target_valid,area,xmin,ymin,xmax,ymax,cx,cy,reason,labels_used,components}=incoming;
    wire out_valid,out_sof,out_eol,out_eof,out_snapshot_ready;
    wire [10:0] out_x,out_y;
    wire [23:0] out_rgb;
    wire [31:0] out_refresh_id;
    wire [159:0] out_packet;
    video_target_info dut(.*);
    reg ev=0,er=0,capture=0;
    reg [159:0] ep=0;
    reg [23:0] ec=0;
    reg [218:0] queue[0:2];
    integer checks=0,pixels=0,fd,outfile,n,line=0,FULL_FRAMES=0,j;
    wire [218:0] observed={out_valid,out_sof,out_eol,out_eof,out_snapshot_ready,out_x,out_y,out_refresh_id,out_packet};
    always @(posedge clk)begin
        if(!rst_n || stream_abort)begin
            for(j=0;j<3;j=j+1)queue[j]=0;
            #1;if(out_valid || out_packet!==0)$fatal(1,"Reset/abort pipeline");
        end else begin
            #1;
            if(out_valid!==queue[2][218])$fatal(1,"Four-stage valid mismatch");
            if(out_valid)begin
                if(observed!==queue[2])$fatal(1,"Text metadata mismatch check %0d",checks);
                $fwrite(outfile,"%c%c%c",out_rgb[23:16],out_rgb[15:8],out_rgb[7:0]);pixels=pixels+1;
            end else if(out_rgb!==0 || out_sof || out_eol || out_eof)$fatal(1,"Blank output");
            queue[2]=queue[1];queue[1]=queue[0];
            queue[0]={ev,in_sof&&ev,in_eol&&ev,in_eof&&ev,er,in_x,in_y,in_refresh_id,ep};
            checks=checks+1;
        end
    end
    task idle;
        begin @(negedge clk);in_valid=0;in_sof=0;in_eol=0;in_eof=0;
            result_strobe=0;ev=0;capture=0;end
    endtask
    task publish;
        input [159:0] p;
        begin idle();result_strobe=1;incoming=p;idle();end
    endtask
    task frame;
        input integer id;
        input [159:0] expected;
        input integer ready;
        input integer sof_event,mid_event;
        input [159:0] sof_packet,mid_packet;
        integer x,y;
        begin
            for(y=0;y<750;y=y+1)begin
                for(x=0;x<1650;x=x+1)begin
                    @(negedge clk);
                    in_valid=(x<1280 && y<720);in_sof=in_valid&&x==0&&y==0;
                    in_eol=in_valid&&x==1279;in_eof=in_eol&&y==719;
                    in_x=x;in_y=y;in_rgb={x[7:0],y[7:0],8'h30};in_refresh_id=id;
                    ev=in_valid;er=ready;ep=expected;capture=1;
                    result_strobe=0;
                    if(sof_event && x==0 && y==0)begin result_strobe=1;incoming=sof_packet;end
                    if(mid_event && x==500 && y==300)begin result_strobe=1;incoming=mid_packet;end
                end
            end
            repeat(5)idle();
            $display("FRAME %0d PASS metadata, timing and stable packet",id);
        end
    endtask
    initial begin
        outfile=$fopen("actual.rgb","wb");
        if(!outfile)$fatal(1,"Cannot open output");
        repeat(5)idle();
        `include "scenario.vh"
        repeat(5)idle();
        if(pixels!=FULL_FRAMES*1280*720)$fatal(1,"Image coverage %0d",pixels);
        $fclose(outfile);
        $display("PASS B1B: %0d directed vectors, %0d pixels, %0d cycle checks",line,pixels,checks);
        $finish;
    end
    initial begin #400000000;$fatal(1,"Watchdog");end
endmodule
