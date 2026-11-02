// B3g2 display-only composition in one pixel clock domain. A/C must deliver
// coherent status packets; no cross-clock transfer or HDMI timing lives here.
module video_b3_target_stream #(
    parameter integer WIDTH=1280,HEIGHT=720,GUARD_ROWS=4,
    parameter integer DEBOUNCE_CYCLES=750000,ACTIVE_LOW=1,
    parameter integer FIFO_DEPTH=(1 << $clog2(WIDTH+8)),MAX_IDLE_CYCLES=4096,
    parameter [10:0] THRESHOLD=11'd128
)(
    input wire clk,rst_n,stream_abort,
    input wire in_valid,in_sof,in_eol,in_eof,
    input wire [10:0] in_x,in_y,
    input wire [23:0] in_rgb,
    input wire [31:0] in_epoch,in_frame_id,
    input wire [15:0] in_cfg_id,
    input wire [1:0] in_target_id,
    input wire [7:0] min_main,min_diff_1,min_diff_2,
    input wire [2:0] buttons_async,
    input wire roi_req_valid,roi_req_enable,
    input wire [50:0] calibration_status_packet,
    input wire [37:0] tracking_packet,
    input wire result_strobe,target_valid,
    input wire [31:0] result_epoch,result_frame_id,
    input wire [15:0] result_cfg_id,
    input wire [1:0] result_target_id,
    input wire [19:0] area,
    input wire [10:0] xmin,ymin,xmax,ymax,cx,cy,
    input wire [2:0] reason,
    input wire [7:0] labels_used,
    input wire [11:0] components,
    input wire source_timeout,result_timeout,
    output wire [2:0] press_event,
    output wire mode_next_evt,calibrate_evt,track_toggle_evt,
    output wire out_valid,out_sof,out_eol,out_eof,
    output wire [10:0] out_x,out_y,
    output wire [23:0] out_rgb,
    output wire [31:0] out_epoch,out_frame_id,
    output wire [15:0] out_cfg_id,
    output wire [1:0] out_target_id,out_mode,
    output wire out_abort,
    output wire detect_valid,detect_mask,detect_sof,detect_eol,detect_eof,
    output wire [10:0] detect_x,detect_y,
    output wire [31:0] detect_epoch,detect_frame_id,
    output wire [15:0] detect_cfg_id,
    output wire [1:0] detect_target_id,
    output wire [15:0] error_flags,fifo_used,fifo_peak,
    output wire [50:0] out_calibration_status,
    output wire [37:0] out_tracking_status,
    output wire out_snapshot_ready,
    output wire [159:0] out_result_packet
);
    wire bvalid,bsof,beol,beof;
    wire [10:0] bx,by;
    wire [23:0] brgb,roi_rgb;
    wire [31:0] bepoch,bframe;
    wire [15:0] bcfg;
    wire [1:0] btarget,bmode;
    video_button_stream #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.GUARD_ROWS(GUARD_ROWS),
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),.ACTIVE_LOW(ACTIVE_LOW),
        .FIFO_DEPTH(FIFO_DEPTH),.MAX_IDLE_CYCLES(MAX_IDLE_CYCLES),.THRESHOLD(THRESHOLD)) video(
        .clk(clk),.rst_n(rst_n),.stream_abort(stream_abort),
        .in_valid(in_valid),.in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),
        .in_x(in_x),.in_y(in_y),.in_rgb(in_rgb),.in_epoch(in_epoch),.in_frame_id(in_frame_id),
        .in_cfg_id(in_cfg_id),.in_target_id(in_target_id),
        .min_main(min_main),.min_diff_1(min_diff_1),.min_diff_2(min_diff_2),
        .buttons_async(buttons_async),.pressed(),.press_event(press_event),.requested_mode(),
        .mode_next_evt(mode_next_evt),.calibrate_evt(calibrate_evt),.track_toggle_evt(track_toggle_evt),
        .invalid_request(),.invalid_request_seen(),.active_input_mode(),.next_frame_mode(),
        .out_valid(bvalid),.out_sof(bsof),.out_eol(beol),.out_eof(beof),
        .out_x(bx),.out_y(by),.out_rgb(brgb),.out_raw_rgb(),.out_gray_rgb(),.out_edge_rgb(),.out_mask_rgb(),
        .out_mode(bmode),.out_epoch(bepoch),.out_frame_id(bframe),.out_cfg_id(bcfg),.out_target_id(btarget),
        .detect_valid(detect_valid),.detect_mask(detect_mask),
        .detect_sof(detect_sof),.detect_eol(detect_eol),.detect_eof(detect_eof),
        .detect_x(detect_x),.detect_y(detect_y),
        .detect_epoch(detect_epoch),.detect_frame_id(detect_frame_id),
        .detect_cfg_id(detect_cfg_id),.detect_target_id(detect_target_id),
        .out_abort(out_abort),.error_flags(error_flags),.fifo_used(fifo_used),.fifo_peak(fifo_peak));
    video_calibration_roi #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) roi(
        .clk(clk),.rst_n(rst_n),.stream_abort(out_abort),
        .roi_req_valid(roi_req_valid),.roi_req_enable(roi_req_enable),
        .in_valid(bvalid),.in_sof(bsof),.in_x(bx),.in_y(by),.in_rgb(brgb),
        .out_rgb(roi_rgb),.roi_hit());
    wire [83:0] btag={bepoch,bframe,bcfg,btarget,bmode};
    wire cv,cs,cl,ce;
    wire [10:0] cpx,cpy;
    wire [23:0] crgb;
    wire [83:0] ctag;
    wire [50:0] cstatus;
    video_calibration_text ctext(.clk(clk),.rst_n(rst_n),.stream_abort(out_abort),
        .status_packet(calibration_status_packet),
        .in_valid(bvalid),.in_sof(bsof),.in_eol(beol),.in_eof(beof),
        .in_x(bx),.in_y(by),.in_rgb(roi_rgb),.in_tag(btag),
        .out_valid(cv),.out_sof(cs),.out_eol(cl),.out_eof(ce),
        .out_x(cpx),.out_y(cpy),.out_rgb(crgb),.out_tag(ctag),.out_status(cstatus));
    wire tv,ts,tl,te;
    wire [10:0] tx,ty;
    wire [23:0] trgb;
    wire [83:0] ttag;
    wire [37:0] tstatus;
    video_tracking_text ttext(.clk(clk),.rst_n(rst_n),.stream_abort(out_abort),
        .tracking_packet(tracking_packet),
        .in_valid(cv),.in_sof(cs),.in_eol(cl),.in_eof(ce),
        .in_x(cpx),.in_y(cpy),.in_rgb(crgb),.in_tag(ctag),
        .out_valid(tv),.out_sof(ts),.out_eol(tl),.out_eof(te),
        .out_x(tx),.out_y(ty),.out_rgb(trgb),
        .out_tag(ttag),.out_tracking_packet(tstatus));
    wire mv,ms,ml,me;
    wire [10:0] mx,my;
    wire [23:0] mrgb;
    wire [83:0] mtag;
    video_mode_label mode_text(.clk(clk),.rst_n(rst_n),.stream_abort(out_abort),
        .in_valid(tv),.in_sof(ts),.in_eol(tl),.in_eof(te),
        .in_x(tx),.in_y(ty),.in_rgb(trgb),.in_tag(ttag),
        .out_valid(mv),.out_sof(ms),.out_eol(ml),.out_eof(me),
        .out_x(mx),.out_y(my),.out_rgb(mrgb),.out_tag(mtag));
    // A supplies a result packet and epoch atomically in this pixel domain.
    // Strict matching selects a completed result only at the display SOF.
    wire match_ready;
    wire [31:0] match_frame;
    wire [15:0] match_cfg;
    wire [1:0] match_target;
    capture_target_gate result_gate(.clk(clk),.rst_n(rst_n),.stream_abort(out_abort),
        .pixel_valid(mv),.pixel_sof(ms),.pixel_epoch(mtag[83:52]),
        .pixel_frame_id(mtag[51:20]),.pixel_cfg_id(mtag[19:4]),
        .pixel_target_id(mtag[3:2]),.result_strobe(result_strobe),
        .result_epoch(result_epoch),.result_frame_id(result_frame_id),
        .result_cfg_id(result_cfg_id),.result_target_id(result_target_id),
        .source_timeout(source_timeout),.result_timeout(result_timeout),
        .completed_ready(match_ready),.completed_refresh_id(match_frame),
        .expected_cfg_id(match_cfg),.expected_target_id(match_target));
    video_target_info #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) target_info(
        .clk(clk),.rst_n(rst_n),.stream_abort(out_abort),
        .in_valid(mv),.in_sof(ms),.in_eol(ml),.in_eof(me),
        .in_x(mx),.in_y(my),.in_rgb(mrgb),.in_refresh_id(mtag[51:20]),
        .completed_ready(match_ready),.completed_refresh_id(match_frame),
        .expected_cfg_id(match_cfg),.expected_target_id(match_target),
        .result_strobe(result_strobe),.target_valid(target_valid),
        .result_frame_id(result_frame_id),.result_cfg_id(result_cfg_id),
        .result_target_id(result_target_id),.area(area),
        .xmin(xmin),.ymin(ymin),.xmax(xmax),.ymax(ymax),.cx(cx),.cy(cy),
        .reason(reason),.labels_used(labels_used),.components(components),
        .out_valid(out_valid),.out_sof(out_sof),.out_eol(out_eol),.out_eof(out_eof),
        .out_x(out_x),.out_y(out_y),.out_rgb(out_rgb),.out_refresh_id(),
        .out_snapshot_ready(out_snapshot_ready),.out_packet(out_result_packet));
    reg [83:0] tag_delay[0:3];
    reg [50:0] cal_delay[0:7];
    reg [37:0] tracking_delay[0:5];
    integer i;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            for(i=0;i<4;i=i+1)tag_delay[i]<=0;
            for(i=0;i<8;i=i+1)cal_delay[i]<=0;
            for(i=0;i<6;i=i+1)tracking_delay[i]<=0;
        end else if(out_abort)begin
            for(i=0;i<4;i=i+1)tag_delay[i]<=0;
            for(i=0;i<8;i=i+1)cal_delay[i]<=0;
            for(i=0;i<6;i=i+1)tracking_delay[i]<=0;
        end
        else begin
            tag_delay[0]<=mtag;
            for(i=1;i<4;i=i+1)tag_delay[i]<=tag_delay[i-1];
            cal_delay[0]<=cstatus;
            for(i=1;i<8;i=i+1)cal_delay[i]<=cal_delay[i-1];
            tracking_delay[0]<=tstatus;
            for(i=1;i<6;i=i+1)tracking_delay[i]<=tracking_delay[i-1];
        end
    end
    assign {out_epoch,out_frame_id,out_cfg_id,out_target_id,out_mode}=tag_delay[3];
    assign out_calibration_status=cal_delay[7];
    assign out_tracking_status=tracking_delay[5];
endmodule
