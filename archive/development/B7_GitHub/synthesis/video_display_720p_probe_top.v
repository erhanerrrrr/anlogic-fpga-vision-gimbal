`timescale 1ns/1ps

// Synthesis-only observation mux. All 176 result bits, including the base RGB
// tap and diagnostics, remain observable. Not a board video interface.
module video_display_720p_probe_top (
    input wire clk, rst_n, in_valid,
    input wire [23:0] in_rgb,
    input wire in_mask, in_sof, in_eol, in_eof,
    input wire [10:0] in_x, in_y,
    input wire [31:0] in_source_frame_id,
    input wire [2:0] buttons_async,
    input wire [2:0] in_probe_select,
    output reg [31:0] out_probe
);
    wire valid, sof, eol, eof, error, invalid_request;
    wire [23:0] rgb;
    wire [1:0] mode;
    wire [10:0] x, y;
    wire [31:0] source_id;
    wire detect_valid, detect_sof, detect_eol, detect_eof;
    wire [23:0] detect_rgb;
    wire [10:0] detect_x, detect_y;
    wire [31:0] detect_id;
    wire [2:0] pressed, press_event;
    wire [1:0] requested_mode;
    wire [175:0] packet={pressed,press_event,requested_mode,error,invalid_request,mode,valid,sof,eol,eof,rgb,x,y,source_id,
                        detect_valid,detect_sof,detect_eol,detect_eof,detect_rgb,detect_x,detect_y,detect_id};
    video_display #(.WIDTH(1280),.HEIGHT(720),.THRESHOLD(11'd128),
                          .DEBOUNCE_CYCLES(750000),.ACTIVE_LOW(1),.OSD_ENABLE(1)) core (
        .clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_rgb(in_rgb),.in_mask(in_mask),
        .in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),
        .in_x(in_x),.in_y(in_y),.in_source_frame_id(in_source_frame_id),
        .buttons_async(buttons_async),.pressed(pressed),.press_event(press_event),
        .requested_mode(requested_mode),.invalid_request(invalid_request),
        .out_valid(valid),.out_rgb(rgb),.out_mode(mode),
        .out_sof(sof),.out_eol(eol),.out_eof(eof),.out_x(x),.out_y(y),.out_source_frame_id(source_id),
        .out_error(error),.detect_valid(detect_valid),.detect_rgb(detect_rgb),
        .detect_sof(detect_sof),.detect_eol(detect_eol),.detect_eof(detect_eof),
        .detect_x(detect_x),.detect_y(detect_y),.detect_source_frame_id(detect_id)
    );
    always @* begin
        case (in_probe_select)
            3'd0: out_probe=packet[31:0];
            3'd1: out_probe=packet[63:32];
            3'd2: out_probe=packet[95:64];
            3'd3: out_probe=packet[127:96];
            3'd4: out_probe=packet[159:128];
            3'd5: out_probe={16'd0,packet[175:160]};
            default: out_probe=32'd0;
        endcase
    end
endmodule
