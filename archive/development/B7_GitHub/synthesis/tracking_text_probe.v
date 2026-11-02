// Standalone observation wrapper; banked ports are not board pins.
module tracking_text_probe(
    input wire clk,rst_n,stream_abort,
    input wire in_load,
    input wire [1:0] in_bank,
    input wire [2:0] in_probe,
    input wire [31:0] in_data,
    input wire in_valid,in_sof,in_eol,in_eof,
    input wire [10:0] in_x,in_y,
    input wire [23:0] in_rgb,
    output reg [31:0] out_probe
);
    reg [127:0] config_words;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)config_words<=0;
        else if(in_load)case(in_bank)
            0:config_words[31:0]<=in_data;1:config_words[63:32]<=in_data;
            2:config_words[95:64]<=in_data;3:config_words[127:96]<=in_data;
        endcase
    end
    wire [37:0] packet=config_words[37:0];
    wire [83:0] tag=config_words[121:38];
    wire ov,os,ol,oe;
    wire [10:0] ox,oy;
    wire [23:0] rgb;
    wire [83:0] otag;
    wire [37:0] opacket;
    wire [191:0] observation={20'd0,ov,os,ol,oe,ox,oy,rgb,otag,opacket};
    video_tracking_text core(.clk(clk),.rst_n(rst_n),.stream_abort(stream_abort),.tracking_packet(packet),
        .in_valid(in_valid),.in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),.in_x(in_x),.in_y(in_y),.in_rgb(in_rgb),.in_tag(tag),
        .out_valid(ov),.out_sof(os),.out_eol(ol),.out_eof(oe),.out_x(ox),.out_y(oy),.out_rgb(rgb),.out_tag(otag),.out_tracking_packet(opacket));
    always @*case(in_probe)
        0:out_probe=observation[31:0];1:out_probe=observation[63:32];
        2:out_probe=observation[95:64];3:out_probe=observation[127:96];
        4:out_probe=observation[159:128];5:out_probe=observation[191:160];
        default:out_probe=0;
    endcase
endmodule
