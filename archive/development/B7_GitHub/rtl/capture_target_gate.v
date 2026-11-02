`timescale 1ns/1ps
// Development adapter for the strict capture-source display policy.
// Both the result packet and its epoch must arrive atomically in this clock
// domain. A owns the real CDC and source-frame binding.
module capture_target_gate(
    input wire clk,rst_n,stream_abort,
    input wire pixel_valid,pixel_sof,
    input wire [31:0] pixel_epoch,pixel_frame_id,
    input wire [15:0] pixel_cfg_id,
    input wire [1:0] pixel_target_id,
    input wire result_strobe,
    input wire [31:0] result_epoch,result_frame_id,
    input wire [15:0] result_cfg_id,
    input wire [1:0] result_target_id,
    input wire source_timeout,result_timeout,
    output wire completed_ready,
    output wire [31:0] completed_refresh_id,
    output wire [15:0] expected_cfg_id,
    output wire [1:0] expected_target_id
);
    reg have_result;
    reg [31:0] latest_epoch,latest_frame_id;
    reg [15:0] latest_cfg_id;
    reg [1:0] latest_target_id;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            have_result<=0;latest_epoch<=0;latest_frame_id<=0;
            latest_cfg_id<=0;latest_target_id<=0;
        end else if(stream_abort) begin
            have_result<=0;latest_epoch<=0;latest_frame_id<=0;
            latest_cfg_id<=0;latest_target_id<=0;
        end else if(result_strobe) begin
            have_result<=1;latest_epoch<=result_epoch;
            latest_frame_id<=result_frame_id;latest_cfg_id<=result_cfg_id;
            latest_target_id<=result_target_id;
        end
    end
    // B1a samples this only on a valid display SOF. A result arriving on
    // that same edge becomes eligible on a later SOF, never halfway through.
    assign completed_ready=have_result && pixel_valid && pixel_sof &&
        !stream_abort && !source_timeout && !result_timeout &&
        latest_epoch==pixel_epoch && latest_frame_id==pixel_frame_id &&
        latest_cfg_id==pixel_cfg_id && latest_target_id==pixel_target_id;
    assign completed_refresh_id=latest_frame_id;
    assign expected_cfg_id=pixel_cfg_id;
    assign expected_target_id=pixel_target_id;
endmodule
