// C8: one request, next new source frame, fixed 16x16 raw RGB ROI.
// Legal raster input; synchronous request pulse. Configuration is compile-time.
module roi_color_sampler #(
    parameter WIDTH=1280, HEIGHT=720,
    parameter ROI_X=(WIDTH-16)/2, ROI_Y=(HEIGHT-16)/2
)(
    input wire clk,rst_n,pixel_valid,
    input wire [23:0] rgb,
    input wire [10:0] x,y,
    input wire sof,eof,
    input wire [31:0] source_frame_id,
    input wire [15:0] cfg_id,
    input wire [1:0] active_color,
    input wire sample_req,
    output wire busy,
    output reg request_ignored,
    output reg [15:0] ignored_requests,
    output reg sample_done,sample_ok,
    output reg [1:0] sample_reason,
    output reg [31:0] sample_frame_id,
    output reg [15:0] sample_cfg_id,
    output reg [1:0] sample_target_id,
    output reg [8:0] sample_count,
    output reg [15:0] sum_r,sum_g,sum_b,
    output reg [7:0] min_r,min_g,min_b,max_r,max_g,max_b,
    output wire [7:0] mean_r,mean_g,mean_b
);
    localparam IDLE=2'd0, WAIT_FRAME=2'd1, CAPTURE=2'd2;
    reg [1:0] state;
    reg seen_sof;
    reg [31:0] last_sof_id, capture_id;
    reg [15:0] capture_cfg;
    reg [1:0] capture_color;
    reg [8:0] count,n_count;
    reg [15:0] sr,sg,sb,n_sr,n_sg,n_sb;
    reg [7:0] lr,lg,lb,hr,hg,hb,n_lr,n_lg,n_lb,n_hr,n_hg,n_hb;
    wire start = state==WAIT_FRAME && pixel_valid && sof &&
                 (!seen_sof || source_frame_id!=last_sof_id);
    wire interrupted = state==CAPTURE && pixel_valid && sof;
    wire take = pixel_valid && (start || state==CAPTURE) && !interrupted;
    wire inside_roi = x>=ROI_X && x<ROI_X+16 && y>=ROI_Y && y<ROI_Y+16;
    assign busy = state!=IDLE;
    // Means are valid only on successful 256-pixel samples; no divider needed.
    assign mean_r=sample_ok ? sum_r[15:8] : 8'b0;
    assign mean_g=sample_ok ? sum_g[15:8] : 8'b0;
    assign mean_b=sample_ok ? sum_b[15:8] : 8'b0;
    always @* begin
        n_count=start ? 9'b0 : count;
        n_sr=start ? 16'b0 : sr; n_sg=start ? 16'b0 : sg; n_sb=start ? 16'b0 : sb;
        n_lr=start ? 8'd255 : lr; n_lg=start ? 8'd255 : lg; n_lb=start ? 8'd255 : lb;
        n_hr=start ? 8'b0 : hr; n_hg=start ? 8'b0 : hg; n_hb=start ? 8'b0 : hb;
        if(take && inside_roi) begin
            n_count=n_count+9'd1;
            n_sr=n_sr+{8'b0,rgb[23:16]};
            n_sg=n_sg+{8'b0,rgb[15:8]};
            n_sb=n_sb+{8'b0,rgb[7:0]};
            if(rgb[23:16]<n_lr) n_lr=rgb[23:16];
            if(rgb[15:8]<n_lg) n_lg=rgb[15:8];
            if(rgb[7:0]<n_lb) n_lb=rgb[7:0];
            if(rgb[23:16]>n_hr) n_hr=rgb[23:16];
            if(rgb[15:8]>n_hg) n_hg=rgb[15:8];
            if(rgb[7:0]>n_hb) n_hb=rgb[7:0];
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=IDLE;seen_sof<=0;last_sof_id<=0;
            capture_id<=0;capture_cfg<=0;capture_color<=0;
            count<=0;sr<=0;sg<=0;sb<=0;
            lr<=255;lg<=255;lb<=255;hr<=0;hg<=0;hb<=0;
            request_ignored<=0;ignored_requests<=0;
            sample_done<=0;sample_ok<=0;sample_reason<=0;
            sample_frame_id<=0;sample_cfg_id<=0;sample_target_id<=0;sample_count<=0;
            sum_r<=0;sum_g<=0;sum_b<=0;
            min_r<=0;min_g<=0;min_b<=0;max_r<=0;max_g<=0;max_b<=0;
        end else begin
            sample_done<=0;request_ignored<=0;
            if(pixel_valid && sof) begin seen_sof<=1;last_sof_id<=source_frame_id;end
            if(sample_req) begin
                if(state==IDLE) state<=WAIT_FRAME;
                else begin
                    request_ignored<=1;
                    if(ignored_requests!=16'hffff) ignored_requests<=ignored_requests+16'd1;
                end
            end
            if(start) begin
                state<=CAPTURE;capture_id<=source_frame_id;
                capture_cfg<=cfg_id;capture_color<=active_color;
            end
            if(take) begin
                count<=n_count;sr<=n_sr;sg<=n_sg;sb<=n_sb;
                lr<=n_lr;lg<=n_lg;lb<=n_lb;hr<=n_hr;hg<=n_hg;hb<=n_hb;
            end
            if((take && eof) || interrupted) begin
                state<=IDLE;sample_done<=1;
                sample_ok<=!interrupted && n_count==9'd256;
                sample_reason<=interrupted ? 2'd2 : (n_count==9'd256 ? 2'd0 : 2'd1);
                sample_frame_id<=start ? source_frame_id : capture_id;
                sample_cfg_id<=start ? cfg_id : capture_cfg;
                sample_target_id<=start ? active_color : capture_color;
                sample_count<=n_count;sum_r<=n_sr;sum_g<=n_sg;sum_b<=n_sb;
                min_r<=n_count==0 ? 8'b0 : n_lr;min_g<=n_count==0 ? 8'b0 : n_lg;min_b<=n_count==0 ? 8'b0 : n_lb;
                max_r<=n_hr;max_g<=n_hg;max_b<=n_hb;
            end
        end
    end
endmodule
