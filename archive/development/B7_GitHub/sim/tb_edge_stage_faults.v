`timescale 1ns/1ps
module tb_edge_stage_faults;
    localparam W=16,H=12;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,abort_in=0,v=0,s=0,l=0,e=0;
    reg [7:0] gray=0;
    reg [10:0] x=0,y=0;
    reg [31:0] epoch=1,fid=2;
    reg [15:0] cfg=3;
    reg [1:0] tid=0;
    wire ov,os,ol,oe,oa;
    wire [23:0] rgb;
    wire [10:0] ox,oy;
    wire [81:0] ot;
    wire [4:0] err;
    reg checking=0,quiet=0;
    integer i,j,seen=0,aborts=0,tests=0;
    reg [23:0] expected;
    video_gray_edge_stream #(.WIDTH(W),.HEIGHT(H),.MAX_IDLE_CYCLES(32)) dut(
        .clk(clk),.rst_n(rst_n),.stream_abort(abort_in),.in_valid(v),.in_gray(gray),
        .in_sof(s),.in_eol(l),.in_eof(e),.in_x(x),.in_y(y),
        .in_epoch(epoch),.in_frame_id(fid),.in_cfg_id(cfg),.in_target_id(tid),
        .out_valid(ov),.out_rgb(rgb),.out_sof(os),.out_eol(ol),.out_eof(oe),.out_x(ox),.out_y(oy),
        .out_epoch(ot[81:50]),.out_frame_id(ot[49:18]),.out_cfg_id(ot[17:2]),.out_target_id(ot[1:0]),
        .out_abort(oa),.error_flags(err));
    always @(posedge clk)begin
        #1;
        if(rst_n)begin
            if(oa)aborts=aborts+1;
            if(quiet && ov)$fatal(1,"Old edge after flush");
            if(checking)begin
                if(oa)$fatal(1,"Unexpected recovery abort");
                if(ov)begin
                    expected=(seen/W>0 && seen/W<H-1 && (seen%W==7 || seen%W==8))?24'hffffff:24'd0;
                    if(ox!==seen%W || oy!==seen/W || rgb!==expected || ot!=={epoch,fid,cfg,tid} ||
                        os!==(seen==0) || ol!==(seen%W==W-1) || oe!==(seen==W*H-1))$fatal(1,"Recovery mismatch %d",seen);
                    seen=seen+1;
                end
            end
        end
    end
    task idle;begin @(negedge clk);v=0;s=0;l=0;e=0;abort_in=0;end endtask
    task drive;
        input integer a,b;
        begin @(negedge clk);v=1;x=a;y=b;s=a==0 && b==0;l=a==W-1;e=l && b==H-1;gray=(a<8)^epoch[0]?8'd0:8'd255;end
    endtask
    task reset;
        begin checking=0;quiet=0;idle();rst_n=0;repeat(3)idle();rst_n=1;epoch=1;fid=2;cfg=3;tid=0;aborts=0;end
    endtask
    task expect_fault;
        input [4:0] bits;
        begin repeat(5)idle();if((err&bits)!=bits || aborts==0 || ov)$fatal(1,"Missed edge fault expected=%h actual=%h",bits,err);
            quiet=1;repeat(4)idle();quiet=0;tests=tests+1;end
    endtask
    task recover;
        begin
            epoch=epoch+1;seen=0;checking=1;
            for(j=0;j<H;j=j+1)for(i=0;i<W;i=i+1)drive(i,j);
            repeat(W+8)idle();checking=0;
            if(seen!=W*H)$fatal(1,"Missing recovery pixels %d",seen);
        end
    endtask
    initial begin
        reset();drive(0,0);drive(1,0);idle();expect_fault(5'h02);recover();
        reset();drive(0,0);drive(2,0);expect_fault(5'h04);recover();
        reset();drive(0,0);drive(1,0);fid=7;expect_fault(5'h04);recover();
        reset();drive(0,0);drive(1,0);epoch=7;expect_fault(5'h04);recover();
        reset();drive(0,0);drive(1,0);cfg=7;expect_fault(5'h04);recover();
        reset();drive(0,0);drive(1,0);tid=2;expect_fault(5'h04);recover();
        reset();drive(0,0);drive(0,0);expect_fault(5'h04);recover();
        reset();drive(0,0);drive(1,0);e=1;expect_fault(5'h04);recover();
        reset();for(i=0;i<W;i=i+1)drive(i,0);repeat(35)idle();expect_fault(5'h01);recover();
        reset();for(j=0;j<4;j=j+1)for(i=0;i<W;i=i+1)drive(i,j);
        @(negedge clk);abort_in=1;v=0;expect_fault(5'h10);recover();
        reset();for(j=0;j<2;j=j+1)for(i=0;i<W;i=i+1)drive(i,j);
        for(i=0;i<5;i=i+1)drive(i,2);force dut.ev=0;
        drive(5,2);drive(6,2);release dut.ev;expect_fault(5'h08);recover();
        reset();for(j=0;j<4;j=j+1)for(i=0;i<W;i=i+1)drive(i,j);
        @(negedge clk);rst_n=0;v=0;#1;if(ov)$fatal(1,"Async reset failed");
        repeat(3)idle();rst_n=1;quiet=1;drive(4,4);drive(5,4);repeat(5)idle();quiet=0;tests=tests+1;recover();
        $display("PASS EDGE_STAGE_FAULTS: scenarios=%0d",tests);$finish;
    end
    initial begin #2000000;$fatal(1,"Watchdog");end
endmodule
