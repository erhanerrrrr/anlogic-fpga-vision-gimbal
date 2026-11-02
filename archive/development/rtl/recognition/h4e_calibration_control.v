// C3c: one operation, one pending configuration. Guard owns active registers.
module h4e_calibration_control #(
    parameter [7:0] PRESET_MAIN=8'd24,PRESET_DIFF_1=8'd16,PRESET_DIFF_2=8'd16
)(
    input wire clk,rst_n,source_flush,
    input wire [31:0] active_epoch,
    input wire new_source_sof,calibrate_req,color_select_req,
    input wire [1:0] color_select,
    input wire sampler_busy,calibration_done,calibration_ok,
    input wire [31:0] calibration_epoch,
    input wire [1:0] candidate_color,
    input wire [7:0] candidate_min_main,candidate_diff_1,candidate_diff_2,
    input wire [15:0] active_cfg_id,
    input wire [1:0] active_color,
    input wire [7:0] active_min_main,active_min_diff_1,active_min_diff_2,
    output wire sample_req,busy,operation_flush,
    output reg request_ignored,select_ignored,cfg_applied,operation_cancelled,
    output reg pending_valid,
    output reg [1:0] pending_color,
    output reg [7:0] pending_main,pending_diff_1,pending_diff_2,
    output wire [15:0] requested_cfg_id,
    output wire [1:0] requested_color,
    output wire [7:0] requested_min_main,requested_min_diff_1,requested_min_diff_2
);
    reg waiting;
    reg [1:0] cancel_drain; // drain sampler -> candidate registered completion after cancellation
    reg [31:0] operation_epoch;
    wire revoked=(waiting || pending_valid) && operation_epoch!=active_epoch;
    wire cancel=source_flush || revoked;
    wire apply_now=rst_n && pending_valid && new_source_sof && !cancel;
    assign busy=waiting || pending_valid || sampler_busy || cancel_drain!=0;
    assign operation_flush=cancel;
    assign sample_req=rst_n && calibrate_req && !busy && !cancel;
    // Combinational bypass delivers all pending fields on the SAME SOF edge
    // where the existing guard latches its active configuration.
    assign requested_cfg_id=apply_now ? active_cfg_id+16'd1 : active_cfg_id;
    assign requested_color=apply_now ? pending_color : active_color;
    assign requested_min_main=apply_now ? pending_main : active_min_main;
    assign requested_min_diff_1=apply_now ? pending_diff_1 : active_min_diff_1;
    assign requested_min_diff_2=apply_now ? pending_diff_2 : active_min_diff_2;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            waiting<=0;cancel_drain<=0;operation_epoch<=0;pending_valid<=0;
            pending_color<=0;pending_main<=0;pending_diff_1<=0;pending_diff_2<=0;
            request_ignored<=0;select_ignored<=0;cfg_applied<=0;operation_cancelled<=0;
        end else begin
            if(cancel_drain!=0) cancel_drain<=cancel_drain-1'b1;
            request_ignored<=calibrate_req && (busy || cancel);
            select_ignored<=color_select_req && (busy || cancel || calibrate_req || color_select==3);
            cfg_applied<=0;operation_cancelled<=0;
            if(sample_req) begin waiting<=1;operation_epoch<=active_epoch;end
            if(color_select_req && !busy && !cancel && !calibrate_req && color_select!=3) begin
                pending_valid<=1;operation_epoch<=active_epoch;pending_color<=color_select;
                pending_main<=PRESET_MAIN;pending_diff_1<=PRESET_DIFF_1;pending_diff_2<=PRESET_DIFF_2;
            end
            if(waiting && calibration_done) begin
                waiting<=0;
                if(calibration_ok && calibration_epoch==active_epoch && candidate_color!=3) begin
                    pending_valid<=1;pending_color<=candidate_color;
                    pending_main<=candidate_min_main;pending_diff_1<=candidate_diff_1;pending_diff_2<=candidate_diff_2;
                end
            end
            if(apply_now) begin pending_valid<=0;cfg_applied<=1;end
            // Cancellation wins even against completion or a new source SOF.
            if(cancel) begin
                operation_cancelled<=waiting || pending_valid || sampler_busy;
                if(waiting || pending_valid || sampler_busy) cancel_drain<=2;
                waiting<=0;pending_valid<=0;
            end
        end
    end
endmodule
