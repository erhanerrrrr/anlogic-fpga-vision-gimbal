`timescale 1ns/1ps
module tb_video_buttons_control;
    parameter integer ACTIVE_LOW=1;
    localparam W=16,H=12,N=4;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,abort_in=0,iv=0,s=0,l=0,e=0;
    reg [2:0] keys=0;
    wire [2:0] pins=ACTIVE_LOW?~keys:keys;
    reg [10:0] x=0,y=0;
    reg [31:0] fid=1;
    wire ov,os,ol,oe,oa,invalid,invalid_seen,mode_evt,cal_evt,track_evt;
    wire [2:0] pressed,events;
    wire [23:0] rgb,raw,gray,edge_rgb,mask_rgb;
    wire [1:0] mode,active_mode,next_mode,requested;
    wire [10:0] ox,oy;
    wire [31:0] ofid,epoch;
    wire [15:0] cfg,err,used,peak;
    wire [1:0] color;
    reg check_frame=0;
    reg [1:0] expected_mode=0;
    integer seen=0,frames=0,cycles=0,trace,i,j,pixels_file;
    integer mode_presses=0,cal_presses=0,track_presses=0,old_count=0;
    reg [23:0] expected_rgb;
    reg expected_mask;
    video_button_stream #(.WIDTH(W),.HEIGHT(H),.GUARD_ROWS(1),.MAX_IDLE_CYCLES(64),
        .DEBOUNCE_CYCLES(N),.ACTIVE_LOW(ACTIVE_LOW)) dut(
        .clk(clk),.rst_n(rst_n),.stream_abort(abort_in),.in_valid(iv),.in_sof(s),.in_eol(l),.in_eof(e),
        .in_rgb(24'hc80000),.in_x(x),.in_y(y),.in_epoch(32'd9),.in_frame_id(fid),.in_cfg_id(16'd3),
        .in_target_id(2'd0),.min_main(8'd24),.min_diff_1(8'd16),.min_diff_2(8'd16),.buttons_async(pins),
        .pressed(pressed),.press_event(events),.requested_mode(requested),.mode_next_evt(mode_evt),
        .calibrate_evt(cal_evt),.track_toggle_evt(track_evt),
        .invalid_request(invalid),.invalid_request_seen(invalid_seen),
        .active_input_mode(active_mode),.next_frame_mode(next_mode),.out_valid(ov),.out_rgb(rgb),.out_mode(mode),
        .out_raw_rgb(raw),.out_gray_rgb(gray),.out_edge_rgb(edge_rgb),.out_mask_rgb(mask_rgb),
        .out_sof(os),.out_eol(ol),.out_eof(oe),.out_x(ox),.out_y(oy),.out_epoch(epoch),
        .out_frame_id(ofid),.out_cfg_id(cfg),.out_target_id(color),.out_abort(oa),
        .error_flags(err),.fifo_used(used),.fifo_peak(peak));
    always @(posedge clk)begin
        cycles=cycles+1;
        #1;
        if(!rst_n)begin mode_presses=0;cal_presses=0;track_presses=0;end
        else begin
            if(invalid || invalid_seen)$fatal(1,"Button generated an illegal request");
            if({track_evt,cal_evt,mode_evt}!==events)$fatal(1,"Three-key routing mismatch");
            if(mode_evt)mode_presses=mode_presses+1;
            if(cal_evt)cal_presses=cal_presses+1;
            if(track_evt)track_presses=track_presses+1;
            if(events || (iv && s) || (ov && os) || oa)
                $fwrite(trace,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",cycles,keys,events,requested,iv&&s,active_mode,next_mode,ov&&os,mode,oa);
            if(check_frame)begin
                if(oa)$fatal(1,"Fault during legal button/video frame");
                if(iv && active_mode!==expected_mode)$fatal(1,"Button changed mode inside a frame");
                if(ov)begin
                    expected_mask=ox>0 && ox<W-1 && oy>0 && oy<H-1;
                    if(raw!==24'hc80000 || gray!==24'h3c3c3c || edge_rgb!==24'd0 || mask_rgb!=={24{expected_mask}})
                        $fatal(1,"Button affected candidate pixels or C input");
                    case(expected_mode)
                        0:expected_rgb=24'hc80000;
                        1:expected_rgb=24'h3c3c3c;
                        2:expected_rgb=0;
                        3:expected_rgb={24{expected_mask}};
                    endcase
                    if(mode!==expected_mode || rgb!==expected_rgb || ox!==seen%W || oy!==seen/W ||
                        {epoch,ofid,cfg,color}!=={32'd9,fid,16'd3,2'd0} ||
                        os!==(seen==0) || ol!==(seen%W==W-1) || oe!==(seen==W*H-1))
                        $fatal(1,"Button/video output mismatch frame=%d pixel=%d",fid,seen);
                    $fwrite(pixels_file,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
                    seen=seen+1;
                end
            end
        end
    end
    task idle;begin @(negedge clk);iv=0;s=0;l=0;e=0;abort_in=0;end endtask
    task hold_keys;input [2:0] value;input integer n;begin
        repeat(n)begin idle();keys=value;@(posedge clk);#2;end
    end endtask
    task press;input [2:0] value;begin hold_keys(0,N+4);hold_keys(value,N+4);hold_keys(0,N+4);end endtask
    task drive;input integer a,b;begin
        @(negedge clk);iv=1;x=a;y=b;s=a==0 && b==0;l=a==W-1;e=l && b==H-1;
    end endtask
    task frame;input [1:0] wanted;input integer mid_press;begin
        expected_mode=wanted;seen=0;fid=fid+1;check_frame=1;
        for(j=0;j<H;j=j+1)for(i=0;i<W;i=i+1)begin
            drive(i,j);
            if(mid_press && i==0 && j==1)keys=1;
            if(mid_press && i==0 && j==2)keys=0;
        end
        repeat(W+16)idle();check_frame=0;
        if(seen!=W*H || used!=0)$fatal(1,"Incomplete button/video frame");
        frames=frames+1;
    end endtask
    initial begin
        pixels_file=$fopen("actual.rgb","wb");
        trace=$fopen("button_video_timing.csv","w");
        $fwrite(trace,"cycle,normalized_keys,event,requested_mode,input_sof,active_input_mode,next_frame_mode,output_sof,out_mode,abort\n");
        hold_keys(0,3);rst_n=1;hold_keys(0,3);frame(0,0);
        // Each press advances the requested mode even when no SOF has occurred.
        press(1);press(1);
        if(requested!=2 || next_mode!=2 || active_mode!=0 || mode_presses!=2)$fatal(1,"Two pre-SOF presses collapsed");
        frame(2,0);
        // Independent calibration/track events and simultaneous presses.
        press(6);
        if(requested!=2 || cal_presses!=1 || track_presses!=1)$fatal(1,"Other keys changed mode or lost routing");
        frame(2,1); // press #3 during a frame, which must stay EDGE
        if(next_mode!=3 || requested!=3)$fatal(1,"Mid-frame button request missing");
        frame(3,0);
        // Make the consumer's request edge coincide exactly with input SOF.
        hold_keys(0,N+4);idle();keys=1;
        while(!events[0])begin @(posedge clk);#2;end
        frame(3,0); // consumes press #4 on SOF, so this frame still uses MASK
        if(requested!=0 || next_mode!=0 || mode_presses!=4)$fatal(1,"SOF-coincident press or long hold handling");
        hold_keys(0,N+4);frame(0,0);
        press(7);
        if(requested!=1 || cal_presses!=2 || track_presses!=2)$fatal(1,"Simultaneous three-key routing");
        frame(1,0);
        // An aborted partial frame does not rearm a continuously held key.
        hold_keys(1,N+4);old_count=mode_presses;fid=fid+1;
        drive(0,0);drive(1,0);idle();abort_in=1;
        repeat(6)idle();hold_keys(1,3*N+4);
        if(mode_presses!=old_count || requested!=2 || oa)$fatal(1,"Video abort repeated a held key");
        frame(2,0);hold_keys(0,N+4);
        // External reset reinitializes buttons and recognizes a held key once.
        rst_n=0;hold_keys(1,3);rst_n=1;hold_keys(1,N+4);
        if(mode_presses!=1 || requested!=1 || active_mode!=0 || next_mode!=1)$fatal(1,"Reset-held key semantics");
        frame(1,0);hold_keys(0,N+4);
        if(frames!=9)$fatal(1,"Missing full-frame coverage");
        $fclose(pixels_file);$fclose(trace);$display("PASS VIDEO_BUTTONS: frames=%0d polarity=%0d",frames,ACTIVE_LOW);$finish;
    end
    initial begin #1000000;$fatal(1,"Watchdog");end
endmodule
