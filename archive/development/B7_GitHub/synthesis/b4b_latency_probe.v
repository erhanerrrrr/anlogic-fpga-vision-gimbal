// Compact-I/O synthesis probe for B4b text. The banked test registers are
// counted in area; this is not the final board integration.
module b4b_latency_probe(
    input wire clk,rst_n,in_load,
    input wire [1:0] in_bank,
    input wire [31:0] in_data,
    input wire in_valid,in_sof,in_eol,in_eof,in_abort,
    input wire [10:0] in_x,in_y,
    input wire [23:0] in_rgb,
    output reg [31:0] out_probe
);
    reg [127:0] config_words;
    always @(posedge clk or negedge rst_n)
        if(!rst_n)config_words<=0;
        else if(in_load)case(in_bank)
            0:config_words[31:0]<=in_data;
            1:config_words[63:32]<=in_data;
            2:config_words[95:64]<=in_data;
            3:config_words[127:96]<=in_data;
        endcase
    wire ov,os,ol,oe;
    wire [10:0] ox,oy;
    wire [23:0] orgb;
    wire [1:0] otag;
    video_latency_text #(.TAG_WIDTH(2)) core(
        .clk(clk),.rst_n(rst_n),.stream_abort(in_abort),
        .stats_valid(config_words[108]),.stats_kind(config_words[107:106]),
        .sample_count(config_words[105:97]),
        .min_us(config_words[96:65]),.avg_us(config_words[64:33]),
        .max_us(config_words[32:1]),.synthetic_source(config_words[0]),
        .in_valid(in_valid),.in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),
        .in_x(in_x),.in_y(in_y),.in_rgb(in_rgb),.in_tag(config_words[110:109]),
        .out_valid(ov),.out_sof(os),.out_eol(ol),.out_eof(oe),
        .out_x(ox),.out_y(oy),.out_rgb(orgb),.out_tag(otag));
    always @(posedge clk or negedge rst_n)
        if(!rst_n)out_probe<=0;
        else out_probe<={ov,os,ol,oe,otag,ox,oy,4'd0} ^
            {8'd0,orgb} ^ {12'd0,config_words[127:111],3'd0};
endmodule
