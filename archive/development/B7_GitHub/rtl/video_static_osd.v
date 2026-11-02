`timescale 1ns/1ps
// Two registered pixel stages; legal raster input, no backpressure.
// in_mode is the mode tag of THIS pixel, supplied by the upstream frame logic.
module video_static_osd #(
    parameter integer WIDTH=1280, HEIGHT=720, ENABLE=1,
    parameter integer LOGO_X=0, LOGO_Y=0,
    parameter integer TITLE_X=168, TITLE_Y=16,
    parameter integer LABEL_X=168, LABEL_Y=48,
    parameter integer CROSS_X=WIDTH/2, CROSS_Y=HEIGHT/2,
    parameter integer CROSS_HALF=8
) (
    input wire clk, rst_n, in_valid,
    input wire [23:0] in_rgb,
    input wire [1:0] in_mode,
    input wire in_sof, in_eol, in_eof,
    input wire [10:0] in_x,in_y,
    input wire [31:0] in_source_frame_id,
    output reg out_valid,
    output reg [23:0] out_rgb,
    output reg [1:0] out_mode,
    output reg out_sof,out_eol,out_eof,
    output reg [10:0] out_x,out_y,
    output reg [31:0] out_source_frame_id
);
    reg in_frame;
    wire accept_pixel=in_valid && (in_frame || in_sof);
    wire inside_view=(in_x<WIDTH && in_y<HEIGHT);
    wire logo_region=inside_view && in_x>=LOGO_X && in_x<LOGO_X+160 &&
                     in_y>=LOGO_Y && in_y<LOGO_Y+160;
    wire title_region=inside_view && in_x>=TITLE_X && in_x<TITLE_X+160 &&
                      in_y>=TITLE_Y && in_y<TITLE_Y+16;
    wire label_region=inside_view && in_x>=LABEL_X && in_x<LABEL_X+160 &&
                      in_y>=LABEL_Y && in_y<LABEL_Y+16;
    // Local coordinates are 0..159 whenever logo_region is true.
    // 160*y = (y<<7)+(y<<5); keep the calculation within the 15-bit ROM address.
    // Avoid a signed 32-bit multiply (TD otherwise spends a DSP on addressing).
    wire [10:0] logo_dx=in_x-LOGO_X, logo_dy=in_y-LOGO_Y;
    wire [14:0] logo_offset={logo_dy[7:0],7'b0}+{2'b0,logo_dy[7:0],5'b0}+{7'b0,logo_dx[7:0]};
    wire [14:0] logo_addr=logo_region ? logo_offset : 15'd0;
    reg [14:0] logo_addr_first;
    wire [24:0] logo_pixel;
    anlogic_logo_rom logo (.I_addr(logo_addr_first),.O_pixel(logo_pixel));

    wire [10:0] title_dx=in_x-TITLE_X, label_dx=in_x-LABEL_X;
    wire [3:0] title_row=in_y-TITLE_Y, label_row=in_y-LABEL_Y;
    reg [7:0] title_code,label_code;
    always @* begin
        title_code=" ";
        if(title_region) case(title_dx[7:4])
            0:title_code="F"; 1:title_code="P"; 2:title_code="G"; 3:title_code="A";
            5:title_code="V"; 6:title_code="I"; 7:title_code="D"; 8:title_code="E"; 9:title_code="O";
            default:title_code=" ";
        endcase
        label_code=" ";
        if(label_region) case(label_dx[7:4])
            0:label_code="M"; 1:label_code="O"; 2:label_code="D"; 3:label_code="E"; 4:label_code=":";
            6:case(in_mode) 0:label_code="R"; 1:label_code="G"; 2:label_code="E"; 3:label_code="M"; endcase
            7:case(in_mode) 0:label_code="A"; 1:label_code="R"; 2:label_code="D"; 3:label_code="A"; endcase
            8:case(in_mode) 0:label_code="W"; 1:label_code="A"; 2:label_code="G"; 3:label_code="S"; endcase
            9:case(in_mode) 0:label_code=" "; 1:label_code="Y"; 2:label_code="E"; 3:label_code="K"; endcase
            default:label_code=" ";
        endcase
    end
    wire [15:0] title_bits,label_bits;
    osd_char_lib title_font (.I_char(title_code),.I_row(title_row),.O_row_bits(title_bits));
    osd_char_lib label_font (.I_char(label_code),.I_row(label_row),.O_row_bits(label_bits));
    wire title_on=title_region && title_bits[15-title_dx[3:0]];
    wire label_on=label_region && label_bits[15-label_dx[3:0]];
    // Add before comparison to avoid unsigned subtraction wrapping at x/y=0.
    wire cross_on=inside_view &&
        ((in_y==CROSS_Y && in_x+CROSS_HALF>=CROSS_X && in_x<=CROSS_X+CROSS_HALF) ||
         (in_x==CROSS_X && in_y+CROSS_HALF>=CROSS_Y && in_y<=CROSS_Y+CROSS_HALF));
    reg [23:0] composed;
    always @* begin
        composed=in_rgb;
        if (ENABLE && inside_view) begin
            if (title_region) composed=24'h17202b;
            if (title_on) composed=24'h00e6ff;
            if (label_region) composed=24'h17202b;
            if (label_on) composed=24'hfff200;
            if (cross_on) composed=24'hff00ff;
        end
    end
    reg valid_first,logo_select_first;
    reg [23:0] rgb_first;
    reg [58:0] meta_first;
    // Stage one: coordinate arithmetic, font lookup and upper overlay layers.
    // Stage two: Logo lookup from a registered address and final pixel select.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_frame<=0; valid_first<=0; logo_addr_first<=0; logo_select_first<=0;
            rgb_first<=0; meta_first<=0;
            out_valid<=0; out_rgb<=0; out_mode<=0;
            out_sof<=0; out_eol<=0; out_eof<=0; out_x<=0; out_y<=0; out_source_frame_id<=0;
        end else begin
            valid_first<=accept_pixel;
            rgb_first<=accept_pixel ? composed : 24'd0;
            logo_addr_first<=accept_pixel ? logo_addr : 15'd0;
            logo_select_first<=accept_pixel && ENABLE && logo_region && !title_region && !label_region && !cross_on;
            meta_first<=accept_pixel ? {in_mode,in_sof,in_eol,in_eof,in_x,in_y,in_source_frame_id} : 59'd0;
            out_valid<=valid_first;
            out_rgb<=valid_first ? ((logo_select_first && logo_pixel[24]) ? logo_pixel[23:0] : rgb_first) : 24'd0;
            {out_mode,out_sof,out_eol,out_eof,out_x,out_y,out_source_frame_id}<=meta_first;
            if (accept_pixel) in_frame<=!in_eof;
        end
    end
endmodule
