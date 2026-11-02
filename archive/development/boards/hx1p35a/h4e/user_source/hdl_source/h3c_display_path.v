// H3C raw geometry: C3/C4 unchanged, fixed RED thresholds as accepted in H3A.
// Results are the union bounding-box midpoint of ALL selected pixels.
// No denoising, object selection, validity filter, camera frame ID or servo yet.
module h3c_display_path #(
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
    mask_target_result result (
        .clk(I_clk),.rst_n(I_rst_n),.mask_valid(pixel_valid && meta_valid_d),.mask(mask),
        .x(x_d),.y(y_d),.sof(sof_d),.eof(eof_d),
        // This C port is intentionally given a DISPLAY ID, not capture freshness.
        .source_frame_id(refresh_id_d),.cfg_id(16'd1),.active_color(2'd0),
        .result_strobe(result_strobe),.target_valid(target_valid),
        .result_frame_id(result_refresh_id),.result_cfg_id(result_cfg_id),.target_id(target_id),
        .area(area),.cx(cx),.cy(cy),.xmin(xmin),.xmax(xmax),.ymin(ymin),.ymax(ymax)
    );
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
    h3c_mixer #(
        .H_OFFSET(H_OFFSET),.V_OFFSET(V_OFFSET),.IMG_WIDTH(IMG_WIDTH),.IMG_HEIGHT(IMG_HEIGHT),
        .DEBUG_MODE(DEBUG_MODE),.HEADER_TEXT({"H3C RED R24 RG16 RB16",344'd0})
    ) u_mixer (
        .I_clk(I_clk),.I_rst_n(I_rst_n),
        .I_video_vsync(vs_d),.I_video_hsync(hs_d),.I_video_de(pixel_valid),
        .I_video_user(user_d),.I_video_last(last_d),.I_debug_status(debug_d),
        .I_pixel_x(x_d),.I_pixel_y(y_d),
        .I_target_valid(display_valid),.I_target_cx(display_cx),.I_target_cy(display_cy),
        .I_target_xmin(display_xmin),.I_target_xmax(display_xmax),
        .I_target_ymin(display_ymin),.I_target_ymax(display_ymax),
        .I_target_area(display_area),.O_video_rd_en(),.I_video_rd_data(pixel_rgb),
        .O_hdmi_vsync(O_hdmi_vsync),.O_hdmi_hsync(O_hdmi_hsync),
        .O_hdmi_de(O_hdmi_de),.O_hdmi_data(O_hdmi_data)
    );
endmodule
