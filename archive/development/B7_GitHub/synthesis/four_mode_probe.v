// Standalone resource observation wrapper, not a board pin interface.
module four_mode_probe(
    input wire clk,rst_n,in_load,
    input wire [1:0] in_bank,
    input wire [3:0] in_probe,
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
    wire v,s,l,e,a;
    wire [23:0] rgb,gray,edge_rgb,mask_rgb,selected;
    wire [1:0] mode;
    wire [10:0] x,y;
    wire [81:0] tag;
    wire [15:0] errors,used,peak;
    wire [383:0] observation={105'd0,v,s,l,e,a,rgb,gray,edge_rgb,mask_rgb,selected,mode,x,y,tag,errors,used,peak};
    video_four_mode_stream core(.clk(clk),.rst_n(rst_n),.stream_abort(in_abort),
        .in_valid(in_valid),.in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),
        .in_x(in_x),.in_y(in_y),.in_rgb(in_rgb),.in_mode(config_words[107:106]),
        .in_epoch(config_words[31:0]),.in_frame_id(config_words[63:32]),
        .in_cfg_id(config_words[79:64]),.in_target_id(config_words[81:80]),
        .min_main(config_words[89:82]),.min_diff_1(config_words[97:90]),.min_diff_2(config_words[105:98]),
        .out_valid(v),.out_sof(s),.out_eol(l),.out_eof(e),.out_abort(a),
        .out_x(x),.out_y(y),.out_raw_rgb(rgb),.out_gray_rgb(gray),.out_edge_rgb(edge_rgb),.out_mask_rgb(mask_rgb),
        .out_rgb(selected),.out_mode(mode),.out_epoch(tag[81:50]),.out_frame_id(tag[49:18]),
        .out_cfg_id(tag[17:2]),.out_target_id(tag[1:0]),
        .error_flags(errors),.fifo_used(used),.fifo_peak(peak));
    always @*case(in_probe)
        0:out_probe=observation[31:0];1:out_probe=observation[63:32];
        2:out_probe=observation[95:64];3:out_probe=observation[127:96];
        4:out_probe=observation[159:128];5:out_probe=observation[191:160];
                6:out_probe=observation[223:192];
        7:out_probe=observation[255:224];
        8:out_probe=observation[287:256];
        9:out_probe=observation[319:288];
        10:out_probe=observation[351:320];
        11:out_probe=observation[383:352];default:out_probe=0;
    endcase
endmodule
