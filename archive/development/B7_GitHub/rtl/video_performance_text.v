`timescale 1ns/1ps
// B4f standalone performance OSD. A must transfer the complete 88-bit
// measurement packet atomically into this pixel clock domain.
// Packet: {src_valid,src_over,src_centi[15:0],
//          dsp_valid,dsp_over,dsp_centi[15:0],
//          res_valid,res_over,res_centi[15:0],
//          fault_valid,fault_count[31:0],synthetic_source}.
module video_performance_text #(
    parameter integer TAG_WIDTH=84
)(
    input wire clk,rst_n,stream_abort,
    input wire [87:0] performance_packet,
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
    reg [87:0] active;
    wire start=in_valid && in_sof;
    wire [87:0] selected=start ? performance_packet : active;
    wire [2:0] valid_bits={selected[87],selected[69],selected[51]};
    wire [2:0] over_bits={selected[86],selected[68],selected[50]};
    wire [15:0] src_rate=selected[85:70];
    wire [15:0] dsp_rate=selected[67:52];
    wire [15:0] res_rate=selected[49:34];
    wire fault_valid=selected[33];
    wire [31:0] fault_count=selected[32:1];
    wire synthetic_source=selected[0];
    wire numbers_ready;
    wire [19:0] src_bcd,dsp_bcd,res_bcd;
    osd_fps_decimal converter(.clk(clk),.rst_n(rst_n),
        .flush(stream_abort),.start(start),
        .source_fps_centi(src_rate),.display_fps_centi(dsp_rate),
        .result_fps_centi(res_rate),.done(numbers_ready),
        .source_bcd(src_bcd),.display_bcd(dsp_bcd),
        .result_bcd(res_bcd));
    wire [10:0] dx=in_x-11'd976;
    wire [4:0] col=dx[8:4];
    reg [2:0] row;
    reg [3:0] gy;
    reg panel;
    always @* begin
        row=0;gy=0;panel=0;
        if(in_x>=976 && in_x<1280)begin
            if(in_y>=208 && in_y<224)begin row=0;gy=in_y-208;panel=1;end
            else if(in_y>=232 && in_y<248)begin row=1;gy=in_y-232;panel=1;end
            else if(in_y>=256 && in_y<272)begin row=2;gy=in_y-256;panel=1;end
            else if(in_y>=280 && in_y<296)begin row=3;gy=in_y-280;panel=1;end
            else if(in_y>=304 && in_y<320 && synthetic_source)begin
                row=4;gy=in_y-304;panel=1;
            end
        end
    end
    localparam [127:0] SRC_LINE="SRC FPS:000.00";
    localparam [127:0] DSP_LINE="DSP FPS:000.00";
    localparam [127:0] RES_LINE="RES FPS:000.00";
    localparam [127:0] ERR_LINE="ERR HEX:00000000";
    localparam [71:0] SIM_LINE="SIM INPUT";
    reg [127:0] rate_line;
    reg [19:0] chosen_bcd;
    reg chosen_valid,chosen_over;
    reg [7:0] ch;
    reg [23:0] ink;
    function [7:0] hexchar;
        input [3:0] digit;
        begin hexchar=digit<10 ? 8'd48+{4'd0,digit} : 8'd55+{4'd0,digit};end
    endfunction
    always @* begin
        case(row)
            0:begin rate_line=SRC_LINE;chosen_bcd=src_bcd;
                chosen_valid=valid_bits[2];chosen_over=over_bits[2];end
            1:begin rate_line=DSP_LINE;chosen_bcd=dsp_bcd;
                chosen_valid=valid_bits[1];chosen_over=over_bits[1];end
            default:begin rate_line=RES_LINE;chosen_bcd=res_bcd;
                chosen_valid=valid_bits[0];chosen_over=over_bits[0];end
        endcase
        ch=" ";ink=row==4 ? 24'hffff00 : 24'h00ffff;
        if(row<3)begin
            if(col<14)ch=rate_line[(13-col)*8+:8];
            if(col>=8 && col<=13)begin
                if(!chosen_valid || !numbers_ready)begin
                    case(col)
                        8:ch="N";9:ch="/";10:ch="A";
                        default:ch=" ";
                    endcase
                end else if(chosen_over)begin
                    case(col)
                        8:ch="O";9:ch="V";10:ch="E";11:ch="R";
                        default:ch=" ";
                    endcase
                end else case(col)
                    8:ch=hexchar(chosen_bcd[19:16]);
                    9:ch=hexchar(chosen_bcd[15:12]);
                    10:ch=hexchar(chosen_bcd[11:8]);
                    11:ch=".";
                    12:ch=hexchar(chosen_bcd[7:4]);
                    default:ch=hexchar(chosen_bcd[3:0]);
                endcase
            end
        end else if(row==3)begin
            if(col<16)ch=ERR_LINE[(15-col)*8+:8];
            if(col>=8 && col<=15)begin
                if(fault_valid)ch=hexchar(fault_count[(15-col)*4+:4]);
                else case(col)
                    8:ch="N";9:ch="/";10:ch="A";
                    default:ch=" ";
                endcase
            end
        end else if(row==4 && synthetic_source && col<9)
            ch=SIM_LINE[(8-col)*8+:8];
    end
    reg v1,s1,l1,e1,panel1;
    reg [10:0] x1,y1;
    reg [23:0] rgb1,ink1;
    reg [TAG_WIDTH-1:0] tag1;
    reg [7:0] char1;
    reg [3:0] row1,bit1;
    wire [15:0] base_glyph;
    target_text_font font(.I_char(char1),.I_row(row1),.O_row_bits(base_glyph));
    wire [15:0] slash_glyph=(row1>=1 && row1<=14) ?
        (16'h0003 << (row1-1'b1)) : 16'd0;
    wire [15:0] dot_glyph=(row1>=12 && row1<=14) ? 16'h03c0 : 16'd0;
    wire [15:0] glyph=char1=="/" ? slash_glyph :
        char1=="." ? dot_glyph : base_glyph;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n || stream_abort)begin
            frame_open<=0;active<=0;
            v1<=0;s1<=0;l1<=0;e1<=0;panel1<=0;
            x1<=0;y1<=0;rgb1<=0;ink1<=0;tag1<=0;
            char1<=0;row1<=0;bit1<=0;
            out_valid<=0;out_sof<=0;out_eol<=0;out_eof<=0;
            out_x<=0;out_y<=0;out_rgb<=0;out_tag<=0;
        end else begin
            if(start)begin frame_open<=1;active<=performance_packet;end
            else if(in_valid && in_eof)frame_open<=0;
            v1<=in_valid && (frame_open || start);
            s1<=in_sof;l1<=in_eol;e1<=in_eof;
            x1<=in_x;y1<=in_y;rgb1<=in_rgb;tag1<=in_tag;
            panel1<=panel;char1<=ch;row1<=gy;
            bit1<=4'd15-dx[3:0];ink1<=ink;
            out_valid<=v1;out_sof<=v1&&s1;out_eol<=v1&&l1;out_eof<=v1&&e1;
            out_x<=x1;out_y<=y1;out_tag<=tag1;
            out_rgb<=!v1 ? 24'd0 : panel1 ?
                (glyph[bit1] ? ink1 : 24'h202020) : rgb1;
        end
    end
endmodule
