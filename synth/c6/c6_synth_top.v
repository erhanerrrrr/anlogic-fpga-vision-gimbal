// Synthesis-only harness: all result bits are observable through a word selector.
// This is not a proposed board-level integration or a deployed interface.
module c6_synth_top(
    input wire clk,rst_n,pixel_valid,
    input wire [23:0] rgb,
    input wire [10:0] x,y,
    input wire sof,eol,eof,
    input wire [31:0] source_frame_id,
    input wire [15:0] cfg_id,
    input wire [1:0] active_color,
    input wire [3:0] read_index,
    output wire result_strobe,
    output reg [15:0] result_word
);
    wire target_valid;
    wire [31:0] result_frame_id;
    wire [15:0] result_cfg_id;
    wire [1:0] target_id;
    wire [19:0] area;
    wire [10:0] cx,xmin,xmax,cy,ymin,ymax;
    wire [2:0] reject_reason;
    wire [19:0] debug_count;
    wire [10:0] debug_xmin,debug_ymin,debug_xmax,debug_ymax;
    wire [207:0] result_bits={4'b0,target_valid,result_frame_id,result_cfg_id,target_id,
        area,xmin,ymin,xmax,ymax,cx,cy,reject_reason,debug_count,debug_xmin,debug_ymin,debug_xmax,debug_ymax};
    rgb_validated_result core(
        .clk(clk),.rst_n(rst_n),.pixel_valid(pixel_valid),.rgb(rgb),.x(x),.y(y),
        .sof(sof),.eol(eol),.eof(eof),.source_frame_id(source_frame_id),.cfg_id(cfg_id),.active_color(active_color),
        .result_strobe(result_strobe),.target_valid(target_valid),.result_frame_id(result_frame_id),
        .result_cfg_id(result_cfg_id),.target_id(target_id),.area(area),.cx(cx),.cy(cy),
        .xmin(xmin),.xmax(xmax),.ymin(ymin),.ymax(ymax),
        .reject_reason(reject_reason),.debug_count(debug_count),.debug_xmin(debug_xmin),
        .debug_ymin(debug_ymin),.debug_xmax(debug_xmax),.debug_ymax(debug_ymax));
    always @* begin
        case(read_index)
            0:result_word=result_bits[15:0];
            1:result_word=result_bits[31:16];
            2:result_word=result_bits[47:32];
            3:result_word=result_bits[63:48];
            4:result_word=result_bits[79:64];
            5:result_word=result_bits[95:80];
            6:result_word=result_bits[111:96];
            7:result_word=result_bits[127:112];
            8:result_word=result_bits[143:128];
            9:result_word=result_bits[159:144];
            10:result_word=result_bits[175:160];
            11:result_word=result_bits[191:176];
            12:result_word=result_bits[207:192];
            default:result_word=0;
        endcase
    end
endmodule
