// Same-pixel-clock B display + unchanged H4E region selector.
// A must provide the real capture epoch/IDs, frame replay and clock-domain
// crossing. No DDR, HDMI timing or cross-clock logic is implemented here.
module video_b3_h4e_sameclk #(
    parameter integer WIDTH=1280,HEIGHT=720,GUARD_ROWS=4,
    parameter integer DEBOUNCE_CYCLES=750000,ACTIVE_LOW=1,
    parameter integer FIFO_DEPTH=(1 << $clog2(WIDTH+8)),MAX_IDLE_CYCLES=4096,
    parameter [10:0] THRESHOLD=11'd128,
    parameter integer MAX_RUNS=64,MIN_AREA=256
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
    output wire [15:0] error_flags,fifo_used,fifo_peak,
    output wire [50:0] out_calibration_status,
    output wire [37:0] out_tracking_status,
    output wire out_snapshot_ready,
    output wire [159:0] out_result_packet,
    output wire region_busy,region_result_strobe,
    output wire [31:0] region_result_epoch,
    output wire [159:0] region_result_packet
);
    wire dv,dm,ds,dl,de;
    wire [10:0] dx,dy;
    wire [31:0] depoch,dframe;
    wire [15:0] dcfg;
    wire [1:0] dtarget;
    wire c_strobe,c_valid;
    wire [2:0] c_reason;
    wire [31:0] c_frame;
    wire [15:0] c_cfg;
    wire [1:0] c_target;
    wire [19:0] c_area;
    wire [10:0] c_xmin,c_ymin,c_xmax,c_ymax,c_cx,c_cy;
    wire [7:0] c_slots;
    wire [11:0] c_components;

    // H4E has no epoch port. Associate its one outstanding result with
    // the source tag seen on the matching mask SOF. A must avoid a new
    // source SOF until the previous H4E result has been consumed.
    reg have_tag;
    reg [31:0] held_epoch,held_frame;
    reg [15:0] held_cfg;
    reg [1:0] held_target;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            have_tag<=0;held_epoch<=0;held_frame<=0;held_cfg<=0;held_target<=0;
        end else if(out_abort || stream_abort)begin
            have_tag<=0;held_epoch<=0;held_frame<=0;held_cfg<=0;held_target<=0;
        end else if(dv && ds)begin
            have_tag<=1;held_epoch<=depoch;held_frame<=dframe;
            held_cfg<=dcfg;held_target<=dtarget;
        end
    end
    wire c_result_match=have_tag && c_frame==held_frame &&
        c_cfg==held_cfg && c_target==held_target;
    assign region_result_strobe=c_strobe && c_result_match &&
        !out_abort && !stream_abort;
    assign region_result_epoch=held_epoch;
    assign region_result_packet={c_frame,c_cfg,c_target,c_valid,c_area,
        c_xmin,c_ymin,c_xmax,c_ymax,c_cx,c_cy,c_reason,c_slots,c_components};

    video_b3_target_stream #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),
        .GUARD_ROWS(GUARD_ROWS),.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),
        .ACTIVE_LOW(ACTIVE_LOW),.FIFO_DEPTH(FIFO_DEPTH),
        .MAX_IDLE_CYCLES(MAX_IDLE_CYCLES),.THRESHOLD(THRESHOLD)) display(
        .clk(clk),.rst_n(rst_n),.stream_abort(stream_abort),
        .in_valid(in_valid),.in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),
        .in_x(in_x),.in_y(in_y),.in_rgb(in_rgb),
        .in_epoch(in_epoch),.in_frame_id(in_frame_id),
        .in_cfg_id(in_cfg_id),.in_target_id(in_target_id),
        .min_main(min_main),.min_diff_1(min_diff_1),.min_diff_2(min_diff_2),
        .buttons_async(buttons_async),.roi_req_valid(roi_req_valid),
        .roi_req_enable(roi_req_enable),
        .calibration_status_packet(calibration_status_packet),
        .tracking_packet(tracking_packet),
        .result_strobe(region_result_strobe),.target_valid(c_valid),
        .result_epoch(held_epoch),.result_frame_id(c_frame),
        .result_cfg_id(c_cfg),.result_target_id(c_target),.area(c_area),
        .xmin(c_xmin),.ymin(c_ymin),.xmax(c_xmax),.ymax(c_ymax),
        .cx(c_cx),.cy(c_cy),.reason(c_reason),
        .labels_used(c_slots),.components(c_components),
        .source_timeout(source_timeout),.result_timeout(result_timeout),
        .press_event(press_event),.mode_next_evt(mode_next_evt),
        .calibrate_evt(calibrate_evt),.track_toggle_evt(track_toggle_evt),
        .out_valid(out_valid),.out_sof(out_sof),.out_eol(out_eol),
        .out_eof(out_eof),.out_x(out_x),.out_y(out_y),.out_rgb(out_rgb),
        .out_epoch(out_epoch),.out_frame_id(out_frame_id),
        .out_cfg_id(out_cfg_id),.out_target_id(out_target_id),
        .out_mode(out_mode),.out_abort(out_abort),
        .error_flags(error_flags),.fifo_used(fifo_used),.fifo_peak(fifo_peak),
        .out_calibration_status(out_calibration_status),
        .out_tracking_status(out_tracking_status),
        .out_snapshot_ready(out_snapshot_ready),
        .out_result_packet(out_result_packet),
        .detect_valid(dv),.detect_mask(dm),.detect_sof(ds),
        .detect_eol(dl),.detect_eof(de),.detect_x(dx),.detect_y(dy),
        .detect_epoch(depoch),.detect_frame_id(dframe),
        .detect_cfg_id(dcfg),.detect_target_id(dtarget));
    h4e_region_select #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),
        .MAX_RUNS(MAX_RUNS),.MIN_AREA(MIN_AREA)) selector(
        .clk(clk),.rst_n(rst_n),
        .mask_valid(dv),.mask(dm),.sof(ds),.eof(de),
        .x(dx),.y(dy),.frame_id(dframe),.cfg_id(dcfg),
        .target_id(dtarget),
        .result_strobe(c_strobe),.target_valid(c_valid),.reason(c_reason),
        .result_frame_id(c_frame),.result_cfg_id(c_cfg),
        .result_target_id(c_target),.area(c_area),
        .xmin(c_xmin),.ymin(c_ymin),.xmax(c_xmax),.ymax(c_ymax),
        .cx(c_cx),.cy(c_cy),.labels_used(c_slots),
        .components(c_components),.busy(region_busy));
endmodule
