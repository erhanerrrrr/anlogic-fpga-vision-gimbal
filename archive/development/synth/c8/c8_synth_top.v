// Synthesis-only harness: all result bits are observable through a word selector.
// This is not a proposed board-level integration or a deployed interface.
module c8_synth_top(
    input wire clk,rst_n,pixel_valid,sample_req,
    input wire [23:0] rgb,
    input wire [10:0] x,y,
    input wire sof,eol,eof,
    input wire [31:0] source_frame_id,
    input wire [15:0] cfg_id,
    input wire [1:0] active_color,
    input wire [4:0] read_index,
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
    wire [207:0] detector_bits={4'b0,target_valid,result_frame_id,result_cfg_id,target_id,
        area,xmin,ymin,xmax,ymax,cx,cy,reject_reason,debug_count,debug_xmin,debug_ymin,debug_xmax,debug_ymax};
    wire busy,request_ignored,sample_done,sample_ok;
    wire [15:0] ignored_requests,sample_cfg_id,sum_r,sum_g,sum_b;
    wire [1:0] sample_reason,sample_target_id;
    wire [31:0] sample_frame_id;
    wire [8:0] sample_count;
    wire [7:0] min_r,min_g,min_b,max_r,max_g,max_b,mean_r,mean_g,mean_b;
    wire [415:0] result_bits={7'b0,busy,request_ignored,ignored_requests,sample_done,sample_ok,
        sample_reason,sample_frame_id,sample_cfg_id,sample_target_id,sample_count,
        sum_r,sum_g,sum_b,min_r,min_g,min_b,max_r,max_g,max_b,mean_r,mean_g,mean_b,detector_bits};
    rgb_sampling_result core(
        .clk(clk),.rst_n(rst_n),.pixel_valid(pixel_valid),.rgb(rgb),.x(x),.y(y),
        .sof(sof),.eol(eol),.eof(eof),.source_frame_id(source_frame_id),.cfg_id(cfg_id),.active_color(active_color),
        .result_strobe(result_strobe),.target_valid(target_valid),.result_frame_id(result_frame_id),
        .result_cfg_id(result_cfg_id),.target_id(target_id),.area(area),.cx(cx),.cy(cy),
        .xmin(xmin),.xmax(xmax),.ymin(ymin),.ymax(ymax),
        .reject_reason(reject_reason),.debug_count(debug_count),.debug_xmin(debug_xmin),
        .debug_ymin(debug_ymin),.debug_xmax(debug_xmax),.debug_ymax(debug_ymax),
        .sample_req(sample_req),.busy(busy),.request_ignored(request_ignored),.ignored_requests(ignored_requests),
        .sample_done(sample_done),.sample_ok(sample_ok),.sample_reason(sample_reason),
        .sample_frame_id(sample_frame_id),.sample_cfg_id(sample_cfg_id),.sample_target_id(sample_target_id),
        .sample_count(sample_count),.sum_r(sum_r),.sum_g(sum_g),.sum_b(sum_b),
        .min_r(min_r),.min_g(min_g),.min_b(min_b),.max_r(max_r),.max_g(max_g),.max_b(max_b),
        .mean_r(mean_r),.mean_g(mean_g),.mean_b(mean_b));
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
            13:result_word=result_bits[223:208];
            14:result_word=result_bits[239:224];
            15:result_word=result_bits[255:240];
            16:result_word=result_bits[271:256];
            17:result_word=result_bits[287:272];
            18:result_word=result_bits[303:288];
            19:result_word=result_bits[319:304];
            20:result_word=result_bits[335:320];
            21:result_word=result_bits[351:336];
            22:result_word=result_bits[367:352];
            23:result_word=result_bits[383:368];
            24:result_word=result_bits[399:384];
            25:result_word=result_bits[415:400];
            default:result_word=0;
        endcase
    end
endmodule
