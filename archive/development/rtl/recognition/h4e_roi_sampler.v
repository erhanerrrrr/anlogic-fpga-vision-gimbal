// Sidecar on the SAME raw input clock as h4e_capture_tracker.
// accepted_sof/new_source_sof are combinational; frame_abort is registered.
// Never reset this module with processing_rst_n. No configuration outputs.
module h4e_roi_sampler #(parameter WIDTH=1280, HEIGHT=720)(
    input wire clk,rst_n,sample_req,source_flush,
    input wire [31:0] active_epoch,source_epoch,source_frame_id,
    input wire [15:0] requested_cfg_id,
    input wire [1:0] requested_color,
    input wire accepted_sof,new_source_sof,frame_abort,
    input wire pixel_valid,sof,eof,
    input wire [23:0] rgb,
    input wire [10:0] x,y,
    output wire busy,
    output reg request_ignored,sample_done,sample_ok,
    output reg [1:0] sample_reason,
    output reg [31:0] sample_frame_id,sample_epoch,
    output reg [15:0] sample_cfg_id,
    output reg [1:0] sample_target_id,
    output reg [8:0] sample_count,
    output reg [15:0] sum_r,sum_g,sum_b,
    output reg [7:0] min_r,min_g,min_b,max_r,max_g,max_b,
    output wire [7:0] mean_r,mean_g,mean_b
);
    localparam IDLE=0, WAIT_FRAME=1, CAPTURE=2, VERIFY=3;
    localparam RX=(WIDTH-16)/2, RY=(HEIGHT-16)/2;
    reg [1:0] state;
    reg prior_accepted;
    reg [8:0] count;
    reg [15:0] sr,sg,sb;
    reg [7:0] lr,lg,lb,hr,hg,hb;
    reg [31:0] held_frame,held_epoch;
    reg [15:0] held_cfg;
    reg [1:0] held_color;
    wire start=state==WAIT_FRAME && new_source_sof && !source_flush;
    wire taking=state==CAPTURE && pixel_valid && !sof;
    wire inside_roi=x>=RX && x<RX+16 && y>=RY && y<RY+16;
    // A new accepted SOF may abort the OLD detector job; don't abort the
    // newly started sample on the following cycle because of that pulse.
    wire cancel=source_flush || ((state==CAPTURE || state==VERIFY) &&
        (active_epoch!=held_epoch || (pixel_valid && sof) ||
         (frame_abort && !prior_accepted)));
    assign busy=state!=IDLE;
    assign mean_r=sample_ok ? sum_r[15:8] : 8'd0;
    assign mean_g=sample_ok ? sum_g[15:8] : 8'd0;
    assign mean_b=sample_ok ? sum_b[15:8] : 8'd0;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state<=IDLE;prior_accepted<=0;count<=0;sr<=0;sg<=0;sb<=0;
            lr<=255;lg<=255;lb<=255;hr<=0;hg<=0;hb<=0;
            held_frame<=0;held_epoch<=0;held_cfg<=0;held_color<=0;
            request_ignored<=0;sample_done<=0;sample_ok<=0;sample_reason<=0;
            sample_frame_id<=0;sample_epoch<=0;sample_cfg_id<=0;sample_target_id<=0;
            sample_count<=0;sum_r<=0;sum_g<=0;sum_b<=0;
            min_r<=0;min_g<=0;min_b<=0;max_r<=0;max_g<=0;max_b<=0;
        end else begin
            prior_accepted<=accepted_sof;
            sample_done<=0;request_ignored<=sample_req && (busy || source_flush);
            if(sample_req && !busy && !source_flush) state<=WAIT_FRAME;
            if(start) begin
                state<=CAPTURE;count<=0;sr<=0;sg<=0;sb<=0;
                lr<=255;lg<=255;lb<=255;hr<=0;hg<=0;hb<=0;
                held_frame<=source_frame_id;held_epoch<=source_epoch;
                held_cfg<=requested_cfg_id;held_color<=requested_color;
            end
            if(taking) begin
                if(inside_roi && count<256) begin
                    count<=count+9'd1;
                    sr<=sr+{8'd0,rgb[23:16]};sg<=sg+{8'd0,rgb[15:8]};sb<=sb+{8'd0,rgb[7:0]};
                    if(rgb[23:16]<lr) lr<=rgb[23:16];
                    if(rgb[15:8]<lg) lg<=rgb[15:8];
                    if(rgb[7:0]<lb) lb<=rgb[7:0];
                    if(rgb[23:16]>hr) hr<=rgb[23:16];
                    if(rgb[15:8]>hg) hg<=rgb[15:8];
                    if(rgb[7:0]>hb) hb<=rgb[7:0];
                end
                if(eof) state<=VERIFY;
            end
            // Publish one clock after raw EOF, after ingress validates it.
            // Failed operations return zero statistics, never a partial sample.
            if(busy && (cancel || state==VERIFY)) begin
                state<=IDLE;sample_done<=1;
                sample_ok<=!cancel && count==256;
                sample_reason<=cancel ? 2'd2 : (count==256 ? 2'd0 : 2'd1);
                sample_frame_id<=state==WAIT_FRAME ? 32'd0 : held_frame;
                sample_epoch<=state==WAIT_FRAME ? 32'd0 : held_epoch;
                sample_cfg_id<=state==WAIT_FRAME ? 16'd0 : held_cfg;
                sample_target_id<=state==WAIT_FRAME ? 2'd0 : held_color;
                sample_count<=!cancel && count==256 ? count : 9'd0;
                sum_r<=!cancel && count==256 ? sr : 16'd0;
                sum_g<=!cancel && count==256 ? sg : 16'd0;
                sum_b<=!cancel && count==256 ? sb : 16'd0;
                min_r<=!cancel && count==256 ? lr : 8'd0;
                min_g<=!cancel && count==256 ? lg : 8'd0;
                min_b<=!cancel && count==256 ? lb : 8'd0;
                max_r<=!cancel && count==256 ? hr : 8'd0;
                max_g<=!cancel && count==256 ? hg : 8'd0;
                max_b<=!cancel && count==256 ? hb : 8'd0;
            end
        end
    end
endmodule
