// B2a: real C classifier/majority filter + checked, compact RGB queue.
// Legal input: row-major, no gaps inside a row; no backpressure.
// Metadata is stored once per frame, not once per pixel. See B2a_README.md.
module video_rgb_mask_pair #(
    parameter integer WIDTH=1280, HEIGHT=720, GUARD_ROWS=4,
    parameter integer FIFO_DEPTH=(1 << $clog2(WIDTH+8)),
    parameter integer MAX_IDLE_CYCLES=4096
)(
    input wire clk,rst_n,stream_abort,
    input wire in_valid,in_sof,in_eol,in_eof,
    input wire [23:0] in_rgb,
    input wire [10:0] in_x,in_y,
    input wire [31:0] in_epoch,in_frame_id,
    input wire [15:0] in_cfg_id,
    input wire [1:0] in_target_id,
    input wire [7:0] min_main,min_diff_1,min_diff_2,
    output wire out_valid,
    output wire [23:0] out_rgb,
    output wire out_mask,out_sof,out_eol,out_eof,
    output wire [10:0] out_x,out_y,
    output wire [31:0] out_epoch,out_frame_id,
    output wire [15:0] out_cfg_id,
    output wire [1:0] out_target_id,
    output reg out_abort,
    output reg [7:0] error_flags,
    output wire [15:0] fifo_used,
    output reg [15:0] fifo_peak
);
    localparam PB=$clog2(FIFO_DEPTH), CB=$clog2(FIFO_DEPTH+1);
    localparam IB=$clog2(MAX_IDLE_CYCLES+1);
    reg [23:0] rgb_queue[0:FIFO_DEPTH-1];
    reg [23:0] rgb_read;
    reg [PB-1:0] wr,rd;
    reg [CB-1:0] used;
    reg [81:0] frame_tags[0:1];
    reg tag_wr,tag_rd;
    reg [1:0] tag_count;
    wire [81:0] input_tag={in_epoch,in_frame_id,in_cfg_id,in_target_id};
    wire [81:0] head_tag=frame_tags[tag_rd];
    reg active,reset_filter;
    reg [10:0] ix,iy,mx,my;
    reg [81:0] active_tag;
    reg [23:0] active_thresholds;
    reg [IB-1:0] idle_count;
    wire enabled=rst_n && !reset_filter && !stream_abort;
    wire candidate=enabled && in_valid && (active || in_sof);
    wire input_bad=candidate && (
        in_x!=ix || in_y!=iy || in_sof!=(ix==0 && iy==0) ||
        in_eol!=(ix==WIDTH-1) || in_eof!=(ix==WIDTH-1 && iy==HEIGHT-1) ||
        (active && (input_tag!=active_tag ||
            {min_main,min_diff_1,min_diff_2}!=active_thresholds)));
    wire inline_gap=enabled && active && ix!=0 && !in_valid;

    // These are the frozen C implementations; only their interface is adapted.
    wire raw_valid,raw_mask;
    wire f_valid,f_mask,f_sof,f_eol,f_eof;
    wire [10:0] fx,fy;
    wire [31:0] ff;
    wire [15:0] fc;
    wire [1:0] ft;
    reg [10:0] dx,dy;
    reg ds,de;
    reg [31:0] df;
    reg [15:0] dc;
    reg [1:0] dt;
    wire core_rst_n=rst_n && !reset_filter && !stream_abort;
    wire mask_bad=enabled && f_valid && (tag_count==0 ||
        {ff,fc,ft}!=head_tag[49:0] || fx!=mx || fy!=my ||
        f_sof!=(mx==0 && my==0) || f_eol!=(mx==WIDTH-1) ||
        f_eof!=(mx==WIDTH-1 && my==HEIGHT-1));
    wire timeout_error=enabled && (active || used!=0) && !in_valid && !f_valid &&
        idle_count==MAX_IDLE_CYCLES-1;
    wire [7:0] faults={
        candidate && in_sof && tag_count==2,
        stream_abort,
        timeout_error,
        mask_bad,
        enabled && f_valid && used==0,
        candidate && used==FIFO_DEPTH,
        inline_gap,
        input_bad};
    wire fail=|faults;
    wire push=candidate && !fail;
    wire pop=enabled && f_valid && !fail;
    wire add_tag=push && in_sof;
    wire remove_tag=pop && f_eof;
    assign fifo_used=used;
    color_classifier_runtime classifier(
        .clk(clk),.rst_n(core_rst_n),.pixel_valid(push),.rgb(in_rgb),
        .active_color(in_target_id),.min_main(min_main),
        .min_diff_1(min_diff_1),.min_diff_2(min_diff_2),
        .mask_valid(raw_valid),.mask(raw_mask));
    always @(posedge clk or negedge core_rst_n) begin
        if(!core_rst_n)begin dx<=0;dy<=0;ds<=0;de<=0;df<=0;dc<=0;dt<=0;end
        else if(push)begin
            dx<=in_x;dy<=in_y;ds<=in_sof;de<=in_eof;
            df<=in_frame_id;dc<=in_cfg_id;dt<=in_target_id;
        end
    end
    mask_majority_3x3 #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) filter(
        .clk(clk),.rst_n(core_rst_n),.mask_valid(raw_valid),
        .mask(raw_mask && dy>=GUARD_ROWS && dy<HEIGHT-GUARD_ROWS),
        .x(dx),.y(dy),.sof(ds),.eof(de),.source_frame_id(df),.cfg_id(dc),.target_id(dt),
        .out_valid(f_valid),.out_mask(f_mask),.out_x(fx),.out_y(fy),
        .out_sof(f_sof),.out_eol(f_eol),.out_eof(f_eof),
        .out_frame_id(ff),.out_cfg_id(fc),.out_target_id(ft));

    // Synchronous read/write, no memory reset; never read an empty queue.
    // A full queue is rejected even on simultaneous pop: no RAM collision dependence.
    always @(posedge clk) begin
        if(push)rgb_queue[wr]<=in_rgb;
        if(pop)rgb_read<=rgb_queue[rd];
        if(add_tag)frame_tags[tag_wr]<=input_tag;
    end
    reg pair_valid,pm,ps,pl,pe;
    reg [10:0] px,py;
    reg [81:0] pt;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            wr<=0;rd<=0;used<=0;tag_wr<=0;tag_rd<=0;tag_count<=0;
            active<=0;reset_filter<=0;ix<=0;iy<=0;mx<=0;my<=0;
            active_tag<=0;active_thresholds<=0;idle_count<=0;
            out_abort<=0;error_flags<=0;fifo_peak<=0;
            pair_valid<=0;pm<=0;ps<=0;pl<=0;pe<=0;px<=0;py<=0;pt<=0;
        end else begin
            out_abort<=fail;reset_filter<=fail;
            error_flags<=error_flags | faults;
            pair_valid<=pop;
            if(fail)begin
                wr<=0;rd<=0;used<=0;tag_wr<=0;tag_rd<=0;tag_count<=0;
                active<=0;ix<=0;iy<=0;mx<=0;my<=0;idle_count<=0;
                pair_valid<=0;
            end else begin
                if(push)begin
                    wr<=(wr==FIFO_DEPTH-1)?0:wr+1'b1;
                    active<=!in_eof;
                    ix<=in_eol?0:ix+1'b1;
                    iy<=in_eof?0:in_eol?iy+1'b1:iy;
                    if(in_sof)begin active_tag<=input_tag;active_thresholds<={min_main,min_diff_1,min_diff_2};end
                end
                if(pop)begin
                    rd<=(rd==FIFO_DEPTH-1)?0:rd+1'b1;
                    mx<=f_eol?0:mx+1'b1;
                    my<=f_eof?0:f_eol?my+1'b1:my;
                    pm<=f_mask;ps<=f_sof;pl<=f_eol;pe<=f_eof;px<=fx;py<=fy;pt<=head_tag;
                end
                case({push,pop})
                    2'b10:begin used<=used+1'b1;if(used+1'b1>fifo_peak)fifo_peak<=used+1'b1;end
                    2'b01:used<=used-1'b1;
                    default:used<=used;
                endcase
                if(add_tag)tag_wr<=!tag_wr;
                if(remove_tag)tag_rd<=!tag_rd;
                case({add_tag,remove_tag})
                    2'b10:tag_count<=tag_count+1'b1;
                    2'b01:tag_count<=tag_count-1'b1;
                    default:tag_count<=tag_count;
                endcase
                if(!(active || used!=0) || in_valid || f_valid)idle_count<=0;
                else if(enabled)idle_count<=idle_count+1'b1;
            end
        end
    end
    assign out_valid=pair_valid && enabled;
    assign out_rgb=out_valid?rgb_read:24'd0;
    assign {out_mask,out_sof,out_eol,out_eof,out_x,out_y,out_epoch,out_frame_id,out_cfg_id,out_target_id}=
        out_valid?{pm,ps,pl,pe,px,py,pt}:108'd0;
endmodule
