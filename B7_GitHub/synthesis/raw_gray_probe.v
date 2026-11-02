// Standalone resource observation wrapper, not a board pin interface.
module raw_gray_probe(
    input wire clk,rst_n,in_load,
    input wire [1:0] in_bank,
    input wire [2:0] in_probe,
    input wire [31:0] in_data,
    input wire in_valid,in_sof,in_eol,in_eof,in_abort,
    input wire [10:0] in_x,in_y,
    input wire [23:0] in_rgb,
    output reg [31:0] out_probe
);
    reg [127:0] config_words;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)config_words<=0;
        else if(in_load)case(in_bank)
            0:config_words[31:0]<=in_data;
            1:config_words[63:32]<=in_data;
            2:config_words[95:64]<=in_data;
            3:config_words[127:96]<=in_data;
        endcase
    end
    wire v,m,s,l,e,a;
    wire [23:0] rgb,gray;
    wire [10:0] x,y;
    wire [81:0] tag;
    wire [7:0] errors;
    wire [15:0] used,peak;
    wire [223:0] observation={26'd0,v,m,s,l,e,a,rgb,gray,x,y,tag,errors,used,peak};
    video_rgb_mask_raw_gray core(.clk(clk),.rst_n(rst_n),.stream_abort(in_abort),
        .in_valid(in_valid),.in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),
        .in_x(in_x),.in_y(in_y),.in_rgb(in_rgb),
        .in_epoch(config_words[31:0]),.in_frame_id(config_words[63:32]),
        .in_cfg_id(config_words[79:64]),.in_target_id(config_words[81:80]),
        .min_main(config_words[89:82]),.min_diff_1(config_words[97:90]),.min_diff_2(config_words[105:98]),
        .out_valid(v),.out_mask(m),.out_sof(s),.out_eol(l),.out_eof(e),.out_abort(a),
        .out_x(x),.out_y(y),.out_raw_rgb(rgb),.out_gray_rgb(gray),.out_epoch(tag[81:50]),.out_frame_id(tag[49:18]),
        .out_cfg_id(tag[17:2]),.out_target_id(tag[1:0]),.error_flags(errors),.fifo_used(used),.fifo_peak(peak));
    always @*case(in_probe)
        0:out_probe=observation[31:0];1:out_probe=observation[63:32];
        2:out_probe=observation[95:64];3:out_probe=observation[127:96];
        4:out_probe=observation[159:128];5:out_probe=observation[191:160];
        6:out_probe=observation[223:192];default:out_probe=0;
    endcase
endmodule
