`timescale 1ns/1ps
// Adds two pipeline registers after B1a. Fixed text panels stay left of Logo.
// IDs have explicit HEX labels; coordinate/area/count fields use decimal.
module video_result_text(
    input wire clk,rst_n,stream_abort,
    input wire in_valid,in_sof,in_eol,in_eof,
    input wire [10:0] in_x,in_y,
    input wire [23:0] in_rgb,
    input wire [31:0] in_refresh_id,
    input wire in_snapshot_ready,
    input wire [159:0] in_packet,
    output reg out_valid,out_sof,out_eol,out_eof,
    output reg [10:0] out_x,out_y,
    output reg [23:0] out_rgb,
    output reg [31:0] out_refresh_id,
    output reg out_snapshot_ready,
    output reg [159:0] out_packet
);
    wire [31:0] fid;
    wire [15:0] cfg;
    wire [1:0] color;
    wire tv;
    wire [19:0] area;
    wire [10:0] xmin,ymin,xmax,ymax,cx,cy;
    wire [2:0] reason;
    wire [7:0] slots;
    wire [11:0] components;
    assign {fid,cfg,color,tv,area,xmin,ymin,xmax,ymax,cx,cy,reason,slots,components}=in_packet;
    wire [15:0] xb,yb,cb;
    wire [27:0] ab;
    wire [11:0] sb;
    wire numbers_ready;
    osd_decimal_fields numbers(.clk(clk),.rst_n(rst_n),.flush(stream_abort),
        .start(in_valid&&in_sof),.cx(cx),.cy(cy),.area(area),.slots(slots),.components(components),
        .done(numbers_ready),.x_bcd(xb),.y_bcd(yb),.area_bcd(ab),.slots_bcd(sb),.components_bcd(cb));
    function [7:0] hexchar;
        input [3:0] d;
        begin hexchar=d<10 ? 8'd48+{4'd0,d} : 8'd55+{4'd0,d};end
    endfunction
    function [7:0] strchar;
        input [511:0] s;
        input [5:0] column;
        begin strchar=s[511-column*8-:8];end
    endfunction
    wire [10:0] dx=in_x-11'd16;
    wire [5:0] col=dx[9:4];
    reg panel;
    reg [1:0] row;
    reg [3:0] glyph_y;
    always @* begin
        panel=0;row=0;glyph_y=0;
        if(in_x>=16 && in_x<976)begin
            if(in_y>=16 && in_y<32)begin panel=1;row=0;glyph_y=in_y-16;end
            else if(in_y>=40 && in_y<56)begin panel=1;row=1;glyph_y=in_y-40;end
            else if(in_y>=64 && in_y<80)begin panel=1;row=2;glyph_y=in_y-64;end
            else if(in_y>=88 && in_y<104)begin panel=1;row=3;glyph_y=in_y-88;end
        end
    end
    reg [7:0] ch;
    reg [23:0] ink;
    reg [63:0] status_word,reason_word;
    reg [39:0] color_word;
    // Bound every variable select even outside its visible character range.
    // Padded words avoid synthesis don't-cares for unused nibble/byte indices.
    wire [2:0] status_byte=6'd14-col, color_byte=6'd28-col, reason_byte=6'd16-col;
    wire [63:0] padded_color={color_word,24'd0};
    wire [1:0] x_digit=6'd5-col, y_digit=6'd12-col, slots_digit=6'd25-col;
    wire [1:0] cfg_digit=6'd31-col, count_digit=6'd41-col;
    wire [2:0] area_digit=6'd25-col, fid_digit=6'd18-col, display_digit=6'd52-col;
    wire [31:0] padded_area={4'd0,ab};
    wire [15:0] padded_slots={4'd0,sb};
    always @* begin
        status_word=!in_snapshot_ready ? "WAIT    " : tv ? "VALID   " : "INVALID ";
        case(color)
            0:color_word="RED  ";1:color_word="GREEN";2:color_word="BLUE ";default:color_word="NA   ";
        endcase
        if(!in_snapshot_ready)color_word="NA   ";
        case(reason)
            0:reason_word="OK      ";1:reason_word="EMPTY   ";2:reason_word="SMALL   ";
            3:reason_word="CAPACITY";4:reason_word="WAIT    ";5:reason_word="TIMEOUT ";
            default:reason_word="RESERVED";
        endcase
        ch=" ";ink=24'hffffff;
        case(row)
            0:begin
                ch=strchar({"TARGET:        COLOR:     ",304'd0},col);
                if(col>=7 && col<15)ch=status_word[status_byte*8+:8];
                if(col>=21 && col<26)ch=padded_color[color_byte*8+:8];
                ink=!in_snapshot_ready ? 24'hff8000 : tv ? 24'h00ff00 : 24'hffff00;
            end
            1:begin
                ch=strchar({"X:     Y:     AREA:       ",304'd0},col);
                if(col>=2 && col<6)ch=tv ? hexchar(xb[x_digit*4+:4]) : col==2 ? "N" : col==3 ? "A" : " ";
                if(col>=9 && col<13)ch=tv ? hexchar(yb[y_digit*4+:4]) : col==9 ? "N" : col==10 ? "A" : " ";
                if(col>=19 && col<26)ch=tv ? hexchar(padded_area[area_digit*4+:4]) : col==19 ? "N" : col==20 ? "A" : " ";
            end
            2:begin
                ch=strchar({"RESULT HEX:         CFG HEX:     DISPLAY HEX:        ",88'd0},col);
                if(col>=11 && col<19)ch=hexchar(fid[fid_digit*4+:4]);
                if(col>=28 && col<32)ch=hexchar(cfg[cfg_digit*4+:4]);
                if(col>=45 && col<53)ch=hexchar(in_refresh_id[display_digit*4+:4]);
            end
            3:begin
                ch=strchar({"REASON:          SLOTS:    COMPONENTS:    ",176'd0},col);
                if(col==7)ch=hexchar({1'b0,reason});
                if(col>=9 && col<17)ch=reason_word[reason_byte*8+:8];
                if(col>=23 && col<26)ch=hexchar(padded_slots[slots_digit*4+:4]);
                if(col>=38 && col<42)ch=in_snapshot_ready && reason!=3 && reason!=5 ? hexchar(cb[count_digit*4+:4]) : col==38 ? "N" : col==39 ? "A" : " ";
            end
        endcase
    end
    reg v1,s1,l1,e1,ready1,panel1;
    reg [10:0] x1,y1;
    reg [23:0] rgb1,ink1;
    reg [31:0] id1;
    reg [159:0] packet1;
    reg [7:0] char1;
    reg [3:0] row1,bit1;
    wire [15:0] glyph;
    target_text_font font(.I_char(char1),.I_row(row1),.O_row_bits(glyph));
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            v1<=0;s1<=0;l1<=0;e1<=0;ready1<=0;panel1<=0;x1<=0;y1<=0;rgb1<=0;ink1<=0;id1<=0;packet1<=0;char1<=0;row1<=0;bit1<=0;
            out_valid<=0;out_sof<=0;out_eol<=0;out_eof<=0;out_x<=0;out_y<=0;out_rgb<=0;out_refresh_id<=0;out_snapshot_ready<=0;out_packet<=0;
        end else if(stream_abort)begin
            v1<=0;s1<=0;l1<=0;e1<=0;ready1<=0;panel1<=0;x1<=0;y1<=0;rgb1<=0;ink1<=0;id1<=0;packet1<=0;char1<=0;row1<=0;bit1<=0;
            out_valid<=0;out_sof<=0;out_eol<=0;out_eof<=0;out_x<=0;out_y<=0;out_rgb<=0;out_refresh_id<=0;out_snapshot_ready<=0;out_packet<=0;
        end else begin
            v1<=in_valid;s1<=in_sof;l1<=in_eol;e1<=in_eof;ready1<=in_snapshot_ready;
            x1<=in_x;y1<=in_y;rgb1<=in_rgb;id1<=in_refresh_id;packet1<=in_packet;
            panel1<=panel && numbers_ready;char1<=ch;row1<=glyph_y;bit1<=4'd15-dx[3:0];ink1<=ink;
            out_valid<=v1;out_sof<=v1&&s1;out_eol<=v1&&l1;out_eof<=v1&&e1;
            out_x<=x1;out_y<=y1;out_refresh_id<=id1;out_snapshot_ready<=ready1;out_packet<=packet1;
            out_rgb<=!v1 ? 24'd0 : panel1 ? (glyph[bit1] ? ink1 : 24'h202020) : rgb1;
        end
    end
endmodule
