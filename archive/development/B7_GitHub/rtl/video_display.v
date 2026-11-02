`timescale 1ns/1ps

// Button-controlled modes followed by registered static OSD. Same clock throughout.
module video_display #(
    parameter integer WIDTH=1280, HEIGHT=720,
    parameter [10:0] THRESHOLD=11'd128,
    parameter integer DEBOUNCE_CYCLES=750000, ACTIVE_LOW=1, OSD_ENABLE=1
) (
    input wire clk, rst_n, in_valid,
    input wire [23:0] in_rgb,
    input wire in_mask, in_sof, in_eol, in_eof,
    input wire [10:0] in_x, in_y,
    input wire [31:0] in_source_frame_id,
    input wire [2:0] buttons_async,
    output wire [2:0] pressed, press_event,
    output wire [1:0] requested_mode,
    output wire invalid_request,
    output wire out_valid,
    output wire [23:0] out_rgb,
    output wire [1:0] out_mode,
    output wire out_sof, out_eol, out_eof,
    output wire [10:0] out_x, out_y,
    output wire [31:0] out_source_frame_id,
    output wire out_error,
    // Independent, one-register base RGB tap for recognition. Always active.
    output wire detect_valid,
    output wire [23:0] detect_rgb,
    output wire detect_sof, detect_eol, detect_eof,
    output wire [10:0] detect_x, detect_y,
    output wire [31:0] detect_source_frame_id
);
    wire styled_valid;
    wire [23:0] styled_rgb;
    wire [1:0] styled_mode;
    wire styled_sof;
    wire styled_eol;
    wire styled_eof;
    wire [10:0] styled_x;
    wire [10:0] styled_y;
    wire [31:0] styled_source_frame_id;
    video_modes_buttons #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.THRESHOLD(THRESHOLD),
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),.ACTIVE_LOW(ACTIVE_LOW)) chain (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_rgb(in_rgb),
        .in_mask(in_mask),
        .in_sof(in_sof),
        .in_eol(in_eol),
        .in_eof(in_eof),
        .in_x(in_x),
        .in_y(in_y),
        .in_source_frame_id(in_source_frame_id),
        .buttons_async(buttons_async),
        .pressed(pressed),
        .press_event(press_event),
        .requested_mode(requested_mode),
        .invalid_request(invalid_request),
        .out_error(out_error),
        .detect_valid(detect_valid),
        .detect_rgb(detect_rgb),
        .detect_sof(detect_sof),
        .detect_eol(detect_eol),
        .detect_eof(detect_eof),
        .detect_x(detect_x),
        .detect_y(detect_y),
        .detect_source_frame_id(detect_source_frame_id),
        .out_valid(styled_valid),
        .out_rgb(styled_rgb),
        .out_mode(styled_mode),
        .out_sof(styled_sof),
        .out_eol(styled_eol),
        .out_eof(styled_eof),
        .out_x(styled_x),
        .out_y(styled_y),
        .out_source_frame_id(styled_source_frame_id)
    );
    video_static_osd #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.ENABLE(OSD_ENABLE)) overlay (
        .clk(clk),.rst_n(rst_n),
        .in_valid(styled_valid),
        .in_rgb(styled_rgb),
        .in_mode(styled_mode),
        .in_sof(styled_sof),
        .in_eol(styled_eol),
        .in_eof(styled_eof),
        .in_x(styled_x),
        .in_y(styled_y),
        .in_source_frame_id(styled_source_frame_id),
        .out_valid(out_valid),
        .out_rgb(out_rgb),
        .out_mode(out_mode),
        .out_sof(out_sof),
        .out_eol(out_eol),
        .out_eof(out_eof),
        .out_x(out_x),
        .out_y(out_y),
        .out_source_frame_id(out_source_frame_id)
    );
endmodule
