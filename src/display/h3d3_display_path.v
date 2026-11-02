// H3D: raw mask on HDMI, 5-of-9 filtered mask in geometry branch ONLY.
// Filter emits delayed/repacked rows: never drive native HDMI DE with its valid.
module h3d3_display_path #(
    parameter H_OFFSET=0, V_OFFSET=0, IMG_WIDTH=1280, IMG_HEIGHT=720,
    parameter integer DEBUG_MODE=0
)(
    input wire I_clk, I_rst_n,
    input wire I_video_vsync, I_video_hsync, I_video_de,
    input wire I_video_user, I_video_last,
    input wire [3:0] I_debug_status,
    output wire O_video_rd_en,
    input wire [23:0] I_video_rd_data,
    output wire O_hdmi_vsync, O_hdmi_hsync, O_hdmi_de,
    output wire [23:0] O_hdmi_data
);
    wire pixel_valid, mask;
    wire [23:0] pixel_rgb = {24{mask}};
    wire native_valid, native_sof, native_eof;
    wire [10:0] native_x, native_y;
    wire [31:0] native_refresh_id;
    reg vs_d, hs_d, user_d, last_d;
    reg [3:0] debug_d;
    reg meta_valid_d, sof_d, eof_d;
    reg [10:0] x_d, y_d;
    reg [31:0] refresh_id_d;

    // Never feed delayed display DE back to DDR read control.
    assign O_video_rd_en = I_video_de;
    display_raster_adapter #(.WIDTH(IMG_WIDTH),.HEIGHT(IMG_HEIGHT)) raster (
        .clk(I_clk),.rst_n(I_rst_n),.de(I_video_de),.user(I_video_user),
        .valid(native_valid),.sof(native_sof),.eof(native_eof),
        .x(native_x),.y(native_y),.refresh_id(native_refresh_id)
    );
    color_classifier_runtime u_c_red (
        .clk(I_clk),.rst_n(I_rst_n),.pixel_valid(I_video_de),
        .rgb(I_video_rd_data),.active_color(2'd0),
        .min_main(8'd24),.min_diff_1(8'd16),.min_diff_2(8'd16),
        .mask_valid(pixel_valid),.mask(mask)
    );
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            vs_d<=0; hs_d<=0; user_d<=0; last_d<=0; debug_d<=0;
            meta_valid_d<=0; sof_d<=0; eof_d<=0; x_d<=0; y_d<=0; refresh_id_d<=0;
        end else begin
            vs_d<=I_video_vsync; hs_d<=I_video_hsync;
            user_d<=I_video_user; last_d<=I_video_last; debug_d<=I_debug_status;
            meta_valid_d<=native_valid; sof_d<=native_sof; eof_d<=native_eof;
            x_d<=native_x; y_d<=native_y; refresh_id_d<=native_refresh_id;
        end
    end

    wire result_strobe, target_valid;
    wire [31:0] result_refresh_id;
    wire [15:0] result_cfg_id;
    wire [1:0] target_id;
    wire [19:0] area;
    wire [10:0] cx, cy, xmin, xmax, ymin, ymax;
    wire filtered_valid, filtered_mask, filtered_sof, filtered_eol, filtered_eof;
    wire [10:0] filtered_x, filtered_y;
    wire [31:0] filtered_frame_id;
    wire [15:0] filtered_cfg_id;
    wire [1:0] filtered_target_id;
    // Diagnostic guard: suppress only first/last four rows in detection.
    // Preserve every pixel VALID and all frame markers; do not drop stream data.
    // Raw HDMI mask and parallel raw statistics remain unguarded for comparison.
    wire guarded_mask = mask && y_d>=11'd4 && y_d<IMG_HEIGHT-4;
    mask_denoised_result #(.WIDTH(IMG_WIDTH),.HEIGHT(IMG_HEIGHT)) result (
        .clk(I_clk),.rst_n(I_rst_n),.mask_valid(pixel_valid && meta_valid_d),.mask(guarded_mask),
        .x(x_d),.y(y_d),.sof(sof_d),.eof(eof_d),
        // This C port is intentionally given a DISPLAY ID, not capture freshness.
        .source_frame_id(refresh_id_d),.cfg_id(16'd1),.active_color(2'd0),
        .filtered_valid(filtered_valid),.filtered_mask(filtered_mask),
        .filtered_x(filtered_x),.filtered_y(filtered_y),
        .filtered_sof(filtered_sof),.filtered_eol(filtered_eol),.filtered_eof(filtered_eof),
        .filtered_frame_id(filtered_frame_id),.filtered_cfg_id(filtered_cfg_id),.filtered_target_id(filtered_target_id),
        .result_strobe(result_strobe),.target_valid(target_valid),
        .result_frame_id(result_refresh_id),.result_cfg_id(result_cfg_id),.target_id(target_id),
        .area(area),.cx(cx),.cy(cy),.xmin(xmin),.xmax(xmax),.ymin(ymin),.ymax(ymax)
    );
    // Stage H4B: preserve F diagnostics; gate only the published T target.
    wire accepted_strobe,accepted_valid;
    wire [31:0] accepted_frame_id;
    wire [15:0] accepted_cfg_id;
    wire [1:0] accepted_target_id;
    wire [2:0] reject_reason;
    wire [19:0] accepted_area;
    wire [10:0] accepted_cx,accepted_cy,accepted_xmin,accepted_xmax,accepted_ymin,accepted_ymax;
    wire [7:0] region_labels;
    wire [11:0] region_components;
    wire region_busy;
    h4e_region_select #(.WIDTH(IMG_WIDTH),.HEIGHT(IMG_HEIGHT)) region_selector(
        .clk(I_clk),.rst_n(I_rst_n),.mask_valid(filtered_valid),.mask(filtered_mask),
        .x(filtered_x),.y(filtered_y),.sof(filtered_sof),.eof(filtered_eof),
        .frame_id(filtered_frame_id),.cfg_id(filtered_cfg_id),.target_id(filtered_target_id),
        .result_strobe(accepted_strobe),.target_valid(accepted_valid),.reason(reject_reason),
        .result_frame_id(accepted_frame_id),.result_cfg_id(accepted_cfg_id),.result_target_id(accepted_target_id),
        .area(accepted_area),.cx(accepted_cx),.cy(accepted_cy),
        .xmin(accepted_xmin),.xmax(accepted_xmax),.ymin(accepted_ymin),.ymax(accepted_ymax),
        .labels_used(region_labels),.components(region_components),.busy(region_busy)
    );
    reg gate_display_valid;
    reg [2:0] gate_display_reason;
    reg [7:0] gate_display_labels;
    reg [11:0] gate_display_components;
    reg [10:0] gate_display_xmin,gate_display_xmax,gate_display_ymin,gate_display_ymax;
    reg [19:0] gate_display_area;
    reg [10:0] gate_display_cx,gate_display_cy;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n)begin
            gate_display_valid<=0;gate_display_reason<=0;gate_display_area<=0;
            gate_display_cx<=0;gate_display_cy<=0;
            gate_display_xmin<=0;gate_display_xmax<=0;gate_display_ymin<=0;gate_display_ymax<=0;
            gate_display_labels<=0;gate_display_components<=0;
        end else if(native_sof)begin
            if(accepted_frame_id==result_refresh_id && !region_busy)begin
                gate_display_valid<=accepted_valid;gate_display_reason<=reject_reason;
                gate_display_area<=accepted_area;gate_display_cx<=accepted_cx;gate_display_cy<=accepted_cy;
                gate_display_xmin<=accepted_xmin;gate_display_xmax<=accepted_xmax;
                gate_display_ymin<=accepted_ymin;gate_display_ymax<=accepted_ymax;
                gate_display_labels<=region_labels;gate_display_components<=region_components;
            end else begin
                gate_display_valid<=0;gate_display_reason<=4;
                gate_display_area<=0;gate_display_cx<=0;gate_display_cy<=0;
                gate_display_xmin<=0;gate_display_xmax<=0;gate_display_ymin<=0;gate_display_ymax<=0;
                gate_display_labels<=0;gate_display_components<=0;
            end
        end
    end
    // Diagnostic only: metrics consume F, never drive target acceptance.
    wire metrics_strobe,metrics_valid,metrics_busy;
    wire [31:0] metrics_frame_id;
    wire [11:0] metrics_width,metrics_height;
    wire [23:0] metrics_box_area;
    wire [6:0] metrics_percent;
    h4c_fill_metrics metrics(
        .clk(I_clk),.rst_n(I_rst_n),.input_strobe(result_strobe),.input_frame_id(result_refresh_id),
        .input_count(area),.input_xmin(xmin),.input_xmax(xmax),.input_ymin(ymin),.input_ymax(ymax),
        .result_strobe(metrics_strobe),.result_valid(metrics_valid),.result_frame_id(metrics_frame_id),
        .box_width(metrics_width),.box_height(metrics_height),.box_area(metrics_box_area),
        .fill_percent(metrics_percent),.busy(metrics_busy)
    );
    reg diag_display_valid;
    reg [11:0] diag_display_width,diag_display_height;
    reg [23:0] diag_display_box_area;
    reg [6:0] diag_display_percent;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n)begin
            diag_display_valid<=0;diag_display_width<=0;diag_display_height<=0;
            diag_display_box_area<=0;diag_display_percent<=0;
        end else if(native_sof)begin
            // Never combine diagnostics from an older refresh with current F.
            if(metrics_valid && metrics_frame_id==result_refresh_id)begin
                diag_display_valid<=1;diag_display_width<=metrics_width;diag_display_height<=metrics_height;
                diag_display_box_area<=metrics_box_area;diag_display_percent<=metrics_percent;
            end else begin
                diag_display_valid<=0;diag_display_width<=0;diag_display_height<=0;
                diag_display_box_area<=0;diag_display_percent<=0;
            end
        end
    end
    wire raw_strobe,raw_valid;
    wire [19:0] raw_area;
    wire [10:0] raw_xmin,raw_xmax,raw_ymin,raw_ymax;
    mask_target_result raw_result (
        .clk(I_clk),.rst_n(I_rst_n),.mask_valid(pixel_valid && meta_valid_d),.mask(mask),
        .x(x_d),.y(y_d),.sof(sof_d),.eof(eof_d),.source_frame_id(refresh_id_d),
        .cfg_id(16'd1),.active_color(2'd0),.result_strobe(raw_strobe),.target_valid(raw_valid),
        .area(raw_area),.xmin(raw_xmin),.xmax(raw_xmax),.ymin(raw_ymin),.ymax(raw_ymax)
    );
    reg raw_display_valid;
    reg [19:0] raw_display_area;
    reg [10:0] raw_display_xmin,raw_display_xmax,raw_display_ymin,raw_display_ymax;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            raw_display_valid<=0;raw_display_area<=0;
            raw_display_xmin<=0;raw_display_xmax<=0;raw_display_ymin<=0;raw_display_ymax<=0;
        end else if(native_sof) begin
            raw_display_valid<=raw_valid;raw_display_area<=raw_area;
            raw_display_xmin<=raw_xmin;raw_display_xmax<=raw_xmax;
            raw_display_ymin<=raw_ymin;raw_display_ymax<=raw_ymax;
        end
    end
    // Publish the previous completed refresh at the start of the next refresh.
    // Text fields are a single frame-stable snapshot, not independently updated.
    reg display_valid;
    reg [19:0] display_area;
    reg [10:0] display_cx, display_cy;
    reg [10:0] display_xmin, display_xmax, display_ymin, display_ymax;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            display_valid<=0; display_area<=0; display_cx<=0; display_cy<=0;
            display_xmin<=0; display_xmax<=0; display_ymin<=0; display_ymax<=0;
        end else if(native_sof) begin
            display_valid<=target_valid; display_area<=area;
            display_cx<=cx; display_cy<=cy;
            display_xmin<=xmin; display_xmax<=xmax; display_ymin<=ymin; display_ymax<=ymax;
        end
    end
    h3d2_mixer #(
        .H_OFFSET(H_OFFSET),.V_OFFSET(V_OFFSET),.IMG_WIDTH(IMG_WIDTH),.IMG_HEIGHT(IMG_HEIGHT),
        .DEBUG_MODE(DEBUG_MODE),.HEADER_TEXT({"H4E ROW RECYCLE R64",360'd0})
    ) u_mixer (
        .I_clk(I_clk),.I_rst_n(I_rst_n),
        .I_video_vsync(vs_d),.I_video_hsync(hs_d),.I_video_de(pixel_valid),
        .I_video_user(user_d),.I_video_last(last_d),.I_debug_status(debug_d),
        .I_pixel_x(x_d),.I_pixel_y(y_d),
        .I_diag_valid(diag_display_valid),.I_diag_width(diag_display_width),.I_diag_height(diag_display_height),
        .I_diag_box_area(diag_display_box_area),.I_diag_percent(diag_display_percent),
        .I_selected_xmin(gate_display_xmin),.I_selected_xmax(gate_display_xmax),
        .I_selected_ymin(gate_display_ymin),.I_selected_ymax(gate_display_ymax),
        .I_region_labels(gate_display_labels),.I_region_components(gate_display_components),
        .I_gate_valid(gate_display_valid),.I_gate_reason(gate_display_reason),
        .I_gate_area(gate_display_area),.I_gate_cx(gate_display_cx),.I_gate_cy(gate_display_cy),
        .I_target_valid(display_valid),.I_target_cx(display_cx),.I_target_cy(display_cy),
        .I_target_xmin(display_xmin),.I_target_xmax(display_xmax),
        .I_target_ymin(display_ymin),.I_target_ymax(display_ymax),
        .I_raw_valid(raw_display_valid),.I_raw_area(raw_display_area),
        .I_raw_xmin(raw_display_xmin),.I_raw_xmax(raw_display_xmax),
        .I_raw_ymin(raw_display_ymin),.I_raw_ymax(raw_display_ymax),
        .I_target_area(display_area),.O_video_rd_en(),.I_video_rd_data(pixel_rgb),
        .O_hdmi_vsync(O_hdmi_vsync),.O_hdmi_hsync(O_hdmi_hsync),
        .O_hdmi_de(O_hdmi_de),.O_hdmi_data(O_hdmi_data)
    );
endmodule
