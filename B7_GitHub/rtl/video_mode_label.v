// Four-mode label uses the mode carried by THIS pixel, never an immediate key.
// Two pipeline registers and the same 16x16 font as other B panels.
module video_mode_label #(parameter integer TAG_WIDTH=84)(
    input wire clk,rst_n,stream_abort,
    input wire in_valid,in_sof,in_eol,in_eof,
    input wire [10:0] in_x,in_y,
    input wire [23:0] in_rgb,
    input wire [TAG_WIDTH-1:0] in_tag,
    output reg out_valid,out_sof,out_eol,out_eof,
    output reg [10:0] out_x,out_y,
    output reg [23:0] out_rgb,
    output reg [TAG_WIDTH-1:0] out_tag
);
    wire panel=in_x>=16 && in_x<160 && in_y>=208 && in_y<224;
    wire [10:0] dx=in_x-11'd16;
    wire [3:0] col=dx[7:4];
    reg [31:0] mode_word;
    reg [7:0] ch;
    always @*begin
        case(in_tag[1:0])
            0:mode_word="RAW ";1:mode_word="GRAY";2:mode_word="EDGE";default:mode_word="MASK";
        endcase
        case(col)
            0:ch="M";1:ch="O";2:ch="D";3:ch="E";4:ch=":";
            5:ch=mode_word[31:24];6:ch=mode_word[23:16];
            7:ch=mode_word[15:8];8:ch=mode_word[7:0];
            default:ch=" ";
        endcase
    end
    reg v1,s1,l1,e1,panel1;
    reg [10:0] x1,y1;
    reg [23:0] rgb1;
    reg [TAG_WIDTH-1:0] tag1;
    reg [7:0] char1;
    reg [3:0] row1,bit1;
    wire [15:0] glyph;
    target_text_font font(.I_char(char1),.I_row(row1),.O_row_bits(glyph));
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n || stream_abort)begin
            v1<=0;s1<=0;l1<=0;e1<=0;panel1<=0;x1<=0;y1<=0;rgb1<=0;tag1<=0;char1<=0;row1<=0;bit1<=0;
            out_valid<=0;out_sof<=0;out_eol<=0;out_eof<=0;out_x<=0;out_y<=0;out_rgb<=0;out_tag<=0;
        end else begin
            v1<=in_valid;s1<=in_sof;l1<=in_eol;e1<=in_eof;
            x1<=in_x;y1<=in_y;rgb1<=in_rgb;tag1<=in_tag;
            panel1<=panel;char1<=ch;row1<=in_y-11'd208;bit1<=4'd15-dx[3:0];
            out_valid<=v1;out_sof<=v1&&s1;out_eol<=v1&&l1;out_eof<=v1&&e1;
            out_x<=x1;out_y<=y1;out_tag<=tag1;
            out_rgb<=!v1 ? 24'd0 : panel1 ? (glyph[bit1] ? 24'h00ffff : 24'h202020) : rgb1;
        end
    end
endmodule
