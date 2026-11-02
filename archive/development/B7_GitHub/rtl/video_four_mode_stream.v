// B2d: parallel real-C mask + Sobel, one shared RGB queue, one output cadence.
// in_mode is source-frame configuration (stable through EOF), NOT a button request.
module video_four_mode_stream #(
    parameter integer WIDTH=1280,HEIGHT=720,GUARD_ROWS=4,
    parameter integer FIFO_DEPTH=(1 << $clog2(WIDTH+8)),MAX_IDLE_CYCLES=4096,
    parameter [10:0] THRESHOLD=11'd128
)(
    input wire clk,rst_n,stream_abort,
    input wire in_valid,in_sof,in_eol,in_eof,
    input wire [23:0] in_rgb,
    input wire [10:0] in_x,in_y,
    input wire [31:0] in_epoch,in_frame_id,
    input wire [15:0] in_cfg_id,
    input wire [1:0] in_target_id,in_mode,
    input wire [7:0] min_main,min_diff_1,min_diff_2,
    output wire out_valid,out_sof,out_eol,out_eof,
    output wire [23:0] out_rgb,out_raw_rgb,out_gray_rgb,out_edge_rgb,out_mask_rgb,
    output wire [1:0] out_mode,
    output wire [10:0] out_x,out_y,
    output wire [31:0] out_epoch,out_frame_id,
    output wire [15:0] out_cfg_id,
    output wire [1:0] out_target_id,
    output wire out_abort,
    // Unmodified, filtered C mask stream before display-mode selection.
    output wire detect_valid,detect_mask,detect_sof,detect_eol,detect_eof,
    output wire [10:0] detect_x,detect_y,
    output wire [31:0] detect_epoch,detect_frame_id,
    output wire [15:0] detect_cfg_id,
    output wire [1:0] detect_target_id,
    output reg [15:0] error_flags,
    output wire [15:0] fifo_used,
    output reg [15:0] fifo_peak
);
    reg flush,input_active;
    reg [1:0] active_mode,mode_tags[0:1];
    reg mode_wr,mode_rd;
    reg [1:0] mode_count;
    reg [1:0] admission_faults;
    wire core_rst_n=rst_n && !flush;
    wire enabled=core_rst_n && !stream_abort;
    wire candidate=enabled && in_valid && (input_active || in_sof);
    wire pv,pm,ps,pl,pe,pa;
    wire [23:0] prgb;
    wire [10:0] px,py;
    wire [81:0] pt;
    wire [7:0] perr;
    wire [15:0] ppeak;
    wire gv,gs,gl,ge;
    wire [23:0] gray;
    wire [10:0] gx,gy;
    wire [81:0] gt;
    wire ev,es,el,ee,ea;
    wire [23:0] ergb;
    wire [10:0] ex,ey;
    wire [81:0] et;
    wire [4:0] eerr;
    wire alignment_bad=enabled && !pa && !ea &&
        ((pv!=ev) || (pv && ({px,py,ps,pl,pe,pt}!={ex,ey,es,el,ee,et})));
    wire mode_bad=candidate && input_active && in_mode!=active_mode;
    wire descriptor_bad=enabled && ((candidate && in_sof && mode_count==2) || (pv && mode_count==0));
    wire fail=stream_abort || pa || ea || alignment_bad || (|admission_faults);
    wire accept=candidate && !fail && !mode_bad && !descriptor_bad;
    wire paired=enabled && pv && ev && !fail && mode_count!=0;
    wire add_mode=accept && in_sof;
    wire remove_mode=paired && pe;
    assign out_abort=rst_n && (fail || flush);
    assign detect_valid=pv && !out_abort;
    assign detect_mask=pm;
    assign {detect_sof,detect_eol,detect_eof,detect_x,detect_y,
        detect_epoch,detect_frame_id,detect_cfg_id,detect_target_id}=
        {ps,pl,pe,px,py,pt};

    // Faults reset both pipelines together. Their own abort inputs are tied low:
    // this avoids a feedback loop of registered abort pulses between the stages.
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin flush<=0;error_flags<=0;fifo_peak<=0;end
        else begin
            flush<=fail;
            error_flags<=error_flags | {descriptor_bad,mode_bad,alignment_bad,eerr,perr} |
                (stream_abort?16'h0040:16'd0);
            if(ppeak>fifo_peak)fifo_peak<=ppeak;
        end
    end
    always @(posedge clk or negedge core_rst_n)begin
        if(!core_rst_n)begin
            input_active<=0;active_mode<=0;mode_wr<=0;mode_rd<=0;mode_count<=0;
            mode_tags[0]<=0;mode_tags[1]<=0;admission_faults<=0;
        end else begin
            // Admission errors are sampled at the input edge. The SOF pins stay
            // high after that edge while mode_count already includes this frame.
            admission_faults<={descriptor_bad,mode_bad};
            if(accept)begin input_active<=!in_eof;if(in_sof)active_mode<=in_mode;end
            if(add_mode)begin mode_tags[mode_wr]<=in_mode;mode_wr<=!mode_wr;end
            if(remove_mode)mode_rd<=!mode_rd;
            case({add_mode,remove_mode})
                2'b10:mode_count<=mode_count+1'b1;
                2'b01:mode_count<=mode_count-1'b1;
                default:mode_count<=mode_count;
            endcase
        end
    end
    // Pair validates the original stream. Use candidate here, not accept: its
    // registered abort cannot create a combinational loop through admission.
    video_rgb_mask_pair #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.GUARD_ROWS(GUARD_ROWS),
        .FIFO_DEPTH(FIFO_DEPTH),.MAX_IDLE_CYCLES(MAX_IDLE_CYCLES)) pair(
        .clk(clk),.rst_n(core_rst_n),.stream_abort(1'b0),
        .in_valid(candidate),.in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),.in_rgb(in_rgb),
        .in_x(in_x),.in_y(in_y),.in_epoch(in_epoch),.in_frame_id(in_frame_id),
        .in_cfg_id(in_cfg_id),.in_target_id(in_target_id),
        .min_main(min_main),.min_diff_1(min_diff_1),.min_diff_2(min_diff_2),
        .out_valid(pv),.out_rgb(prgb),.out_mask(pm),.out_sof(ps),.out_eol(pl),.out_eof(pe),
        .out_x(px),.out_y(py),.out_epoch(pt[81:50]),.out_frame_id(pt[49:18]),
        .out_cfg_id(pt[17:2]),.out_target_id(pt[1:0]),.out_abort(pa),.error_flags(perr),
        .fifo_used(fifo_used),.fifo_peak(ppeak));
    video_raw_gray_stage input_gray(
        .clk(clk),.rst_n(core_rst_n),.stream_abort(1'b0),.in_valid(candidate),.in_mask(1'b0),
        .in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),.in_rgb(in_rgb),
        .in_x(in_x),.in_y(in_y),.in_epoch(in_epoch),.in_frame_id(in_frame_id),
        .in_cfg_id(in_cfg_id),.in_target_id(in_target_id),
        .out_valid(gv),.out_raw_rgb(),.out_gray_rgb(gray),.out_mask(),
        .out_sof(gs),.out_eol(gl),.out_eof(ge),.out_x(gx),.out_y(gy),
        .out_epoch(gt[81:50]),.out_frame_id(gt[49:18]),.out_cfg_id(gt[17:2]),
        .out_target_id(gt[1:0]),.out_abort());
    video_gray_edge_stream #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_IDLE_CYCLES(MAX_IDLE_CYCLES),.THRESHOLD(THRESHOLD)) edges(
        .clk(clk),.rst_n(core_rst_n),.stream_abort(1'b0),.in_valid(gv),.in_gray(gray[7:0]),
        .in_sof(gs),.in_eol(gl),.in_eof(ge),.in_x(gx),.in_y(gy),
        .in_epoch(gt[81:50]),.in_frame_id(gt[49:18]),.in_cfg_id(gt[17:2]),.in_target_id(gt[1:0]),
        .out_valid(ev),.out_rgb(ergb),.out_sof(es),.out_eol(el),.out_eof(ee),
        .out_x(ex),.out_y(ey),.out_epoch(et[81:50]),.out_frame_id(et[49:18]),
        .out_cfg_id(et[17:2]),.out_target_id(et[1:0]),.out_abort(ea),.error_flags(eerr));

    wire final_valid,final_mask;
    wire [23:0] final_raw,final_gray;
    wire [106:0] final_metadata;
    reg [23:0] final_edge;
    reg [1:0] final_mode;
    video_raw_gray_stage output_stage(
        .clk(clk),.rst_n(core_rst_n),.stream_abort(fail),.in_valid(paired),.in_mask(pm),
        .in_sof(ps),.in_eol(pl),.in_eof(pe),.in_rgb(prgb),.in_x(px),.in_y(py),
        .in_epoch(pt[81:50]),.in_frame_id(pt[49:18]),.in_cfg_id(pt[17:2]),.in_target_id(pt[1:0]),
        .out_valid(final_valid),.out_raw_rgb(final_raw),.out_gray_rgb(final_gray),.out_mask(final_mask),
        .out_sof(final_metadata[106]),.out_eol(final_metadata[105]),.out_eof(final_metadata[104]),
        .out_x(final_metadata[103:93]),.out_y(final_metadata[92:82]),
        .out_epoch(final_metadata[81:50]),.out_frame_id(final_metadata[49:18]),
        .out_cfg_id(final_metadata[17:2]),.out_target_id(final_metadata[1:0]),.out_abort());
    always @(posedge clk or negedge core_rst_n)begin
        if(!core_rst_n)begin final_edge<=0;final_mode<=0;end
        else begin final_edge<=paired?ergb:24'd0;final_mode<=paired?mode_tags[mode_rd]:2'd0;end
    end
    assign out_valid=final_valid && enabled && !fail;
    assign out_raw_rgb=out_valid?final_raw:24'd0;
    assign out_gray_rgb=out_valid?final_gray:24'd0;
    assign out_edge_rgb=out_valid?final_edge:24'd0;
    assign out_mask_rgb={24{out_valid && final_mask}};
    assign out_mode=out_valid?final_mode:2'd0;
    assign out_rgb=out_mode==0?out_raw_rgb:out_mode==1?out_gray_rgb:out_mode==2?out_edge_rgb:out_mask_rgb;
    assign {out_sof,out_eol,out_eof,out_x,out_y,out_epoch,out_frame_id,out_cfg_id,out_target_id}=
        out_valid?final_metadata:107'd0;
endmodule
