`timescale 1ns/1ps
// B4b display-only overlay. Input statistics must already be in this clock
// domain as one coherent packet. The 16x16 panels avoid the official Logo.
// Values are explicitly HEX microseconds, avoiding a wide decimal divider.
module video_latency_text #(
    parameter integer TAG_WIDTH=84
)(
    input wire clk,rst_n,stream_abort,
    input wire stats_valid,
    input wire [1:0] stats_kind,
    input wire [31:0] min_us,avg_us,max_us,
    input wire [8:0] sample_count,
    input wire synthetic_source,
    input wire in_valid,in_sof,in_eol,in_eof,
    input wire [10:0] in_x,in_y,
    input wire [23:0] in_rgb,
    input wire [TAG_WIDTH-1:0] in_tag,
    output reg out_valid,out_sof,out_eol,out_eof,
    output reg [10:0] out_x,out_y,
    output reg [23:0] out_rgb,
    output reg [TAG_WIDTH-1:0] out_tag
);
    reg frame_open;
    reg [108:0] active;
    wire start=in_valid && in_sof;
    wire [108:0] selected=start ?
        {stats_valid,stats_kind,sample_count,min_us,avg_us,max_us,synthetic_source} : active;
    wire good=selected[108] && selected[107:106]!=2'd3;
    wire [1:0] kind=selected[107:106];
    wire [8:0] count=selected[105:97];
    wire [31:0] minimum=selected[96:65];
    wire [31:0] average=selected[64:33];
    wire [31:0] maximum=selected[32:1];
    wire demo=selected[0];
    wire second=in_y>=232;
    wire [10:0] dx=second ? in_x-11'd16 : in_x-11'd176;
    wire [5:0] col=dx[9:4];
    wire panel=(in_y>=208 && in_y<224 && in_x>=176 && in_x<880) ||
        (in_y>=232 && in_y<248 && in_x>=16 && in_x<720);
    wire [3:0] glyph_y=second ? in_y-11'd232 : in_y-11'd208;
    localparam [511:0] LINE0="LAT TYPE:SOF N HEX:000 MIN HEX US:00000000";
    localparam [511:0] LINE1="AVG HEX US:00000000 MAX HEX US:00000000 SIM";
    reg [23:0] type_word;
    always @* begin
        case(kind)
            0:type_word="SOF";
            1:type_word="RES";
            2:type_word="EXT";
            default:type_word="NA ";
        endcase
    end
    function [7:0] hexchar;
        input [3:0] digit;
        begin hexchar=digit<10 ? 8'd48+{4'd0,digit} : 8'd55+{4'd0,digit};end
    endfunction
    reg [7:0] ch;
    always @* begin
        ch=" ";
        if(good) begin
            if(!second) begin
                if(col<42)ch=LINE0[(41-col)*8+:8];
                if(col>=9 && col<=11)ch=type_word[(11-col)*8+:8];
                if(col>=19 && col<=21)begin
                    case(col)
                        19:ch=hexchar({3'd0,count[8]});
                        20:ch=hexchar(count[7:4]);
                        default:ch=hexchar(count[3:0]);
                    endcase
                end
                if(col>=34 && col<=41)ch=hexchar(minimum[(41-col)*4+:4]);
            end else begin
                if(col<43)ch=LINE1[(42-col)*8+:8];
                if(col>=11 && col<=18)ch=hexchar(average[(18-col)*4+:4]);
                if(col>=31 && col<=38)ch=hexchar(maximum[(38-col)*4+:4]);
                if(!demo && col>=40)ch=" ";
            end
        end else if(!second) begin
            case(col)
                0:ch="L";1:ch="A";2:ch="T";3:ch=":";
                4:ch="N";5:ch="/";6:ch="A";
                default:ch=" ";
            endcase
        end
    end
    reg v1,s1,l1,e1,panel1;
    reg [10:0] x1,y1;
    reg [23:0] rgb1;
    reg [TAG_WIDTH-1:0] tag1;
    reg [7:0] char1;
    reg [3:0] row1,bit1;
    wire [15:0] base_glyph;
    target_text_font font(.I_char(char1),.I_row(row1),.O_row_bits(base_glyph));
    wire [15:0] slash_glyph=(row1>=1 && row1<=14) ?
        (16'h0003 << (row1-1'b1)) : 16'd0;
    wire [15:0] glyph=char1=="/" ? slash_glyph : base_glyph;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n || stream_abort) begin
            frame_open<=0;active<=0;
            v1<=0;s1<=0;l1<=0;e1<=0;panel1<=0;
            x1<=0;y1<=0;rgb1<=0;tag1<=0;char1<=0;row1<=0;bit1<=0;
            out_valid<=0;out_sof<=0;out_eol<=0;out_eof<=0;
            out_x<=0;out_y<=0;out_rgb<=0;out_tag<=0;
        end else begin
            if(start)begin frame_open<=1;active<=selected;end
            else if(in_valid && in_eof)frame_open<=0;
            v1<=in_valid && (frame_open || start);
            s1<=in_sof;l1<=in_eol;e1<=in_eof;
            x1<=in_x;y1<=in_y;rgb1<=in_rgb;tag1<=in_tag;
            panel1<=panel;char1<=ch;row1<=glyph_y;bit1<=4'd15-dx[3:0];
            out_valid<=v1;out_sof<=v1&&s1;out_eol<=v1&&l1;out_eof<=v1&&e1;
            out_x<=x1;out_y<=y1;out_tag<=tag1;
            out_rgb<=!v1 ? 24'd0 : panel1 ?
                (glyph[bit1] ? 24'h00ffff : 24'h202020) : rgb1;
        end
    end
endmodule
