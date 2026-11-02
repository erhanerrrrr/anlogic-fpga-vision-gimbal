// One outstanding operation. New settings commit only at a NEW source SOF.
module calibration_control #(parameter [15:0] INITIAL_CFG_ID=16'd0)(
    input wire clk,rst_n,pixel_valid,sof,
    input wire [31:0] source_frame_id,
    input wire calibrate_req,color_select_req,
    input wire [1:0] color_select,
    input wire sample_done,params_valid,
    input wire [2:0] params_reason,
    input wire [31:0] sample_frame_id,
    input wire [1:0] params_color,
    input wire [7:0] params_main,params_diff_1,params_diff_2,
    output wire sample_req,busy,
    output reg request_ignored,select_ignored,
    output reg [15:0] ignored_requests,
    output reg calibration_done,calibration_ok,
    output reg [2:0] calibration_reason,
    output reg [31:0] calibration_frame_id,
    output reg cfg_applied,pending_valid,
    output reg [1:0] pending_color,active_color,
    output reg [7:0] pending_main,pending_diff_1,pending_diff_2,active_main,active_diff_1,active_diff_2,
    output reg [15:0] active_cfg_id,
    output wire [1:0] pixel_color,
    output wire [7:0] pixel_main,pixel_diff_1,pixel_diff_2,
    output wire [15:0] pixel_cfg_id,
    output reg active_calibrated
);
    reg waiting_sample,seen_sof,pending_calibrated;
    reg [31:0] last_sof_id;
    wire new_sof=pixel_valid && sof && (!seen_sof || source_frame_id!=last_sof_id);
    wire apply_now=pending_valid && new_sof;
    assign busy=waiting_sample || pending_valid;
    assign sample_req=calibrate_req && !busy;
    // First pixel uses pending values on the SAME edge that commits them.
    assign pixel_color=apply_now ? pending_color : active_color;
    assign pixel_main=apply_now ? pending_main : active_main;
    assign pixel_diff_1=apply_now ? pending_diff_1 : active_diff_1;
    assign pixel_diff_2=apply_now ? pending_diff_2 : active_diff_2;
    assign pixel_cfg_id=apply_now ? active_cfg_id+16'd1 : active_cfg_id;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            active_calibrated<=0;pending_calibrated<=0;waiting_sample<=0;seen_sof<=0;last_sof_id<=0;pending_valid<=0;
            pending_color<=0;pending_main<=0;pending_diff_1<=0;pending_diff_2<=0;
            active_color<=0;active_main<=24;active_diff_1<=16;active_diff_2<=16;active_cfg_id<=INITIAL_CFG_ID;
            request_ignored<=0;select_ignored<=0;ignored_requests<=0;
            calibration_done<=0;calibration_ok<=0;calibration_reason<=0;calibration_frame_id<=0;cfg_applied<=0;
        end else begin
            request_ignored<=0;select_ignored<=0;calibration_done<=0;cfg_applied<=0;
            if(pixel_valid && sof) begin seen_sof<=1;last_sof_id<=source_frame_id;end
            if(calibrate_req) begin
                if(busy) begin
                    request_ignored<=1;
                    if(ignored_requests!=16'hffff) ignored_requests<=ignored_requests+16'd1;
                end else waiting_sample<=1;
            end
            // RED 24/16/16, GREEN 32/12/12, BLUE 64/16/16 plus the
            // classifier's relative floor. K2 explicitly restores presets.
            // Calibration wins simultaneous requests; no hidden request queue.
            if(color_select_req) begin
                if(busy || calibrate_req || color_select==3) select_ignored<=1;
                else begin
                    pending_valid<=1;pending_color<=color_select;pending_calibrated<=0;
                    pending_main<=color_select==0?24:color_select==1?32:64;
                    pending_diff_1<=color_select==1?12:16;pending_diff_2<=color_select==1?12:16;
                end
            end
            if(waiting_sample && sample_done) begin
                waiting_sample<=0;calibration_done<=1;calibration_ok<=params_valid;
                calibration_reason<=params_reason;calibration_frame_id<=sample_frame_id;
                if(params_valid) begin
                    pending_valid<=1;pending_color<=params_color;pending_calibrated<=1;
                    pending_main<=params_main;pending_diff_1<=params_diff_1;pending_diff_2<=params_diff_2;
                end
            end
            if(apply_now) begin
                pending_valid<=0;cfg_applied<=1;active_cfg_id<=active_cfg_id+16'd1;
                active_calibrated<=pending_calibrated;active_color<=pending_color;active_main<=pending_main;
                active_diff_1<=pending_diff_1;active_diff_2<=pending_diff_2;
            end
        end
    end
endmodule
