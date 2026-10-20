`timescale 1ns/1ps
// Two displays of one source. H4E consumes the public filtered-mask port.
module tb_b3g5_formal_mask_port;
    localparam integer WIDTH=976,HEIGHT=480;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,iv=0,sof=0,eol=0,eof=0;
    reg [10:0] x=0,y=0;
    reg [23:0] rgb=0;
    wire c_strobe,c_valid,c_busy;
    wire [2:0] c_reason;
    wire [31:0] c_frame;
    wire [15:0] c_cfg;
    wire [1:0] c_target;
    wire [19:0] c_area;
    wire [10:0] c_xmin,c_ymin,c_xmax,c_ymax,c_cx,c_cy;
    wire [7:0] c_slots;
    wire [11:0] c_components;
    wire [159:0] c_packet={c_frame,c_cfg,c_target,c_valid,c_area,
        c_xmin,c_ymin,c_xmax,c_ymax,c_cx,c_cy,c_reason,c_slots,c_components};
    wire ov,os,ol,oe,oa,ready;
    wire [10:0] ox,oy;
    wire [23:0] orgb;
    wire [31:0] epoch,ofid;
    wire [15:0] cfg,errors,used,peak;
    wire [1:0] target,mode;
    wire [50:0] cal_status;
    wire [37:0] track_status;
    wire [159:0] result_packet;
    wire [2:0] events;
    wire mode_evt,cal_evt,track_evt;
    wire dv,dm,ds,dl,de;
    wire [10:0] dx,dy;
    wire [31:0] depoch,dframe;
    wire [15:0] dcfg;
    wire [1:0] dtarget;
    video_b3_target_stream #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.GUARD_ROWS(4),
        .DEBOUNCE_CYCLES(4),.MAX_IDLE_CYCLES(4096)) dut(
        .clk(clk),.rst_n(rst_n),.stream_abort(1'b0),
        .in_valid(iv),.in_sof(sof),.in_eol(eol),.in_eof(eof),
        .in_x(x),.in_y(y),.in_rgb(rgb),.in_epoch(32'd9),.in_frame_id(32'd42),
        .in_cfg_id(16'd3),.in_target_id(2'd0),
        .min_main(8'd24),.min_diff_1(8'd16),.min_diff_2(8'd16),
        .buttons_async(3'b111),.roi_req_valid(1'b0),.roi_req_enable(1'b0),
        .calibration_status_packet(51'd0),.tracking_packet(38'd0),
        .result_strobe(c_strobe),.target_valid(c_valid),
        .result_epoch(32'd9),.result_frame_id(c_frame),.result_cfg_id(c_cfg),
        .result_target_id(c_target),.area(c_area),
        .xmin(c_xmin),.ymin(c_ymin),.xmax(c_xmax),.ymax(c_ymax),
        .cx(c_cx),.cy(c_cy),.reason(c_reason),
        .labels_used(c_slots),.components(c_components),
        .source_timeout(1'b0),.result_timeout(1'b0),
        .press_event(events),.mode_next_evt(mode_evt),
        .calibrate_evt(cal_evt),.track_toggle_evt(track_evt),
        .out_valid(ov),.out_sof(os),.out_eol(ol),.out_eof(oe),
        .out_x(ox),.out_y(oy),.out_rgb(orgb),
        .out_epoch(epoch),.out_frame_id(ofid),.out_cfg_id(cfg),
        .out_target_id(target),.out_mode(mode),.out_abort(oa),
        .detect_valid(dv),.detect_mask(dm),
        .detect_sof(ds),.detect_eol(dl),.detect_eof(de),
        .detect_x(dx),.detect_y(dy),
        .detect_epoch(depoch),.detect_frame_id(dframe),
        .detect_cfg_id(dcfg),.detect_target_id(dtarget),
        .error_flags(errors),.fifo_used(used),.fifo_peak(peak),
        .out_calibration_status(cal_status),.out_tracking_status(track_status),
        .out_snapshot_ready(ready),.out_result_packet(result_packet));
    // Public port is a same-clock, synthesizable wire bundle. A still owns
    // capture identity binding and atomic cross-clock result transfer.
    h4e_region_select #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) c_selector(
        .clk(clk),.rst_n(rst_n),
        .mask_valid(dv),.mask(dm),.sof(ds),.eof(de),
        .x(dx),.y(dy),.frame_id(dframe),
        .cfg_id(dcfg),.target_id(dtarget),
        .result_strobe(c_strobe),.target_valid(c_valid),.reason(c_reason),
        .result_frame_id(c_frame),.result_cfg_id(c_cfg),.result_target_id(c_target),
        .area(c_area),.xmin(c_xmin),.ymin(c_ymin),.xmax(c_xmax),.ymax(c_ymax),
        .cx(c_cx),.cy(c_cy),.labels_used(c_slots),.components(c_components),.busy(c_busy));
    integer fd,seen=0,output_frames=0,c_events=0,cycles=0;
    reg [159:0] first_c_packet=0;
    always @(posedge clk)begin
        cycles=cycles+1;
        #2;
        if(rst_n)begin
            if(dv && ({depoch,dframe,dcfg,dtarget}!=={32'd9,32'd42,16'd3,2'd0} ||
                ds!==(dx==0 && dy==0) || dl!==(dx==WIDTH-1) ||
                de!==(dx==WIDTH-1 && dy==HEIGHT-1)))
                $fatal(1,"public detect port metadata mismatch");
            if(c_strobe)begin
                c_events=c_events+1;
                if(c_events==1)begin
                    first_c_packet=c_packet;
                    if(c_frame!==42 || c_cfg!==3 || c_target!==0 || !c_valid ||
                        c_reason!==0 || c_area!==20'd9996 ||
                        {c_xmin,c_ymin,c_xmax,c_ymax,c_cx,c_cy}!==
                        {11'd300,11'd250,11'd399,11'd349,11'd349,11'd299})
                        $fatal(1,"C result geometry mismatch %h",c_packet);
                end
            end
            if(oa || errors!=0)$fatal(1,"video abort/errors cycle=%0d errors=%h",cycles,errors);
            if(ov)begin
                if(output_frames>1 || ox!==seen%WIDTH || oy!==seen/WIDTH ||
                   {epoch,ofid,cfg,target,mode}!=={32'd9,32'd42,16'd3,2'd0,2'd0} ||
                   os!==(seen==0) || ol!==(seen%WIDTH==WIDTH-1) ||
                   oe!==(seen==WIDTH*HEIGHT-1) || cal_status!==0 || track_status!==0)
                    $fatal(1,"pixel metadata mismatch frame=%0d pixel=%0d",output_frames,seen);
                if(output_frames==0)begin
                    if(ready || result_packet[109] || result_packet[22:20]!==3'd4)
                        $fatal(1,"first display showed unfinished target");
                end else if(!ready || result_packet!==first_c_packet)
                    $fatal(1,"repeat display did not use first C result %h/%h",result_packet,first_c_packet);
                $fwrite(fd,"%c%c%c",orgb[23:16],orgb[15:8],orgb[7:0]);
                seen=seen+1;
                if(oe)begin
                    if(seen!=WIDTH*HEIGHT)$fatal(1,"short frame");
                    seen=0;output_frames=output_frames+1;
                end
            end
        end
    end
    task idle;begin @(negedge clk);iv=0;sof=0;eol=0;eof=0;end endtask
    task frame;input integer index;integer xx,yy;begin
        for(yy=0;yy<HEIGHT;yy=yy+1)begin
            for(xx=0;xx<WIDTH;xx=xx+1)begin
                @(negedge clk);iv=1;x=xx;y=yy;
                sof=(xx==0 && yy==0);eol=(xx==WIDTH-1);
                eof=eol && yy==HEIGHT-1;
                rgb=(xx>=300 && xx<=399 && yy>=250 && yy<=349) ? 24'hc80000 : 24'h000000;
            end
            idle();
        end
        idle();
        while(output_frames<=index || (index==0 && c_events==0))idle();
        repeat(4)idle();
        if(used!=0 || errors!=0)$fatal(1,"FIFO not empty/error after frame");
    end endtask
    initial begin
        fd=$fopen("actual.rgb","wb");if(!fd)$fatal(1,"cannot open RGB output");
        repeat(3)idle();rst_n=1;repeat(5)idle();
        frame(0);frame(1);
        $fclose(fd);
        if(output_frames!=2 || c_events<1)$fatal(1,"frame/result count");
        $display("PASS B3G5_FORMAL_MASK_PORT: 2 frames, %0d pixels, C result events=%0d peak=%0d",
            2*WIDTH*HEIGHT,c_events,peak);
        $finish;
    end
    initial begin #50000000;$fatal(1,"watchdog");end
endmodule
