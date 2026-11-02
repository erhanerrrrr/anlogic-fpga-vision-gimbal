`timescale 1ns/1ps
// A owns all control decisions. This block only snapshots and displays A's
// coherent status packet: {valid,state[2:0],pan_limit,tilt_limit,pan_us,tilt_us}.
// Text labels say CMD and HEX explicitly: no encoder/position is inferred.
module video_tracking_text #(parameter integer TAG_WIDTH=84)(
    input wire clk,rst_n,stream_abort,
    input wire [37:0] tracking_packet,
    input wire in_valid,in_sof,in_eol,in_eof,
    input wire [10:0] in_x,in_y,
    input wire [23:0] in_rgb,
    input wire [TAG_WIDTH-1:0] in_tag,
    output reg out_valid,out_sof,out_eol,out_eof,
    output reg [10:0] out_x,out_y,
    output reg [23:0] out_rgb,
    output reg [TAG_WIDTH-1:0] out_tag,
    output reg [37:0] out_tracking_packet
);
    reg frame_open;
    reg [37:0] active;
    wire start=in_valid && in_sof;
    wire [37:0] selected=start ? tracking_packet : active;
    wire known=selected[37];
    wire [2:0] state=selected[36:34];
    wire pan_lim=selected[33],tilt_lim=selected[32];
    wire [15:0] pan_us=selected[31:16],tilt_us=selected[15:0];
    wire [10:0] dx=in_x-11'd16;
    wire [5:0] col=dx[9:4];
    wire panel=in_x>=16 && in_x<976 && ((in_y>=160 && in_y<176) || (in_y>=184 && in_y<200));
    wire second=in_y>=184;
    wire [3:0] gy=second ? in_y-184 : in_y-160;
    reg [87:0] word;
    reg [7:0] ch;
    reg [23:0] ink;
    function [7:0] hexchar;
        input [3:0] n;
        begin hexchar=n<10 ? 8'd48+{4'd0,n} : 8'd55+{4'd0,n};end
    endfunction
    function [7:0] static_char;
        input [479:0] line;
        input [5:0] column;
        reg [511:0] padded;
        reg [5:0] index;
        begin padded={line,32'd0};index=6'd63-column;static_char=padded[index*8+:8];end
    endfunction
    wire [3:0] word_col=col-7;
    wire [127:0] padded_word={word,40'd0};
    wire [3:0] word_index=4'd15-word_col;
    always @* begin
        case(state)
            0:word="OFF        ";1:word="REACQUIRE  ";2:word="FOLLOW     ";
            3:word="LOST HOLD  ";4:word="TIMEOUT HLD";5:word="FAULT      ";
            default:word="RESERVED   ";
        endcase
        if(!known)word="UNKNOWN    ";
        ink=!known ? 24'hff8000 : state==5 ? 24'hff4040 : state==2 ? 24'h00ff00 :
            (state==3 || state==4) ? 24'hffff00 : 24'hffffff;
        ch=" ";
        if(!second)begin
            ch=static_char({"TRACK:            PAN LIM:  TILT LIM:  ",168'd0},col);
            if(col>=7 && col<18)ch=padded_word[word_index*8+:8];
            if(col==26)ch=known ? (pan_lim ? "Y" : "N") : "N";
            if(col==27 && !known)ch="A";
            if(col==37)ch=known ? (tilt_lim ? "Y" : "N") : "N";
            if(col==38 && !known)ch="A";
        end else begin
            ch=static_char({"PAN CMD US HEX:       TILT CMD US HEX:    ",144'd0},col);
            if(col>=16 && col<20)begin
                case(col)
                    16:ch=hexchar(pan_us[15:12]);17:ch=hexchar(pan_us[11:8]);
                    18:ch=hexchar(pan_us[7:4]);default:ch=hexchar(pan_us[3:0]);
                endcase
                if(!known)ch=col==16 ? "N" : col==17 ? "A" : " ";
            end
            if(col>=38 && col<42)begin
                case(col)
                    38:ch=hexchar(tilt_us[15:12]);39:ch=hexchar(tilt_us[11:8]);
                    40:ch=hexchar(tilt_us[7:4]);default:ch=hexchar(tilt_us[3:0]);
                endcase
                if(!known)ch=col==38 ? "N" : col==39 ? "A" : " ";
            end
            ink=24'hffffff;
        end
    end
    reg v1,s1,l1,e1,panel1;
    reg [10:0] x1,y1;
    reg [23:0] rgb1,ink1;
    reg [TAG_WIDTH-1:0] tag1;
    reg [37:0] packet1;
    reg [7:0] char1;
    reg [3:0] row1,bit1;
    wire [15:0] glyph;
    target_text_font font(.I_char(char1),.I_row(row1),.O_row_bits(glyph));
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n || stream_abort)begin
            frame_open<=0;active<=0;
            v1<=0;s1<=0;l1<=0;e1<=0;panel1<=0;x1<=0;y1<=0;rgb1<=0;ink1<=0;tag1<=0;packet1<=0;char1<=0;row1<=0;bit1<=0;
            out_valid<=0;out_sof<=0;out_eol<=0;out_eof<=0;out_x<=0;out_y<=0;out_rgb<=0;out_tag<=0;out_tracking_packet<=0;
        end else begin
            if(start)begin frame_open<=1;active<=tracking_packet;end
            v1<=in_valid && (frame_open || start);s1<=in_sof;l1<=in_eol;e1<=in_eof;
            x1<=in_x;y1<=in_y;rgb1<=in_rgb;tag1<=in_tag;packet1<=selected;
            panel1<=panel;char1<=ch;row1<=gy;bit1<=4'd15-dx[3:0];ink1<=ink;
            out_valid<=v1;out_sof<=v1&&s1;out_eol<=v1&&l1;out_eof<=v1&&e1;
            out_x<=x1;out_y<=y1;out_tag<=tag1;out_tracking_packet<=packet1;
            out_rgb<=!v1 ? 24'd0 : panel1 ? (glyph[bit1] ? ink1 : 24'h202020) : rgb1;
        end
    end
endmodule
