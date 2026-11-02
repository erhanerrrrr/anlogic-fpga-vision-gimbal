// H2: B's registered grayscale conversion, followed by existing Gamma/OSD.
// ROI statistics now measure grayscale BEFORE Gamma; R/G/B sums must agree.
// Native board raster markers are retained verbatim; they are NOT the C-side
// SOF/EOL/EOF contract. This stage does not assign capture source frame IDs.
module h2_display_path #(
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
    wire pixel_valid;
    wire [23:0] pixel_rgb;
    reg vs_d, hs_d, user_d, last_d;
    reg [3:0] debug_d;
    // The DDR read request must retain its original timing. Do not feed the
    // delayed mixer DE back to the FIFO, which would change the sampled RGB.
    assign O_video_rd_en = I_video_de;
    rgb_to_gray u_b_gray (
        .clk(I_clk), .rst_n(I_rst_n), .in_valid(I_video_de),
        .in_rgb(I_video_rd_data), .out_valid(pixel_valid), .out_rgb(pixel_rgb)
    );
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            vs_d<=0; hs_d<=0; user_d<=0; last_d<=0; debug_d<=0;
        end else begin
            vs_d<=I_video_vsync; hs_d<=I_video_hsync;
            user_d<=I_video_user; last_d<=I_video_last; debug_d<=I_debug_status;
        end
    end
    hdmi_mixer #(
        .H_OFFSET(H_OFFSET), .V_OFFSET(V_OFFSET),
        .IMG_WIDTH(IMG_WIDTH), .IMG_HEIGHT(IMG_HEIGHT), .DEBUG_MODE(DEBUG_MODE),
        .HEADER_TEXT({"H2 GRAY R1.56 B2.03 BLC16 G2.2",272'd0})
    ) u_mixer (
        .I_clk(I_clk), .I_rst_n(I_rst_n),
        .I_video_vsync(vs_d), .I_video_hsync(hs_d), .I_video_de(pixel_valid),
        .I_video_user(user_d), .I_video_last(last_d), .I_debug_status(debug_d),
        .O_video_rd_en(), .I_video_rd_data(pixel_rgb),
        .O_hdmi_vsync(O_hdmi_vsync), .O_hdmi_hsync(O_hdmi_hsync),
        .O_hdmi_de(O_hdmi_de), .O_hdmi_data(O_hdmi_data)
    );
endmodule
