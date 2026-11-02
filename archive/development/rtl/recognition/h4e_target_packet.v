// Atomic T-region result register; one clock of latency, no backpressure.
// Input identity/epoch must already belong to this result, not live camera state.
// h4e-refresh-v1: connect t_capture_epoch to 0. Source binding/dedup is C2b.
module h4e_target_packet (
    input wire clk, rst_n,
    input wire t_result_strobe,
    input wire t_target_valid,
    input wire [31:0] t_frame_id,
    input wire [31:0] t_capture_epoch,
    input wire [15:0] t_cfg_id,
    input wire [1:0] t_target_id,
    input wire [19:0] t_area,
    input wire [10:0] t_cx,
    input wire [10:0] t_cy,
    input wire [10:0] t_xmin,
    input wire [10:0] t_xmax,
    input wire [10:0] t_ymin,
    input wire [10:0] t_ymax,
    input wire [2:0] t_reason,
    input wire [7:0] t_peak_slots,
    input wire [11:0] t_component_count,
    output reg result_strobe,
    output reg target_valid,
    output reg [31:0] frame_id,
    output reg [31:0] capture_epoch,
    output reg [15:0] cfg_id,
    output reg [1:0] target_id,
    output reg [19:0] area,
    output reg [10:0] cx,
    output reg [10:0] cy,
    output reg [10:0] xmin,
    output reg [10:0] xmax,
    output reg [10:0] ymin,
    output reg [10:0] ymax,
    output reg [2:0] reject_reason,
    output reg [7:0] peak_slots,
    output reg [11:0] component_count
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_strobe <= 1'b0;
            target_valid <= 1'd0;
            frame_id <= 32'd0;
            capture_epoch <= 32'd0;
            cfg_id <= 16'd0;
            target_id <= 2'd0;
            area <= 20'd0;
            cx <= 11'd0;
            cy <= 11'd0;
            xmin <= 11'd0;
            xmax <= 11'd0;
            ymin <= 11'd0;
            ymax <= 11'd0;
            reject_reason <= 3'd0;
            peak_slots <= 8'd0;
            component_count <= 12'd0;
        end else begin
            // Consecutive asserted cycles are distinct events, not a stretched one.
            result_strobe <= t_result_strobe;
            if (t_result_strobe) begin
                target_valid <= t_target_valid;
                frame_id <= t_frame_id;
                capture_epoch <= t_capture_epoch;
                cfg_id <= t_cfg_id;
                target_id <= t_target_id;
                area <= t_target_valid ? t_area : 20'd0;
                cx <= t_target_valid ? t_cx : 11'd0;
                cy <= t_target_valid ? t_cy : 11'd0;
                xmin <= t_target_valid ? t_xmin : 11'd0;
                xmax <= t_target_valid ? t_xmax : 11'd0;
                ymin <= t_target_valid ? t_ymin : 11'd0;
                ymax <= t_target_valid ? t_ymax : 11'd0;
                reject_reason <= t_reason;
                peak_slots <= t_peak_slots;
                component_count <= t_component_count;
            end
        end
    end
endmodule

