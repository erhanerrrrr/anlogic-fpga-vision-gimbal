// B2c: checked gray raster -> full binary Sobel raster, only two gray line RAMs.
// Border slots are scheduled alongside windows; no extra edge row/frame buffer.
module video_gray_edge_stream #(
    parameter integer WIDTH=1280,HEIGHT=720,MAX_IDLE_CYCLES=4096,
    parameter [10:0] THRESHOLD=11'd128
)(
    input wire clk,rst_n,stream_abort,
    input wire in_valid,in_sof,in_eol,in_eof,
    input wire [7:0] in_gray,
    input wire [10:0] in_x,in_y,
    input wire [31:0] in_epoch,in_frame_id,
    input wire [15:0] in_cfg_id,
    input wire [1:0] in_target_id,
    output wire out_valid,
    output wire [23:0] out_rgb,
    output wire out_sof,out_eol,out_eof,
    output wire [10:0] out_x,out_y,
    output wire [31:0] out_epoch,out_frame_id,
    output wire [15:0] out_cfg_id,
    output wire [1:0] out_target_id,
    output reg out_abort,
    output reg [4:0] error_flags
);
    localparam IB=$clog2(MAX_IDLE_CYCLES+1);
    reg active,flush;
    reg [10:0] ix,iy;
    reg [81:0] active_tag;
    reg [IB-1:0] idle_count;
    wire [81:0] tag={in_epoch,in_frame_id,in_cfg_id,in_target_id};
    wire enabled=rst_n && !stream_abort && !flush;
    wire candidate=enabled && in_valid && (active || in_sof);
    wire input_bad=candidate && (in_x!=ix || in_y!=iy ||
        in_sof!=(ix==0 && iy==0) || in_eol!=(ix==WIDTH-1) ||
        in_eof!=(ix==WIDTH-1 && iy==HEIGHT-1) || (active && tag!=active_tag));
    wire inline_gap=enabled && active && ix!=0 && !in_valid;
    wire timeout_bad=enabled && active && !in_valid && idle_count==MAX_IDLE_CYCLES-1;
    wire align_bad;
    wire [4:0] faults={stream_abort,align_bad,input_bad,inline_gap,timeout_bad};
    wire fail=|faults;
    wire accept=candidate && !fail;
    wire core_rst_n=rst_n && !stream_abort && !flush;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            active<=0;flush<=0;ix<=0;iy<=0;active_tag<=0;idle_count<=0;
            out_abort<=0;error_flags<=0;
        end else begin
            flush<=fail;out_abort<=fail;error_flags<=error_flags|faults;
            if(fail)begin active<=0;ix<=0;iy<=0;idle_count<=0;end
            else begin
                if(accept)begin
                    active<=!in_eof;ix<=in_eol?0:ix+1'b1;
                    iy<=in_eof?0:in_eol?iy+1'b1:iy;
                    if(in_sof)active_tag<=tag;
                end
                if(!active || in_valid)idle_count<=0;
                else if(enabled)idle_count<=idle_count+1'b1;
            end
        end
    end
    wire wv,ws,wl,we;
    wire [71:0] patch;
    wire [10:0] wx,wy;
    wire [31:0] wf;
    window_3x3 #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) window_core(
        .clk(clk),.rst_n(core_rst_n),.in_valid(accept),.in_gray(in_gray),
        .in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),.in_x(in_x),.in_y(in_y),
        .in_source_frame_id(in_frame_id),.out_valid(wv),.out_window(patch),
        .out_center_x(wx),.out_center_y(wy),.out_sof(ws),.out_eol(wl),.out_eof(we),.out_source_frame_id(wf));
    wire ev;
    wire [7:0] edge_pixel;
    sobel_core sobel(.clk(clk),.rst_n(core_rst_n),.in_valid(wv),.in_window(patch),
        .in_threshold(THRESHOLD),.out_valid(ev),.out_gx(),.out_gy(),.out_magnitude(),.out_edge(edge_pixel));
    reg [10:0] ex,ey;
    reg [31:0] ef;
    // Parallel to Sobel's registered arithmetic output.
    always @(posedge clk or negedge core_rst_n)begin
        if(!core_rst_n)begin ex<=0;ey<=0;ef<=0;end
        else begin ex<=wx;ey<=wy;ef<=wf;end
    end
    reg sv,se;
    reg [10:0] sx,sy;
    reg [81:0] st;
    reg right_pending,tail_pending;
    reg [10:0] right_y;
    reg [11:0] tail_index;
    reg [81:0] pending_tag;
    reg schedule_v;
    reg [10:0] schedule_x,schedule_y;
    reg [81:0] schedule_tag;
    reg pv;
    reg [10:0] px,py;
    reg [81:0] pt;
    always @(posedge clk or negedge core_rst_n)begin
        if(!core_rst_n)begin
            sv<=0;se<=0;sx<=0;sy<=0;st<=0;right_pending<=0;tail_pending<=0;
            right_y<=0;tail_index<=0;pending_tag<=0;
            schedule_v<=0;schedule_x<=0;schedule_y<=0;schedule_tag<=0;
            pv<=0;px<=0;py<=0;pt<=0;
        end else begin
            sv<=accept;
            if(accept)begin sx<=in_x;sy<=in_y;se<=in_eof;st<=tag;end
            schedule_v<=0;schedule_x<=0;schedule_y<=0;schedule_tag<=0;
            if(tail_pending)begin
                schedule_v<=1;
                schedule_x<=tail_index==0?WIDTH-1:tail_index-1'b1;
                schedule_y<=tail_index==0?HEIGHT-2:HEIGHT-1;
                schedule_tag<=pending_tag;
                if(tail_index==WIDTH)begin tail_pending<=0;tail_index<=0;end
                else tail_index<=tail_index+1'b1;
            end else if(right_pending)begin
                schedule_v<=1;schedule_x<=WIDTH-1;schedule_y<=right_y;schedule_tag<=pending_tag;
                right_pending<=0;
            end else if(sv && sy>=1 && sx>=1)begin
                schedule_v<=1;schedule_x<=sx-1'b1;schedule_y<=sy-1'b1;schedule_tag<=st;
            end
            if(sv && sy>=1 && sx==WIDTH-1)begin
                pending_tag<=st;
                if(se)begin tail_pending<=1;tail_index<=0;end
                else begin right_pending<=1;right_y<=sy-1'b1;end
            end
            pv<=schedule_v;px<=schedule_x;py<=schedule_y;pt<=schedule_tag;
        end
    end
    wire border=px==0 || py==0 || px==WIDTH-1 || py==HEIGHT-1;
    assign align_bad=enabled && pv && !border && (!ev || ex!=px || ey!=py || ef!=pt[49:18]);
    assign out_valid=pv && enabled && !align_bad;
    assign out_rgb=out_valid && !border?{3{edge_pixel}}:24'd0;
    assign out_sof=out_valid && px==0 && py==0;
    assign out_eol=out_valid && px==WIDTH-1;
    assign out_eof=out_eol && py==HEIGHT-1;
    assign {out_x,out_y,out_epoch,out_frame_id,out_cfg_id,out_target_id}=out_valid?{px,py,pt}:104'd0;
endmodule
