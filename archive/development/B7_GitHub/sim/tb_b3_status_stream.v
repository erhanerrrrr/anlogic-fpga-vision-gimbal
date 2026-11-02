`timescale 1ns/1ps
module tb_b3_status_stream;
    parameter integer WIDTH=976,HEIGHT=480,NFRAMES=4;
    localparam integer N=4;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,iv=0,sof=0,eol=0,eof=0,abort_in=0;
    reg [10:0] x=0,y=0;
    reg [31:0] fid=0;
    reg [2:0] keys=0;
    wire [2:0] pins=~keys;
    reg roi_req_valid=0,roi_req_enable=0;
    reg [50:0] cal_packet=0,cal_packets[0:3];
    reg [37:0] tracking_packet=0,tracking_packets[0:3];
    reg [1:0] expected_modes[0:3];
    wire [2:0] events;
    wire mode_evt,cal_evt,track_evt,ov,os,ol,oe,oa;
    wire [10:0] ox,oy;
    wire [23:0] orgb;
    wire [31:0] epoch,ofid;
    wire [15:0] cfg,errors,used,peak;
    wire [1:0] target,mode;
    wire [50:0] out_cal;
    wire [37:0] out_tracking;
    integer fd,seen=0,output_frames=0,input_frames=0,i,j,cycles=0,mode_presses=0;
    video_b3_status_stream #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.GUARD_ROWS(1),
        .DEBOUNCE_CYCLES(N),.ACTIVE_LOW(1),.MAX_IDLE_CYCLES(4096)) dut(
        .clk(clk),.rst_n(rst_n),.stream_abort(abort_in),
        .in_valid(iv),.in_sof(sof),.in_eol(eol),.in_eof(eof),.in_x(x),.in_y(y),.in_rgb(24'hc80000),
        .in_epoch(32'd9),.in_frame_id(fid),.in_cfg_id(16'd3),.in_target_id(2'd0),
        .min_main(8'd24),.min_diff_1(8'd16),.min_diff_2(8'd16),.buttons_async(pins),
        .roi_req_valid(roi_req_valid),.roi_req_enable(roi_req_enable),
        .calibration_status_packet(cal_packet),.tracking_packet(tracking_packet),
        .press_event(events),.mode_next_evt(mode_evt),.calibrate_evt(cal_evt),.track_toggle_evt(track_evt),
        .out_valid(ov),.out_sof(os),.out_eol(ol),.out_eof(oe),.out_x(ox),.out_y(oy),.out_rgb(orgb),
        .out_epoch(epoch),.out_frame_id(ofid),.out_cfg_id(cfg),.out_target_id(target),.out_mode(mode),
        .out_abort(oa),.error_flags(errors),.fifo_used(used),.fifo_peak(peak),
        .out_calibration_status(out_cal),.out_tracking_status(out_tracking));
    always @(posedge clk)begin
        cycles=cycles+1;
        #2;
        if(rst_n)begin
            if(mode_evt)mode_presses=mode_presses+1;
            if(cal_evt || track_evt || events[2:1])$fatal(1,"other button event");
            if(oa)$fatal(1,"legal combined stream aborted cycle=%0d errors=%h",cycles,errors);
            if(ov)begin
                if(output_frames>=NFRAMES)$fatal(1,"unexpected frame");
                if(ox!==seen%WIDTH || oy!==seen/WIDTH || mode!==expected_modes[output_frames] ||
                    {epoch,ofid,cfg,target}!=={32'd9,32'(output_frames+1),16'd3,2'd0} ||
                    os!==(seen==0) || ol!==(seen%WIDTH==WIDTH-1) || oe!==(seen==WIDTH*HEIGHT-1) ||
                    out_cal!==cal_packets[output_frames] || out_tracking!==tracking_packets[output_frames])
                    $fatal(1,"metadata mismatch frame=%0d pixel=%0d xy=%0d,%0d mode=%0d cal=%h expected=%h track=%h expected=%h",
                        output_frames,seen,ox,oy,mode,out_cal,cal_packets[output_frames],out_tracking,tracking_packets[output_frames]);
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
    task hold;input [2:0] value;input integer count;integer k;begin
        for(k=0;k<count;k=k+1)begin idle();keys=value;end
    end endtask
    task press_mode;begin hold(0,N+4);hold(1,N+4);hold(0,N+4);end endtask
    task frame;input integer index;begin
        if(index>0)press_mode();
        fid=index+1;cal_packet=cal_packets[index];tracking_packet=tracking_packets[index];
        for(j=0;j<HEIGHT;j=j+1)begin
            for(i=0;i<WIDTH;i=i+1)begin
                @(negedge clk);iv=1;x=i;y=j;sof=(i==0 && j==0);eol=(i==WIDTH-1);eof=eol && j==HEIGHT-1;
                if(i==0 && j==HEIGHT/2)begin
                    // Control changes mid-display-frame may be seen on wires,
                    // but the frame's status snapshot must remain unchanged.
                    cal_packet=cal_packets[(index+1)%NFRAMES];
                    tracking_packet=tracking_packets[(index+1)%NFRAMES];
                    if(index==2 && NFRAMES==4)begin roi_req_valid=1;roi_req_enable=0;end
                end
                if(i==1 && j==HEIGHT/2)roi_req_valid=0;
            end
            idle(); // one blank cycle per line
        end
        idle();
        while(output_frames<=index)idle();
        if(used!=0 || errors!=0)$fatal(1,"FIFO/errors after frame %0d: used=%0d errors=%h",index,used,errors);
        input_frames=input_frames+1;
    end endtask
    initial begin
        fd=$fopen("actual.rgb","wb");if(!fd)$fatal(1,"output open");
        `include "b3f_scenarios.vh"
        hold(0,3);rst_n=1;hold(0,4);
        roi_req_enable=1;roi_req_valid=1;idle();roi_req_valid=0;
        for(integer n=0;n<NFRAMES;n=n+1)frame(n);
        hold(0,4);
        if(output_frames!=NFRAMES || input_frames!=NFRAMES || mode_presses!=NFRAMES-1)$fatal(1,"frame/button count");
        $fclose(fd);
        $display("PASS B3F_COMBINED: frames=%0d pixels=%0d peak=%0d",output_frames,NFRAMES*WIDTH*HEIGHT,peak);$finish;
    end
    initial begin #60000000;$fatal(1,"watchdog");end
endmodule
