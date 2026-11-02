`timescale 1ns/1ps
// h4e-refresh-v1 only. Packet layout is documented in docs/B1a_interface.md.
// result_packet is captured ONLY on strobe; the previous completed refresh is
// selected at display SOF. A result arriving ON SOF is eligible next SOF.
module b1_target_snapshot #(
    parameter integer WIDTH=1280, HEIGHT=720
)(
    input wire clk, rst_n, stream_abort,
    input wire pixel_valid, pixel_sof,
    input wire result_strobe,
    input wire [159:0] result_packet,
    input wire completed_ready,
    input wire [31:0] completed_refresh_id,
    input wire [15:0] expected_cfg_id,
    input wire [1:0] expected_target_id,
    output wire pixel_frame_open,
    output wire pixel_ready,
    output wire [159:0] pixel_packet
);
    reg seen, frame_open, active_ready;
    reg [159:0] latest, active;
    wire start = pixel_valid && pixel_sof;
    wire [31:0] fid;
    wire [15:0] cfg;
    wire [1:0] tid;
    wire tv;
    wire [19:0] area;
    wire [10:0] xmin,ymin,xmax,ymax,cx,cy;
    wire [2:0] reason;
    wire [7:0] labels;
    wire [11:0] components;
    assign {fid,cfg,tid,tv,area,xmin,ymin,xmax,ymax,cx,cy,reason,labels,components}=latest;
    wire match = seen && completed_ready && fid==completed_refresh_id &&
                 cfg==expected_cfg_id && tid==expected_target_id && tid!=2'd3;
    wire geometry_ok = area!=0 && xmin<=xmax && ymin<=ymax &&
        xmax<WIDTH && ymax<HEIGHT && cx<WIDTH && cy<HEIGHT;
    wire usable = match && tv && reason==0 && geometry_ok;
    wire [2:0] selected_reason = !match || (tv && (!geometry_ok || reason!=0)) ? 3'd4 : reason;
    wire [159:0] selected = {fid,cfg,tid,usable,
        usable ? area : 20'd0, usable ? xmin : 11'd0, usable ? ymin : 11'd0,
        usable ? xmax : 11'd0, usable ? ymax : 11'd0,
        usable ? cx : 11'd0, usable ? cy : 11'd0,selected_reason,
        match ? labels : 8'd0, match ? components : 12'd0};
    assign pixel_frame_open = rst_n && !stream_abort && (frame_open || start);
    assign pixel_ready = pixel_frame_open && (start ? match : active_ready);
    assign pixel_packet = !pixel_frame_open ? 160'd0 : (start ? selected : active);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            seen<=0;frame_open<=0;active_ready<=0;latest<=0;active<=0;
        end else if(stream_abort) begin
            // An upstream malformed/interrupted frame flushes both mailboxes.
            seen<=0;frame_open<=0;active_ready<=0;latest<=0;active<=0;
        end else begin
            if(start) begin frame_open<=1;active_ready<=match;active<=selected;end
            if(result_strobe) begin seen<=1;latest<=result_packet;end
        end
    end
endmodule
