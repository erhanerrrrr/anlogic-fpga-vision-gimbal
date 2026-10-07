`timescale 1ns/1ps

// Pair the original RGB stream with its complete Sobel raster.
// The edge stream schedules FIFO reads; this is NOT a fixed-cycle delay.
// Legal raster input: WIDTH/HEIGHT=3..2048, continuous pixels within a row,
// arbitrary nonnegative inter-row/frame blanking, no backpressure.
module video_rgb_edge_align #(
    parameter integer WIDTH=16,
    parameter integer HEIGHT=12,
    parameter [10:0] THRESHOLD=11'd128
) (
    input wire clk, rst_n,
    input wire in_valid,
    input wire [23:0] in_rgb,
    input wire in_sof, in_eol, in_eof,
    input wire [10:0] in_x, in_y,
    input wire [31:0] in_source_frame_id,
    output wire out_valid,
    output wire [23:0] out_original_rgb, out_edge_rgb,
    output wire out_sof, out_eol, out_eof,
    output wire [10:0] out_x, out_y,
    output wire [31:0] out_source_frame_id,
    output reg out_error
);
    // Store complete metadata as well as RGB to check pairing independently.
    // Four rows plus pipeline margin; storage scales with WIDTH, not HEIGHT.
    localparam integer FIFO_DEPTH=4*WIDTH+16;
    localparam integer PTR_BITS=$clog2(FIFO_DEPTH);
    localparam integer COUNT_BITS=$clog2(FIFO_DEPTH+1);
    reg [80:0] original_fifo[0:FIFO_DEPTH-1];
    reg [80:0] read_packet;
    reg [PTR_BITS-1:0] write_ptr, read_ptr;
    reg [COUNT_BITS-1:0] queued_pixels;
    reg in_frame;
    wire accept_pixel=in_valid && (in_frame || in_sof);

    wire edge_valid, edge_sof, edge_eol, edge_eof, edge_error;
    wire [23:0] edge_rgb;
    wire [10:0] edge_x, edge_y;
    wire [31:0] edge_id;
    video_edge #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.THRESHOLD(THRESHOLD)) edges (
        .clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_rgb(in_rgb),
        .in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),
        .in_x(in_x),.in_y(in_y),.in_source_frame_id(in_source_frame_id),
        .out_valid(edge_valid),.out_rgb(edge_rgb),
        .out_sof(edge_sof),.out_eol(edge_eol),.out_eof(edge_eof),
        .out_x(edge_x),.out_y(edge_y),.out_source_frame_id(edge_id),.out_error(edge_error)
    );

    wire pop=edge_valid && queued_pixels != 0;
    // Do not permit same-address read/write at full occupancy: a full FIFO
    // is a fatal protocol/capacity error even when a read also occurs.
    wire push=accept_pixel && queued_pixels < FIFO_DEPTH;
    reg pair_valid;
    reg [80:0] paired_edge;
    wire metadata_mismatch=pair_valid && read_packet[80:24] != paired_edge[80:24];

    // Synchronous RAM read; no array reset. Invalid output gates stale data.
    always @(posedge clk) begin
        if (rst_n && push)
            original_fifo[write_ptr] <= {in_sof,in_eol,in_eof,in_x,in_y,in_source_frame_id,in_rgb};
        if (rst_n && pop)
            read_packet <= original_fifo[read_ptr];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 0; read_ptr <= 0; queued_pixels <= 0;
            in_frame <= 1'b0; pair_valid <= 1'b0; paired_edge <= 81'd0;
            out_error <= 1'b0;
        end else begin
            if (accept_pixel) in_frame <= !in_eof;
            if (push) write_ptr <= (write_ptr == FIFO_DEPTH-1) ? 0 : write_ptr+1'b1;
            if (pop) read_ptr <= (read_ptr == FIFO_DEPTH-1) ? 0 : read_ptr+1'b1;
            case ({push,pop})
                2'b10: queued_pixels <= queued_pixels+1'b1;
                2'b01: queued_pixels <= queued_pixels-1'b1;
                default: queued_pixels <= queued_pixels;
            endcase
            pair_valid <= pop;
            paired_edge <= pop ? {edge_sof,edge_eol,edge_eof,edge_x,edge_y,edge_id,edge_rgb} : 81'd0;
            if (edge_error || (accept_pixel && !push) || (edge_valid && !pop) || metadata_mismatch)
                out_error <= 1'b1;
        end
    end

    assign out_valid=pair_valid;
    assign out_original_rgb=pair_valid ? read_packet[23:0] : 24'd0;
    assign out_edge_rgb=pair_valid ? paired_edge[23:0] : 24'd0;
    assign {out_sof,out_eol,out_eof,out_x,out_y,out_source_frame_id}=
        pair_valid ? paired_edge[80:24] : 57'd0;
endmodule
