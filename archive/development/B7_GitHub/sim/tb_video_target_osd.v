`timescale 1ns/1ps
module tb_video_target_osd;
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
    video_target_osd dut(.*);
    reg ev=0,er=0,capture=0;
    reg [159:0] ep=0;
    reg [23:0] ec=0;
    reg qv=0,qr=0,qs=0,ql=0,qe=0,qcap=0;
    reg [10:0] qx=0,qy=0;
    reg [31:0] qid=0;
    reg [159:0] qp=0;
    reg [23:0] qc=0;
    integer checks=0,pixels=0,fd,outfile,n,line=0,FULL_FRAMES=0;
    always @(posedge clk) begin
        if(!rst_n || stream_abort) begin
            qv=0;
            #1;
            if(out_valid || out_sof || out_eol || out_eof || out_packet!==0)
                $fatal(1,"Reset/abort did not clear pipeline");
        end else begin
            #1;
            if(out_valid!==qv || out_sof!==(qv&&qs) || out_eol!==(qv&&ql) || out_eof!==(qv&&qe))
                $fatal(1,"Latency/valid/marker mismatch at check %0d",checks);
            if(qv) begin
                if(out_x!==qx || out_y!==qy || out_refresh_id!==qid || out_snapshot_ready!==qr || out_packet!==qp)
                    $fatal(1,"Metadata mismatch at check %0d x=%0d y=%0d got=%h expected=%h",checks,qx,qy,out_packet,qp);
                if(qcap) begin
                    $fwrite(outfile,"%c%c%c",out_rgb[23:16],out_rgb[15:8],out_rgb[7:0]);
                    pixels=pixels+1;
                end else if(out_rgb!==qc)
                    $fatal(1,"Sparse pixel mismatch at check %0d got=%h expected=%h",checks,out_rgb,qc);
            end else if(out_rgb!==0) $fatal(1,"Invalid output RGB not zero");
            qv=ev;qr=er;qp=ep;qc=ec;qx=in_x;qy=in_y;qid=in_refresh_id;
            qs=in_sof;ql=in_eol;qe=in_eof;qcap=capture;
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
            repeat(3)idle();
            $display("FRAME %0d PASS metadata, timing and stable packet",id);
        end
    endtask
    initial begin
        outfile=$fopen("actual.rgb","wb");
        fd=$fopen("directed.txt","r");
        if(!fd || !outfile)$fatal(1,"Cannot open fixtures/output");
        while(!$feof(fd))begin
            @(negedge clk);
            n=$fscanf(fd,"%d %d %d %d %d %d %d %d %h %d %d %h %h %d %d %h %d %h %d %h\n",
                rst_n,stream_abort,in_valid,in_sof,in_eol,in_eof,in_x,in_y,in_rgb,in_refresh_id,
                completed_ready,completed_refresh_id,expected_cfg_id,expected_target_id,
                result_strobe,incoming,er,ep,ev,ec);
            if(n!=20)$fatal(1,"Bad vector row %0d count %0d",line,n);
            line=line+1;
        end
        repeat(3)idle();
        `include "scenario.vh"
        repeat(3)idle();
        if(pixels!=FULL_FRAMES*1280*720)$fatal(1,"Image coverage %0d",pixels);
        $fclose(outfile);
        $display("PASS B1A: %0d directed vectors, %0d pixels, %0d cycle checks",line,pixels,checks);
        $finish;
    end
    initial begin #250000000;$fatal(1,"Watchdog");end
endmodule
