`timescale 1ns/1ps
module tb_rgb_mask_faults;
    parameter W=16,H=12,HT=16,GUARD=1,FULL=0,CAPACITY=0;
    localparam DEPTH=CAPACITY?16:(1 << $clog2(W+8));
    localparam IDLE_LIMIT=FULL?4096:64;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,abort_in=0,iv=0,s=0,l=0,e=0;
    reg [10:0] x=0,y=0;
    reg [23:0] rgb=0;
    reg [31:0] epoch=9,fid=15;
    reg [15:0] cfg=3;
    reg [7:0] threshold=24;
    wire ov,om,os,ol,oe,oa;
    wire [23:0] orgb;
    wire [10:0] ox,oy;
    wire [81:0] ot;
    wire [7:0] err;
    wire [15:0] used,peak;
    reg check_good=0,quiet=0;
    integer seen=0,aborts=0,tests=0,i,j,n,old_aborts;
    reg expected_mask;
    function [23:0] pixel;
        input integer a,b;
        begin pixel=((200+a%20)<<16)|((b%8)<<8);end
    endfunction
    video_rgb_mask_pair #(.WIDTH(W),.HEIGHT(H),.GUARD_ROWS(GUARD),.FIFO_DEPTH(DEPTH),.MAX_IDLE_CYCLES(IDLE_LIMIT)) dut(
        .clk(clk),.rst_n(rst_n),.stream_abort(abort_in),
        .in_valid(iv),.in_sof(s),.in_eol(l),.in_eof(e),.in_rgb(rgb),.in_x(x),.in_y(y),
        .in_epoch(epoch),.in_frame_id(fid),.in_cfg_id(cfg),.in_target_id(2'd0),
        .min_main(threshold),.min_diff_1(8'd16),.min_diff_2(8'd16),
        .out_valid(ov),.out_rgb(orgb),.out_mask(om),.out_sof(os),.out_eol(ol),.out_eof(oe),
        .out_x(ox),.out_y(oy),.out_epoch(ot[81:50]),.out_frame_id(ot[49:18]),
        .out_cfg_id(ot[17:2]),.out_target_id(ot[1:0]),.out_abort(oa),
        .error_flags(err),.fifo_used(used),.fifo_peak(peak));
    always @(posedge clk)begin
        #1;
        if(rst_n)begin
            if(oa)aborts=aborts+1;
            if(quiet && ov)$fatal(1,"Stale output while waiting for fresh SOF");
            if(check_good)begin
                if(oa)$fatal(1,"Fault during recovery frame: %h",err);
                if(ov)begin
                    expected_mask=ox>0 && ox<W-1 && oy>0 && oy<H-1 && oy>=GUARD && oy<H-GUARD;
                    if(ox!==seen%W || oy!==seen/W || orgb!==pixel(seen%W,seen/W) ||
                        om!==expected_mask || ot!=={epoch,fid,cfg,2'd0} ||
                        os!==(seen==0) || ol!==(seen%W==W-1) || oe!==(seen==W*H-1))
                        $fatal(1,"Recovery pixel/metadata mismatch index=%d",seen);
                    seen=seen+1;
                end
            end
        end
    end
    task idle;
        begin @(negedge clk);iv=0;s=0;l=0;e=0;abort_in=0;end
    endtask
    task drive;
        input integer a,b;
        begin @(negedge clk);iv=1;x=a;y=b;s=a==0 && b==0;l=a==W-1;e=l && b==H-1;rgb=pixel(a,b);end
    endtask
    task reset;
        begin
            check_good=0;quiet=0;idle();rst_n=0;repeat(3)idle();rst_n=1;
            epoch=9;fid=15;cfg=3;threshold=24;aborts=0;seen=0;
        end
    endtask
    task expect_fault;
        input [7:0] mask;
        begin
            idle();idle();
            if((err & mask)!=mask || aborts==0 || used!=0 || ov)
                $fatal(1,"Fault not detected/recovered expected=%h actual=%h aborts=%d",mask,err,aborts);
            quiet=1;repeat(8)idle();quiet=0;
            tests=tests+1;
        end
    endtask
    task recover;
        begin
            // A higher epoch with reused frame ID must survive intact.
            epoch=epoch+1;threshold=24;cfg=3;seen=0;check_good=1;
            for(j=0;j<H;j=j+1)begin
                for(i=0;i<W;i=i+1)drive(i,j);
                repeat(HT-W)idle();
            end
            repeat(W+24)idle();check_good=0;
            if(seen!=W*H || used!=0)$fatal(1,"Incomplete recovery %d",seen);
        end
    endtask
    initial begin
        reset();
        if(CAPACITY)begin
            for(i=0;i<W;i=i+1)drive(i,0);drive(0,1);
            expect_fault(8'h04);
        end else if(FULL)begin
            // Reset with both RGB and mask streams already active.
            for(j=0;j<6;j=j+1)begin
                for(i=0;i<W;i=i+1)drive(i,j);
                repeat(HT-W)idle();
            end
            drive(0,6);drive(1,6);@(negedge clk);rst_n=0;iv=0;
            #1;if(ov)$fatal(1,"Async reset did not suppress valid");
            repeat(3)idle();rst_n=1;quiet=1;
            // Non-SOF remnants must be ignored.
            drive(4,6);drive(5,6);repeat(8)idle();quiet=0;
            tests=tests+1;recover();
        end else begin
            drive(0,0);drive(1,0);idle();expect_fault(8'h02);recover();
            reset();drive(0,0);drive(2,0);expect_fault(8'h01);recover();
            reset();drive(0,0);drive(1,0);cfg=4;expect_fault(8'h01);recover();
            reset();drive(0,0);drive(1,0);epoch=10;expect_fault(8'h01);recover();
            reset();drive(0,0);drive(1,0);threshold=25;expect_fault(8'h01);recover();
            reset();drive(0,0);drive(0,0);expect_fault(8'h01);recover();
            reset();drive(0,0);drive(1,0);l=1;expect_fault(8'h01);recover();
            reset();for(i=0;i<W;i=i+1)drive(i,0);
            repeat(IDLE_LIMIT+4)idle();expect_fault(8'h20);recover();
            reset();drive(0,0);drive(1,0);@(negedge clk);abort_in=1;iv=0;
            expect_fault(8'h40);recover();
            reset();drive(0,0);drive(1,0);
            @(negedge clk);iv=0;force dut.f_valid=1;force dut.fx=7;
            @(negedge clk);release dut.f_valid;release dut.fx;
            expect_fault(8'h10);recover();
            reset();force dut.f_valid=1;
            idle();release dut.f_valid;expect_fault(8'h08);recover();
            reset();drive(0,0);drive(1,0);
            @(negedge clk);rst_n=0;iv=0;#1;if(ov)$fatal(1,"Reset valid");
            repeat(3)idle();rst_n=1;quiet=1;drive(4,0);drive(5,0);repeat(8)idle();quiet=0;
            tests=tests+1;recover();
        end
        $display("PASS RGB_MASK_FAULTS: tests=%0d size=%0dx%0d capacity=%0d",tests,W,H,CAPACITY);$finish;
    end
    initial begin #50000000;$fatal(1,"Watchdog");end
endmodule
