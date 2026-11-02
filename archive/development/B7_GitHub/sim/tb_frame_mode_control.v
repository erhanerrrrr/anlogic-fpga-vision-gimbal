`timescale 1ns/1ps
module tb_frame_mode_control;
    localparam W=16,H=12;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,abort_in=0,iv=0,s=0,l=0,e=0,rv=0;
    reg [2:0] req=0;
    reg [10:0] x=0,y=0;
    reg [31:0] fid=1;
    wire ov,os,ol,oe,oa,invalid,invalid_seen;
    wire [23:0] rgb;
    wire [1:0] mode,active_mode,next_mode;
    wire [10:0] ox,oy;
    wire [31:0] ofid,epoch;
    wire [15:0] cfg,err,used,peak;
    wire [1:0] color;
    reg check_frame=0;
    reg [1:0] expected_mode=0;
    integer seen=0,frames=0,aborts=0,cycles=0,trace,i,j,k;
    reg [23:0] expected_rgb;
    video_frame_mode_stream #(.WIDTH(W),.HEIGHT(H),.GUARD_ROWS(1),.MAX_IDLE_CYCLES(64)) dut(
        .clk(clk),.rst_n(rst_n),.stream_abort(abort_in),.in_valid(iv),.in_sof(s),.in_eol(l),.in_eof(e),
        .in_rgb(24'hc80000),.in_x(x),.in_y(y),.in_epoch(32'd9),.in_frame_id(fid),.in_cfg_id(16'd3),
        .in_target_id(2'd0),.min_main(8'd24),.min_diff_1(8'd16),.min_diff_2(8'd16),
        .mode_req_valid(rv),.mode_req(req),.invalid_request(invalid),.invalid_request_seen(invalid_seen),
        .active_input_mode(active_mode),.next_frame_mode(next_mode),.out_valid(ov),.out_rgb(rgb),.out_mode(mode),
        .out_raw_rgb(),.out_gray_rgb(),.out_edge_rgb(),.out_mask_rgb(),.out_sof(os),.out_eol(ol),.out_eof(oe),
        .out_x(ox),.out_y(oy),.out_epoch(epoch),.out_frame_id(ofid),.out_cfg_id(cfg),.out_target_id(color),
        .out_abort(oa),.error_flags(err),.fifo_used(used),.fifo_peak(peak));
    always @(posedge clk)begin
        cycles=cycles+1;
        #1;
        if(rst_n)begin
            if(invalid!==(rv && req[2]))$fatal(1,"Illegal request pulse");
            if(oa)aborts=aborts+1;
            if(rv || s || (ov && os) || oa)
                $fwrite(trace,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",cycles,rv,req,iv&&s,active_mode,next_mode,ov&&os,mode,oa,err);
            if(check_frame)begin
                if(oa)$fatal(1,"Fault during legal frame");
                if(iv && active_mode!==expected_mode)$fatal(1,"Changed input frame mode");
                if(ov)begin
                    case(expected_mode)
                        0:expected_rgb=24'hc80000;
                        1:expected_rgb=24'h3c3c3c;
                        2:expected_rgb=0;
                        3:expected_rgb=(ox>0 && ox<W-1 && oy>0 && oy<H-1)?24'hffffff:24'd0;
                    endcase
                    if(mode!==expected_mode || rgb!==expected_rgb || ox!==seen%W || oy!==seen/W ||
                        {epoch,ofid,cfg,color}!=={32'd9,fid,16'd3,2'd0} ||
                        os!==(seen==0) || ol!==(seen%W==W-1) || oe!==(seen==W*H-1))
                        $fatal(1,"Recovery output mismatch frame=%d pixel=%d mode=%d expected=%d",fid,seen,mode,expected_mode);
                    seen=seen+1;
                end
            end
        end
    end
    task idle;begin @(negedge clk);iv=0;s=0;l=0;e=0;rv=0;abort_in=0;end endtask
    task request;input [2:0] value;begin idle();rv=1;req=value;idle();end endtask
    task drive;input integer a,b;begin
        @(negedge clk);iv=1;x=a;y=b;s=a==0 && b==0;l=a==W-1;e=l && b==H-1;rv=0;
    end endtask
    task reset;begin
        check_frame=0;idle();rst_n=0;repeat(3)idle();rst_n=1;repeat(2)idle();
        if(active_mode!=0 || next_mode!=0 || invalid_seen || err || ov)$fatal(1,"Reset did not clear mode and diagnostics");
    end endtask
    task frame;
        input [1:0] wanted;
        input integer sof_request,mid_request;
        begin
            expected_mode=wanted;seen=0;fid=fid+1;check_frame=1;
            for(j=0;j<H;j=j+1)for(i=0;i<W;i=i+1)begin
                drive(i,j);
                if(i==0 && j==0 && sof_request>=0)begin rv=1;req=sof_request;end
                if(i==3 && j==2 && mid_request>=0)begin rv=1;req=mid_request;end
            end
            repeat(W+16)idle();check_frame=0;
            if(seen!=W*H || used!=0)$fatal(1,"Incomplete frame");
            frames=frames+1;
        end
    endtask
    task expect_fault;input [15:0] mask;begin
        repeat(6)idle();
        if((err&mask)!=mask || used!=0 || ov || oa)$fatal(1,"Missing fault or failure to clear");
    end endtask
    initial begin
        trace=$fopen("control_timing.csv","w");
        $fwrite(trace,"cycle,req_valid,req,input_sof,active_input_mode,next_frame_mode,output_sof,out_mode,abort,errors\n");
        reset();
        request(1);idle();s=1;iv=0;idle();
        if(active_mode!=0 || next_mode!=1)$fatal(1,"Invalid SOF consumed request");
        frame(1,-1,-1);
        request(2);request(0);request(3);
        for(k=4;k<8;k=k+1)request(k);
        if(next_mode!=3 || !invalid_seen)$fatal(1,"Illegal request replaced legal pending");
        frame(3,1,-1); // existing 3 wins this SOF; simultaneous 1 stays pending
        if(next_mode!=1)$fatal(1,"Lost SOF-simultaneous request");
        frame(1,-1,2);frame(2,-1,-1);
        // A request on abort is retained; aborted video does not reset controls.
        idle();abort_in=1;rv=1;req=3;idle();repeat(4)idle();
        drive(4,5);drive(5,5);repeat(4)idle();
        if(active_mode!=2 || next_mode!=3 || ov)$fatal(1,"Abort/remnants consumed pending");
        frame(3,-1,-1);
        // Structurally invalid SOF must fail video and must not commit a mode.
        request(1);drive(1,0);s=1;expect_fault(16'h0001);
        if(active_mode!=3 || next_mode!=1)$fatal(1,"Malformed SOF consumed request");
        frame(1,-1,-1);
        // A premature SOF in a partial frame also cannot commit pending mode.
        drive(0,0);drive(1,0);rv=1;req=2;drive(0,0);expect_fault(16'h0001);
        if(active_mode!=1 || next_mode!=2)$fatal(1,"Early SOF consumed request");
        frame(2,-1,-1);
        // Row-boundary timeout retains a request for a later complete frame.
        for(i=0;i<W;i=i+1)drive(i,0);
        request(3);repeat(68)idle();expect_fault(16'h0020);
        if(next_mode!=3)$fatal(1,"Timeout lost pending request");
        frame(3,-1,-1);
        request(1);reset();frame(0,-1,-1);
        if(frames!=9 || aborts==0)$fatal(1,"Missing scenario coverage");
        $fclose(trace);$display("PASS FRAME_MODE_CONTROL: frames=%0d",frames);$finish;
    end
    initial begin #1000000;$fatal(1,"Watchdog");end
endmodule
