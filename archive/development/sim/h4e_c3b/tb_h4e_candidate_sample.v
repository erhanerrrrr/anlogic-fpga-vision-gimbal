`timescale 1ns/1ps
module tb_h4e_roi_sampler;
parameter W=32,H=32;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=1,sample_req=0,source_flush=0;
    reg [31:0] active_epoch=7,source_epoch=7,source_frame_id=0;
    reg [15:0] requested_cfg_id=1;
    reg [1:0] requested_color=0;
    reg pixel_valid=0,sof=0,eof=0;
    reg [23:0] rgb=0;
    reg [10:0] x=0,y=0;
    wire accepted_sof,new_source_sof,frame_abort;
    wire busy;
    wire request_ignored,sample_done,sample_ok;
    wire [1:0] sample_reason;
    wire [31:0] sample_frame_id,sample_epoch;
    wire [15:0] sample_cfg_id;
    wire [1:0] sample_target_id;
    wire [8:0] sample_count;
    wire [15:0] sum_r,sum_g,sum_b;
    wire [7:0] min_r,min_g,min_b,max_r,max_g,max_b;
    wire [7:0] mean_r,mean_g,mean_b;
    capture_frame_guard #(.WIDTH(W),.HEIGHT(H)) guard(
        .clk(clk),.rst_n(rst_n),.source_flush(source_flush),.active_epoch(active_epoch),
        .pixel_valid(pixel_valid),.sof(sof),.eof(eof),.rgb(rgb),.x(x),.y(y),
        .source_frame_id(source_frame_id),.source_epoch(source_epoch),
        .requested_cfg_id(requested_cfg_id),.requested_color(requested_color),
        .requested_min_main(8'd24),.requested_min_diff_1(8'd16),.requested_min_diff_2(8'd16),
        .candidate_strobe(1'b0),.candidate_frame_id(32'd0),.candidate_cfg_id(16'd0),.candidate_target_id(2'd0),
        .accepted_sof(accepted_sof),.new_source_sof(new_source_sof),.frame_abort(frame_abort));
    h4e_roi_sampler #(.WIDTH(W),.HEIGHT(H)) dut(
        .clk(clk),
        .rst_n(rst_n),
        .sample_req(sample_req),
        .source_flush(source_flush),
        .active_epoch(active_epoch),
        .source_epoch(source_epoch),
        .source_frame_id(source_frame_id),
        .requested_cfg_id(requested_cfg_id),
        .requested_color(requested_color),
        .accepted_sof(accepted_sof),
        .new_source_sof(new_source_sof),
        .frame_abort(frame_abort),
        .pixel_valid(pixel_valid),
        .sof(sof),
        .eof(eof),
        .rgb(rgb),
        .x(x),
        .y(y),
        .busy(busy),
        .request_ignored(request_ignored),
        .sample_done(sample_done),
        .sample_ok(sample_ok),
        .sample_reason(sample_reason),
        .sample_frame_id(sample_frame_id),
        .sample_epoch(sample_epoch),
        .sample_cfg_id(sample_cfg_id),
        .sample_target_id(sample_target_id),
        .sample_count(sample_count),
        .sum_r(sum_r),
        .sum_g(sum_g),
        .sum_b(sum_b),
        .min_r(min_r),
        .min_g(min_g),
        .min_b(min_b),
        .max_r(max_r),
        .max_g(max_g),
        .max_b(max_b),
        .mean_r(mean_r),
        .mean_g(mean_g),
        .mean_b(mean_b));

    integer events=0,ignored=0,tag=0,fd;
    wire calibration_done,calibration_ok;
    wire [2:0] calibration_reason;
    wire [31:0] calibration_frame_id,calibration_epoch;
    wire [15:0] calibration_cfg_id;
    wire [1:0] calibration_target_id,candidate_color;
    wire [7:0] candidate_min_main,candidate_diff_1,candidate_diff_2;
 h4e_calibration_candidate candidate(.clk(clk),.rst_n(rst_n),.source_flush(source_flush),.active_epoch(active_epoch),.sample_done(sample_done),.sample_ok(sample_ok),.sample_count(sample_count),.sample_frame_id(sample_frame_id),.sample_epoch(sample_epoch),.sample_cfg_id(sample_cfg_id),.sample_target_id(sample_target_id),.mean_r(mean_r),.mean_g(mean_g),.mean_b(mean_b),.min_r(min_r),.min_g(min_g),.min_b(min_b),.max_r(max_r),.max_g(max_g),.max_b(max_b),.calibration_done(calibration_done),.calibration_ok(calibration_ok),.calibration_reason(calibration_reason),.calibration_frame_id(calibration_frame_id),.calibration_epoch(calibration_epoch),.calibration_cfg_id(calibration_cfg_id),.calibration_target_id(calibration_target_id),.candidate_color(candidate_color),.candidate_min_main(candidate_min_main),.candidate_diff_1(candidate_diff_1),.candidate_diff_2(candidate_diff_2));
 integer cf;initial begin cf=$fopen("candidate_samples.csv","w");$fdisplay(cf,"tag,ok,reason,fid,epoch,cfg,target,color,main,d1,d2");end
 always @(posedge clk) begin #2;if(calibration_done) $fdisplay(cf,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",tag,calibration_ok,calibration_reason,calibration_frame_id,calibration_epoch,calibration_cfg_id,calibration_target_id,candidate_color,candidate_min_main,candidate_diff_1,candidate_diff_2);end


    always @(posedge clk) begin
        #1;
        if(request_ignored) ignored=ignored+1;
        if(sample_done) begin
            events=events+1;
            $fdisplay(fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",tag,sample_ok,sample_reason,sample_frame_id,sample_epoch,sample_cfg_id,sample_target_id,sample_count,sum_r,sum_g,sum_b,min_r,min_g,min_b,max_r,max_g,max_b,mean_r,mean_g);
            $display("BMEAN %0d %0d",tag,mean_b);
        end
    end
    task idle; input integer n; integer i; begin
        for(i=0;i<n;i=i+1) begin @(negedge clk);pixel_valid=0;sof=0;eof=0;sample_req=0;end
    end endtask
    task req; begin @(negedge clk);sample_req=1; @(negedge clk);sample_req=0;end endtask
    task frame; input integer fid,pattern,limit,mode; integer xx,yy,k; reg [7:0] r,g,b; begin
        k=0;
        for(yy=0;yy<H;yy=yy+1) for(xx=0;xx<W;xx=xx+1) if(k<limit) begin
            @(negedge clk);pixel_valid=1;sof=(k==0);eof=(k==W*H-1);x=xx;y=yy;
            source_frame_id=fid;source_epoch=active_epoch;
            sample_req=(mode==1 && k==0)||(mode==2 && k==W*H-1);
            r=0;g=255;b=1;
            if(xx>=(W-16)/2 && xx<(W-16)/2+16 && yy>=(H-16)/2 && yy<(H-16)/2+16) begin
                case(pattern)
                    0:begin r=220;g=30;b=10;end
                    1:begin r=20;g=200;b=40;end
                    2:begin r=15;g=25;b=210;end
                    3:begin r=255;g=255;b=255;end
                    4:begin r=(xx-(W-16)/2)*16+yy-(H-16)/2;g=255-r;b=r/2;end
                    5:begin r=xx<(W/2)?20:201;g=xx<(W/2)?50:100;b=xx<(W/2)?230:3;end
                endcase
            end
            rgb={r,g,b};k=k+1;
        end
    end endtask
    integer before_events;
    initial begin
        fd=$fopen("samples.csv","w");
        $fdisplay(fd,"tag,ok,reason,fid,epoch,cfg,color,count,sr,sg,sb,lr,lg,lb,hr,hg,hb,mr,mg");
        #1;rst_n=0;idle(2);rst_n=1;
        // Request on SOF skips that frame; consecutive repeat also skips.
        tag=1;frame(10,0,W*H,1);idle(3);
        if(events!=0 || !busy) $fatal(1,"same edge request");
        frame(10,0,W*H,0);idle(3);if(events!=0) $fatal(1,"repeat");
        frame(11,0,W*H,2);idle(3);if(events!=1 || ignored!=1) $fatal(1,"first sample/busy");
        tag=2;req;frame(12,1,W*H,0);idle(3);
        tag=3;req;frame(13,2,W*H,0);idle(3);
        tag=4;req;frame(14,3,W*H,0);idle(3);
        tag=5;req;frame(15,4,W*H,0);idle(3);
        tag=6;req;frame(16,5,W*H,0);idle(3);
        if(W<100) begin
            // Midrow gap after full ROI: cannot publish success.
            tag=7;req;frame(17,0,W*(H-2)+5,0);idle(4);
            tag=8;req;frame(17,0,W*H,0);idle(3);
            if(!busy || events!=7) $fatal(1,"retry repeated identity");
            frame(18,1,W*H,0);idle(3);
            // Flush while waiting; no captured identity.
            tag=9;req;@(negedge clk);source_flush=1;idle(2);source_flush=0;
            // Epoch revoke after ROI but before EOF.
            tag=10;req;frame(19,0,W*(H-2),0);@(negedge clk);active_epoch=8;pixel_valid=0;idle(3);
            // Same numeric frame ID in a new epoch is eligible.
            tag=11;req;frame(19,2,W*H,0);idle(3);
            // New SOF interrupts and is not queued for current request.
            tag=12;req;frame(20,0,W,0);frame(21,0,W*H,0);idle(3);
            // Bad EOF at a nonfinal coordinate.
            tag=13;req;frame(22,0,W,0);@(negedge clk);x=0;y=1;sof=0;eof=1;idle(4);
            // Reset silently clears a waiting request.
            before_events=events;req;@(negedge clk);rst_n=0;idle(2);rst_n=1;idle(2);
            if(busy || sample_done) $fatal(1,"reset waiting");
            // Reset silently clears an active sample.
            req;frame(23,0,W,0);@(negedge clk);rst_n=0;pixel_valid=0;idle(2);rst_n=1;idle(2);
            if(busy || events!=before_events) $fatal(1,"reset active");
            // Busy request on completion edge is ignored.
            tag=14;req;frame(24,0,W*H,0);@(negedge clk);pixel_valid=0;sof=0;eof=0;sample_req=1;idle(3);
            if(ignored!=2 || busy) $fatal(1,"completion request");
        end
        $display("C3A_PASS events=%0d ignored=%0d W=%0d H=%0d",events,ignored,W,H);
        $fclose(fd);$finish;
    end
endmodule
