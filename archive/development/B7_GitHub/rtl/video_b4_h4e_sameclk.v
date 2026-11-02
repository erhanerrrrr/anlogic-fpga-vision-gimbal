// B4 extension of the unchanged B3g6 same-clock closed loop. A supplies
// measured latency events in this clock domain; no timer, CDC, DDR or HDMI
// controller is inferred here. No latency value is fabricated by this block.
module video_b4_h4e_sameclk #(
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
    input wire latency_clear,latency_valid,
    input wire [31:0] latency_us,
    input wire [1:0] latency_kind,
    input wire latency_synthetic,
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
    wire bv,bs,bl,be;
    wire [10:0] bx,by;
    wire [23:0] brgb;
    wire [31:0] bepoch,bframe;
    wire [15:0] bcfg;
    wire [1:0] btarget,bmode;
    wire [50:0] bcal;
    wire [37:0] btrack;
    wire bready;
    wire [159:0] bpacket;
    video_b3_h4e_sameclk #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),
        .GUARD_ROWS(GUARD_ROWS),.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),
        .ACTIVE_LOW(ACTIVE_LOW),.FIFO_DEPTH(FIFO_DEPTH),
        .MAX_IDLE_CYCLES(MAX_IDLE_CYCLES),.THRESHOLD(THRESHOLD),
        .MAX_RUNS(MAX_RUNS),.MIN_AREA(MIN_AREA)) base(
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
        .source_timeout(source_timeout),.result_timeout(result_timeout),
        .press_event(press_event),.mode_next_evt(mode_next_evt),
        .calibrate_evt(calibrate_evt),.track_toggle_evt(track_toggle_evt),
        .out_valid(bv),.out_sof(bs),.out_eol(bl),.out_eof(be),
        .out_x(bx),.out_y(by),.out_rgb(brgb),
        .out_epoch(bepoch),.out_frame_id(bframe),
        .out_cfg_id(bcfg),.out_target_id(btarget),.out_mode(bmode),
        .out_abort(out_abort),.error_flags(error_flags),
        .fifo_used(fifo_used),.fifo_peak(fifo_peak),
        .out_calibration_status(bcal),.out_tracking_status(btrack),
        .out_snapshot_ready(bready),.out_result_packet(bpacket),
        .region_busy(region_busy),.region_result_strobe(region_result_strobe),
        .region_result_epoch(region_result_epoch),
        .region_result_packet(region_result_packet));

    wire stats_valid;
    wire [1:0] stats_kind;
    wire [31:0] minimum,average,maximum;
    wire [8:0] stats_count;
    latency_window_stats stats(.clk(clk),.rst_n(rst_n),
        .clear(latency_clear || stream_abort || out_abort),
        .sample_valid(latency_valid),.sample_us(latency_us),
        .sample_kind(latency_kind),.stats_valid(stats_valid),
        .stats_kind(stats_kind),.min_us(minimum),.avg_us(average),
        .max_us(maximum),.sample_count(stats_count));

    wire [83:0] btag={bepoch,bframe,bcfg,btarget,bmode};
    wire [83:0] otag;
    video_latency_text text(.clk(clk),.rst_n(rst_n),
        .stream_abort(stream_abort || out_abort),
        .stats_valid(stats_valid),.stats_kind(stats_kind),
        .min_us(minimum),.avg_us(average),.max_us(maximum),
        .sample_count(stats_count),.synthetic_source(latency_synthetic),
        .in_valid(bv),.in_sof(bs),.in_eol(bl),.in_eof(be),
        .in_x(bx),.in_y(by),.in_rgb(brgb),.in_tag(btag),
        .out_valid(out_valid),.out_sof(out_sof),.out_eol(out_eol),
        .out_eof(out_eof),.out_x(out_x),.out_y(out_y),
        .out_rgb(out_rgb),.out_tag(otag));
    assign {out_epoch,out_frame_id,out_cfg_id,out_target_id,out_mode}=otag;

    // The text overlay adds two registers to each pixel. Delay the B3g6
    // per-pixel diagnostic snapshot by exactly the same two registers.
    reg [50:0] cal0,cal1;
    reg [37:0] track0,track1;
    reg ready0,ready1;
    reg [159:0] packet0,packet1;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n || stream_abort || out_abort)begin
            cal0<=0;cal1<=0;track0<=0;track1<=0;
            ready0<=0;ready1<=0;packet0<=0;packet1<=0;
        end else begin
            cal0<=bcal;cal1<=cal0;
            track0<=btrack;track1<=track0;
            ready0<=bready;ready1<=ready0;
            packet0<=bpacket;packet1<=packet0;
        end
    end
    assign out_calibration_status=cal1;
    assign out_tracking_status=track1;
    assign out_snapshot_ready=ready1;
    assign out_result_packet=packet1;
endmodule
