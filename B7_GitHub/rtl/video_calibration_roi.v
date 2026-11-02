`timescale 1ns/1ps
// Display-only overlay. Place BEFORE video_target_osd so official Logo wins.
// No pixel register: valid/coordinates/identity/mode stay on the same wires.
// Synchronous request mailbox; a request ON SOF applies at the FOLLOWING SOF.
module video_calibration_roi #(
    parameter integer WIDTH=1280, HEIGHT=720,
    parameter [23:0] ROI_COLOR=24'hffff00
)(
    input wire clk,rst_n,stream_abort,
    input wire roi_req_valid,roi_req_enable,
    input wire in_valid,in_sof,
    input wire [10:0] in_x,in_y,
    input wire [23:0] in_rgb,
    output wire [23:0] out_rgb,
    output wire roi_hit
);
    localparam integer LEFT=(WIDTH-16)/2, TOP=(HEIGHT-16)/2;
    localparam integer RIGHT=LEFT+15, BOTTOM=TOP+15;
    reg pending_enable,active_enable,frame_open;
    wire start=in_valid && in_sof;
    wire enabled=start ? pending_enable : active_enable;
    // Reject unsupported geometry; avoid unsigned subtraction at the edges.
    assign roi_hit=rst_n && !stream_abort && in_valid && (frame_open || start) &&
        enabled && WIDTH>=16 && HEIGHT>=16 && WIDTH<=2048 && HEIGHT<=2048 &&
        in_x<WIDTH && in_y<HEIGHT &&
        in_x>=LEFT && in_x<=RIGHT && in_y>=TOP && in_y<=BOTTOM &&
        (in_x==LEFT || in_x==RIGHT || in_y==TOP || in_y==BOTTOM);
    assign out_rgb=roi_hit ? ROI_COLOR : in_rgb;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin pending_enable<=0;active_enable<=0;frame_open<=0;end
        else begin
            // Abort invalidates display frame, not the requested visibility.
            if(roi_req_valid) pending_enable<=roi_req_enable;
            if(stream_abort) begin active_enable<=0;frame_open<=0;end
            else if(start) begin active_enable<=pending_enable;frame_open<=1;end
        end
    end
endmodule
