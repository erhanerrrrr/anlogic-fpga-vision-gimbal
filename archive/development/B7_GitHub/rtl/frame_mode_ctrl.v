`timescale 1ns/1ps

// Display mode requests are synchronous to clk, with a one-cycle valid strobe.
// 0=base RGB, 1=gray, 2=edge, 3=mask. Values 4..7 are rejected.
// A request sampled ON a valid SOF applies to the FOLLOWING valid SOF.
module frame_mode_ctrl (
    input wire clk, rst_n,
    input wire in_valid, in_sof,
    input wire mode_req_valid,
    input wire [2:0] mode_req,
    output reg [1:0] active_mode,
    // Sample this at an admitted SOF to tag that frame in a downstream register.
    // Outside SOF it is only a preview, not the mode of the current pixel.
    output wire [1:0] mode_for_sof,
    output reg invalid_request
);
    reg pending_valid;
    reg [1:0] pending_mode;
    assign mode_for_sof = pending_valid ? pending_mode : active_mode;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_mode <= 2'd0;
            pending_mode <= 2'd0;
            pending_valid <= 1'b0;
            invalid_request <= 1'b0;
        end else begin
            invalid_request <= mode_req_valid && mode_req[2];
            if (in_valid && in_sof) begin
                active_mode <= mode_for_sof;
                pending_valid <= 1'b0;
            end
            // Last legal request wins. This assignment has priority over the
            // SOF clear so a same-edge request is kept for the next frame.
            if (mode_req_valid && !mode_req[2]) begin
                pending_mode <= mode_req[1:0];
                pending_valid <= 1'b1;
            end
        end
    end
endmodule
