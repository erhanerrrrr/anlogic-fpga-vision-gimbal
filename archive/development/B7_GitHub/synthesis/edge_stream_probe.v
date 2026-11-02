// Standalone resource observation wrapper, not a board pin interface.
module edge_stream_probe(
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
    wire v,m,s,l,e,a;
    wire [23:0] rgb,gray;
    wire [10:0] x,y;
    wire [81:0] tag;
    wire [12:0] errors;
    wire ev,es,el,ee;wire [23:0] ergb;wire [10:0] ex,ey;wire [81:0] etag;
    wire [15:0] used,peak;
    wire [383:0] observation={49'd0,v,m,s,l,e,a,rgb,gray,x,y,tag,errors,used,peak,ev,es,el,ee,ergb,ex,ey,etag};
    video_rgb_mask_edge core(.clk(clk),.rst_n(rst_n),.stream_abort(in_abort),
        .in_valid(in_valid),.in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),
        .in_x(in_x),.in_y(in_y),.in_rgb(in_rgb),
        .in_epoch(config_words[31:0]),.in_frame_id(config_words[63:32]),
        .in_cfg_id(config_words[79:64]),.in_target_id(config_words[81:80]),
        .min_main(config_words[89:82]),.min_diff_1(config_words[97:90]),.min_diff_2(config_words[105:98]),
        .base_valid(v),.base_mask(m),.base_sof(s),.base_eol(l),.base_eof(e),.out_abort(a),
        .base_x(x),.base_y(y),.base_raw_rgb(rgb),.base_gray_rgb(gray),.base_epoch(tag[81:50]),.base_frame_id(tag[49:18]),
        .base_cfg_id(tag[17:2]),.base_target_id(tag[1:0]),.out_valid(ev),.out_sof(es),.out_eol(el),.out_eof(ee),.out_rgb(ergb),.out_x(ex),.out_y(ey),
        .out_epoch(etag[81:50]),.out_frame_id(etag[49:18]),.out_cfg_id(etag[17:2]),.out_target_id(etag[1:0]),
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
