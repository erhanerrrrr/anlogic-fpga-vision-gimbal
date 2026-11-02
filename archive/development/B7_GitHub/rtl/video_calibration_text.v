`timescale 1ns/1ps
// Latest completed control-status snapshot, NOT the configuration of the image.
// Two pipeline registers, matching the existing uniform 16x16 font renderer.
// Place before official Logo compositor. Default rows avoid B1 text and central ROI.
module video_calibration_text #(
    parameter integer TAG_WIDTH=84
)(
    input wire clk,rst_n,stream_abort,
    input wire [50:0] status_packet,
    input wire in_valid,in_sof,in_eol,in_eof,
    input wire [10:0] in_x,in_y,
    input wire [23:0] in_rgb,
    input wire [TAG_WIDTH-1:0] in_tag,
    output reg out_valid,out_sof,out_eol,out_eof,
    output reg [10:0] out_x,out_y,
    output reg [23:0] out_rgb,
    output reg [TAG_WIDTH-1:0] out_tag,
    output reg [50:0] out_status
);
    reg opened;
    reg [50:0] active;
    wire start=in_valid && in_sof;
    wire [50:0] selected=start ? status_packet : active;
    wire known=selected[50];
    wire [2:0] phase=selected[49:47],reason=selected[44:42];
    wire [1:0] result=selected[46:45],color=selected[25:24];
    wire [15:0] cfg=selected[41:26];
    wire [7:0] main=selected[23:16],d1=selected[15:8],d2=selected[7:0];
    wire [10:0] dx=in_x-11'd16;
    wire [5:0] col=dx[9:4];
    wire panel=in_x>=16 && in_x<976 && ((in_y>=112 && in_y<128) || (in_y>=136 && in_y<152));
    wire second=in_y>=136;
    wire [3:0] gy=second ? in_y-136 : in_y-112;
    reg [87:0] word;
    reg [31:0] outcome;
    reg [7:0] ch;
    reg [23:0] ink;
    function [7:0] hexchar;
        input [3:0] n;
        begin hexchar=n<10 ? 8'd48+{4'd0,n} : 8'd55+{4'd0,n};end
    endfunction
    function [7:0] strchar;
        input [479:0] text;
        input [5:0] column;
        reg [511:0] padded;
        reg [5:0] byte_index;
        begin padded={text,32'd0};byte_index=6'd63-column;strchar=padded[byte_index*8+:8];end
    endfunction
    wire [3:0] word_index=col-4;
    wire [127:0] padded_word={word,40'd0};
    wire [1:0] result_index=col-23;
    wire [3:0] word_byte=4'd15-word_index;
    wire [1:0] result_byte=2'd3-result_index;
    always @* begin
        case(phase)
            0:word="IDLE       ";1:word="WAIT SAMPLE";2:word="CALC       ";
            3:word="PENDING    ";4:word="APPLIED    ";5:word="FAILED     ";
            default:word="UNKNOWN    ";
        endcase
        if(!known)word="UNKNOWN    ";
        case(result)1:outcome="OK  ";2:outcome="FAIL";default:outcome="NONE";endcase
        ink=!known ? 24'hff8000 : phase==5 ? 24'hff4040 : phase==4 ? 24'h00ff00 : 24'hffffff;
        ch=" ";
        if(!second)begin
            ch=strchar({"CAL:            RESULT:     WHY: ",216'd0},col);
            if(col>=4 && col<15)ch=padded_word[word_byte*8+:8];
            if(col>=23 && col<27)ch=known ? outcome[result_byte*8+:8] : " ";
            if(col==32)ch=known ? hexchar({1'b0,reason}) : " ";
        end else begin
            ch=strchar({"CTRL HEX CFG:     COLOR:  MAIN:   D1:   D2:  ",120'd0},col);
            // Explicit character positions; no divide/modulo datapath.
            if(col>=13 && col<17)begin
                case(col)13:ch=hexchar(cfg[15:12]);14:ch=hexchar(cfg[11:8]);15:ch=hexchar(cfg[7:4]);default:ch=hexchar(cfg[3:0]);endcase
                if(!known)ch=col==13 ? "N" : col==14 ? "A" : " ";
            end
            if(col==24)ch=!known ? "N" : color==0 ? "R" : color==1 ? "G" : color==2 ? "B" : "N";
            if(col==31 || col==32)ch=known ? hexchar(col==31 ? main[7:4] : main[3:0]) : col==31 ? "N" : "A";
            if(col==37 || col==38)ch=known ? hexchar(col==37 ? d1[7:4] : d1[3:0]) : col==37 ? "N" : "A";
            if(col==43 || col==44)ch=known ? hexchar(col==43 ? d2[7:4] : d2[3:0]) : col==43 ? "N" : "A";
            ink=24'hffffff;
        end
    end
    reg v1,s1,l1,e1,panel1;
    reg [10:0] x1,y1;
    reg [23:0] rgb1,ink1;
    reg [TAG_WIDTH-1:0] tag1;
    reg [50:0] status1;
    reg [7:0] char1;
    reg [3:0] row1,bit1;
    wire [15:0] glyph;
    target_text_font font(.I_char(char1),.I_row(row1),.O_row_bits(glyph));
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n || stream_abort)begin
            opened<=0;active<={1'b0,3'd6,47'd0};
            v1<=0;s1<=0;l1<=0;e1<=0;panel1<=0;x1<=0;y1<=0;rgb1<=0;ink1<=0;tag1<=0;status1<=0;char1<=0;row1<=0;bit1<=0;
            out_valid<=0;out_sof<=0;out_eol<=0;out_eof<=0;out_x<=0;out_y<=0;out_rgb<=0;out_tag<=0;out_status<=0;
        end else begin
            if(start)begin opened<=1;active<=status_packet;end
            v1<=in_valid && (opened || start);s1<=in_sof;l1<=in_eol;e1<=in_eof;
            x1<=in_x;y1<=in_y;rgb1<=in_rgb;tag1<=in_tag;status1<=selected;
            panel1<=panel;char1<=ch;row1<=gy;bit1<=4'd15-dx[3:0];ink1<=ink;
            out_valid<=v1;out_sof<=v1&&s1;out_eol<=v1&&l1;out_eof<=v1&&e1;
            out_x<=x1;out_y<=y1;out_tag<=tag1;out_status<=status1;
            out_rgb<=!v1 ? 24'd0 : panel1 ? (glyph[bit1] ? ink1 : 24'h202020) : rgb1;
        end
    end
endmodule
