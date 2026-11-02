// Development capture-v1 adapter; A still owns physical frame commit, CDC and timeouts.
// Input RGB is fixed-WB RGB888, before gamma/gray/OSD. Existing H4E rules are unchanged.
module h4e_capture_tracker #(
    parameter WIDTH=1280,HEIGHT=720,MAX_RUNS=64
)(
    input wire clk,rst_n,source_flush,
    input wire [31:0] active_epoch,
    input wire pixel_valid,sof,eof,
    input wire [23:0] rgb,
    input wire [10:0] x,y,
    input wire [31:0] source_frame_id,source_epoch,
    input wire [15:0] requested_cfg_id,
    input wire [1:0] requested_color,
    input wire [7:0] requested_min_main,requested_min_diff_1,requested_min_diff_2,
    output wire result_strobe,new_observation,new_source_sof,accepted_sof,frame_abort,stream_error,
    output wire [15:0] active_cfg_id,
    output wire [1:0] active_color,
    output wire [7:0] active_min_main,active_min_diff_1,active_min_diff_2,
    output wire target_valid,
    output wire [31:0] frame_id,
    output wire [31:0] capture_epoch,
    output wire [15:0] cfg_id,
    output wire [1:0] target_id,
    output wire [19:0] area,
    output wire [10:0] cx,
    output wire [10:0] cy,
    output wire [10:0] xmin,
    output wire [10:0] xmax,
    output wire [10:0] ymin,
    output wire [10:0] ymax,
    output wire [2:0] reject_reason,
    output wire [7:0] peak_slots,
    output wire [11:0] component_count
);
    wire processing_rst_n,pv,ps,pe;
    wire [23:0] prgb;
    wire [10:0] px,py;
    wire [31:0] held_frame,held_epoch;
    wire raw_strobe,accept_result,packet_strobe;
    wire raw_target_valid;
    wire [31:0] raw_frame_id;
    wire [15:0] raw_cfg_id;
    wire [1:0] raw_target_id;
    wire [19:0] raw_area;
    wire [10:0] raw_cx;
    wire [10:0] raw_cy;
    wire [10:0] raw_xmin;
    wire [10:0] raw_xmax;
    wire [10:0] raw_ymin;
    wire [10:0] raw_ymax;
    wire [2:0] raw_reject_reason;
    wire [7:0] raw_peak_slots;
    wire [11:0] raw_component_count;
    capture_frame_guard #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) ingress(
        .clk(clk),.rst_n(rst_n),.source_flush(source_flush),.active_epoch(active_epoch),
        .pixel_valid(pixel_valid),.sof(sof),.eof(eof),.rgb(rgb),.x(x),.y(y),
        .source_frame_id(source_frame_id),.source_epoch(source_epoch),
        .requested_cfg_id(requested_cfg_id),.requested_color(requested_color),
        .requested_min_main(requested_min_main),.requested_min_diff_1(requested_min_diff_1),
        .requested_min_diff_2(requested_min_diff_2),.candidate_strobe(raw_strobe),
        .candidate_frame_id(raw_frame_id),.candidate_cfg_id(raw_cfg_id),.candidate_target_id(raw_target_id),
        .accept_result(accept_result),.new_source_sof(new_source_sof),.accepted_sof(accepted_sof),
        .processing_rst_n(processing_rst_n),.frame_abort(frame_abort),.stream_error(stream_error),
        .out_valid(pv),.out_sof(ps),.out_eof(pe),.out_rgb(prgb),.out_x(px),.out_y(py),
        .frame_id(held_frame),.frame_epoch(held_epoch),.active_cfg_id(active_cfg_id),
        .active_color(active_color),.active_min_main(active_min_main),
        .active_min_diff_1(active_min_diff_1),.active_min_diff_2(active_min_diff_2));
    wire classified_valid,classified_mask;
    reg [10:0] classified_x,classified_y;
    reg classified_sof,classified_eof;
    color_classifier_runtime classifier(
        .min_main(active_min_main),.min_diff_1(active_min_diff_1),.min_diff_2(active_min_diff_2),
        .clk(clk),.rst_n(processing_rst_n),.pixel_valid(pv),.rgb(prgb),.active_color(active_color),
        .mask_valid(classified_valid),.mask(classified_mask));
    always @(posedge clk or negedge processing_rst_n) begin
        if(!processing_rst_n) begin classified_x<=0;classified_y<=0;classified_sof<=0;classified_eof<=0;end
        else if(pv) begin classified_x<=px;classified_y<=py;classified_sof<=ps;classified_eof<=pe;end
    end
    wire filtered_valid,filtered_mask,filtered_sof,filtered_eof,filtered_eol;
    wire [10:0] filtered_x,filtered_y;
    wire [31:0] filtered_frame;
    wire [15:0] filtered_cfg;
    wire [1:0] filtered_color;
    mask_majority_3x3 #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) filter(
        .clk(clk),.rst_n(processing_rst_n),.mask_valid(classified_valid),
        .mask(classified_mask && classified_y>=4 && classified_y<HEIGHT-4),
        .x(classified_x),.y(classified_y),.sof(classified_sof),.eof(classified_eof),
        .source_frame_id(held_frame),.cfg_id(active_cfg_id),.target_id(active_color),
        .out_valid(filtered_valid),.out_mask(filtered_mask),.out_x(filtered_x),.out_y(filtered_y),
        .out_sof(filtered_sof),.out_eol(filtered_eol),.out_eof(filtered_eof),
        .out_frame_id(filtered_frame),.out_cfg_id(filtered_cfg),.out_target_id(filtered_color));
    h4e_region_select #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_RUNS(MAX_RUNS)) region(
        .clk(clk),.rst_n(processing_rst_n),.mask_valid(filtered_valid),.mask(filtered_mask),
        .sof(filtered_sof),.eof(filtered_eof),.x(filtered_x),.y(filtered_y),
        .frame_id(filtered_frame),.cfg_id(filtered_cfg),.target_id(filtered_color),
        .result_strobe(raw_strobe),.busy(),
        .target_valid(raw_target_valid),
        .result_frame_id(raw_frame_id),
        .result_cfg_id(raw_cfg_id),
        .result_target_id(raw_target_id),
        .area(raw_area),
        .cx(raw_cx),
        .cy(raw_cy),
        .xmin(raw_xmin),
        .xmax(raw_xmax),
        .ymin(raw_ymin),
        .ymax(raw_ymax),
        .reason(raw_reject_reason),
        .labels_used(raw_peak_slots),
        .components(raw_component_count));
    h4e_target_packet packet(
        .clk(clk),.rst_n(rst_n),.t_result_strobe(accept_result),
        .t_target_valid(raw_target_valid),
        .t_frame_id(raw_frame_id),
        .t_capture_epoch(held_epoch),
        .t_cfg_id(raw_cfg_id),
        .t_target_id(raw_target_id),
        .t_area(raw_area),
        .t_cx(raw_cx),
        .t_cy(raw_cy),
        .t_xmin(raw_xmin),
        .t_xmax(raw_xmax),
        .t_ymin(raw_ymin),
        .t_ymax(raw_ymax),
        .t_reason(raw_reject_reason),
        .t_peak_slots(raw_peak_slots),
        .t_component_count(raw_component_count),
        .result_strobe(packet_strobe),
        .target_valid(target_valid),
        .frame_id(frame_id),
        .capture_epoch(capture_epoch),
        .cfg_id(cfg_id),
        .target_id(target_id),
        .area(area),
        .cx(cx),
        .cy(cy),
        .xmin(xmin),
        .xmax(xmax),
        .ymin(ymin),
        .ymax(ymax),
        .reject_reason(reject_reason),
        .peak_slots(peak_slots),
        .component_count(component_count));
    capture_observation_guard observer(
        .clk(clk),.rst_n(rst_n),.packet_strobe(packet_strobe),.source_flush(source_flush),
        .packet_frame_id(frame_id),.packet_epoch(capture_epoch),.active_epoch(active_epoch),
        .result_strobe(result_strobe),.new_observation(new_observation));
endmodule
