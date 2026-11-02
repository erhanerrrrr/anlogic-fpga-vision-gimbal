// Standalone resource probe only. Register-loading interface is NOT for A's board.
module target_info_probe(
    input wire clk,rst_n,
    input wire in_load,
    input wire [2:0] in_bank,in_probe,
    input wire [31:0] in_data,
    input wire in_valid,in_sof,in_eol,in_eof,in_abort,in_strobe,in_completed_ready,
    input wire [10:0] in_x,in_y,
    input wire [23:0] in_rgb,
    output reg [31:0] out_probe
);
    reg [255:0] config_words;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)config_words<=0;
        else if(in_load)begin
            case(in_bank)
                0:config_words[31:0]<=in_data;
                1:config_words[63:32]<=in_data;
                2:config_words[95:64]<=in_data;
                3:config_words[127:96]<=in_data;
                4:config_words[159:128]<=in_data;
                5:config_words[191:160]<=in_data;
                6:config_words[223:192]<=in_data;
                7:config_words[255:224]<=in_data;
            endcase
        end
    end
    wire [31:0] fid;
    wire [15:0] cfg;
    wire [1:0] tid;
    wire tv;
    wire [19:0] area;
    wire [10:0] xmin,ymin,xmax,ymax,cx,cy;
    wire [2:0] reason;
    wire [7:0] labels;
    wire [11:0] components;
    assign {fid,cfg,tid,tv,area,xmin,ymin,xmax,ymax,cx,cy,reason,labels,components}=config_words[159:0];
    wire v,s,l,e,ready;
    wire [23:0] rgb;
    wire [10:0] x,y;
    wire [31:0] rid;
    wire [159:0] p;
    wire [242:0] observed={v,s,l,e,ready,rgb,x,y,rid,p};
    video_target_info core(.clk(clk),.rst_n(rst_n),.stream_abort(in_abort),
        .in_valid(in_valid),.in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),
        .in_x(in_x),.in_y(in_y),.in_rgb(in_rgb),.in_refresh_id(config_words[191:160]),
        .completed_ready(in_completed_ready),.completed_refresh_id(config_words[223:192]),
        .expected_cfg_id(config_words[239:224]),.expected_target_id(config_words[241:240]),
        .result_strobe(in_strobe),.target_valid(tv),.result_frame_id(fid),.result_cfg_id(cfg),
        .result_target_id(tid),.area(area),.xmin(xmin),.ymin(ymin),.xmax(xmax),.ymax(ymax),
        .cx(cx),.cy(cy),.reason(reason),.labels_used(labels),.components(components),
        .out_valid(v),.out_sof(s),.out_eol(l),.out_eof(e),.out_x(x),.out_y(y),
        .out_rgb(rgb),.out_refresh_id(rid),.out_snapshot_ready(ready),.out_packet(p));
    always @*begin
        case(in_probe)
            0:out_probe=observed[31:0];1:out_probe=observed[63:32];
            2:out_probe=observed[95:64];3:out_probe=observed[127:96];
            4:out_probe=observed[159:128];5:out_probe=observed[191:160];
            6:out_probe=observed[223:192];7:out_probe={13'd0,observed[242:224]};
        endcase
    end
endmodule
