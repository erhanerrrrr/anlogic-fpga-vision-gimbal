`timescale 1ns/1ps

// Four display modes, selected per INPUT frame. Mode tags and the mask bit
// travel with their pixels; the latest input mode never selects an old frame.
// in_mask accompanies exactly the same pixel as in_rgb (shared metadata).
module video_modes #(
    parameter integer WIDTH=16, HEIGHT=12,
    parameter [10:0] THRESHOLD=11'd128
) (
    input wire clk, rst_n, in_valid,
    input wire [23:0] in_rgb,
    input wire in_mask, in_sof, in_eol, in_eof,
    input wire [10:0] in_x, in_y,
    input wire [31:0] in_source_frame_id,
    input wire mode_req_valid,
    input wire [2:0] mode_req,
    output wire invalid_request,
    output wire out_valid,
    output wire [23:0] out_rgb,
    output wire [1:0] out_mode,
    output wire out_sof, out_eol, out_eof,
    output wire [10:0] out_x, out_y,
    output wire [31:0] out_source_frame_id,
    output reg out_error,
    // Independent, one-register base RGB tap for recognition. Always active.
    output wire detect_valid,
    output wire [23:0] detect_rgb,
    output wire detect_sof, detect_eol, detect_eof,
    output wire [10:0] detect_x, detect_y,
    output wire [31:0] detect_source_frame_id
);
    wire [1:0] active_mode, mode_for_sof;
    reg in_frame;
    wire accept_pixel=in_valid && (in_frame || in_sof);
    frame_mode_ctrl modes (
        .clk(clk),.rst_n(rst_n),.in_valid(accept_pixel),.in_sof(in_sof),
        .mode_req_valid(mode_req_valid),.mode_req(mode_req),
        .active_mode(active_mode),.mode_for_sof(mode_for_sof),.invalid_request(invalid_request)
    );
    video_bypass detection_tap (
        .clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_rgb(in_rgb),
        .in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),
        .in_x(in_x),.in_y(in_y),.in_source_frame_id(in_source_frame_id),
        .out_valid(detect_valid),.out_rgb(detect_rgb),
        .out_sof(detect_sof),.out_eol(detect_eol),.out_eof(detect_eof),
        .out_x(detect_x),.out_y(detect_y),.out_source_frame_id(detect_source_frame_id)
    );

    wire pair_valid, pair_sof, pair_eol, pair_eof, pair_error;
    wire [23:0] original_rgb, edge_rgb;
    wire [10:0] pair_x, pair_y;
    wire [31:0] pair_id;
    video_rgb_edge_align #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.THRESHOLD(THRESHOLD)) align (
        .clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_rgb(in_rgb),
        .in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),
        .in_x(in_x),.in_y(in_y),.in_source_frame_id(in_source_frame_id),
        .out_valid(pair_valid),.out_original_rgb(original_rgb),.out_edge_rgb(edge_rgb),
        .out_sof(pair_sof),.out_eol(pair_eol),.out_eof(pair_eof),
        .out_x(pair_x),.out_y(pair_y),.out_source_frame_id(pair_id),.out_error(pair_error)
    );

    localparam integer DEPTH=4*WIDTH+16;
    localparam integer PTR_BITS=$clog2(DEPTH), COUNT_BITS=$clog2(DEPTH+1);
    reg [2:0] tags[0:DEPTH-1];
    reg [2:0] read_tag;
    reg [PTR_BITS-1:0] write_ptr, read_ptr;
    reg [COUNT_BITS-1:0] tag_count;
    wire push=accept_pixel && tag_count < DEPTH;
    wire pop=pair_valid && tag_count != 0;
    always @(posedge clk) begin
        if (rst_n && push)
            tags[write_ptr] <= {in_sof ? mode_for_sof : active_mode,in_mask};
        if (rst_n && pop) read_tag <= tags[read_ptr];
    end

    // Synchronous tag RAM read, gray calculation, and the other branches all
    // take one register stage. Invalid cycles gate the unreset RAM output.
    wire gray_valid;
    wire [23:0] gray_rgb;
    rgb_to_gray gray_branch (
        .clk(clk),.rst_n(rst_n),.in_valid(pop),.in_rgb(original_rgb),
        .out_valid(gray_valid),.out_rgb(gray_rgb)
    );
    reg [23:0] original_d, edge_d;
    reg [56:0] metadata_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_frame <= 1'b0;
            write_ptr <= 0; read_ptr <= 0; tag_count <= 0;
            original_d <= 0; edge_d <= 0; metadata_d <= 0;
            out_error <= 1'b0;
        end else begin
            if (accept_pixel) in_frame <= !in_eof;
            if (push) write_ptr <= (write_ptr == DEPTH-1) ? 0 : write_ptr+1'b1;
            if (pop) read_ptr <= (read_ptr == DEPTH-1) ? 0 : read_ptr+1'b1;
            case ({push,pop})
                2'b10: tag_count <= tag_count+1'b1;
                2'b01: tag_count <= tag_count-1'b1;
                default: tag_count <= tag_count;
            endcase
            original_d <= pop ? original_rgb : 24'd0;
            edge_d <= pop ? edge_rgb : 24'd0;
            metadata_d <= pop ? {pair_sof,pair_eol,pair_eof,pair_x,pair_y,pair_id} : 57'd0;
            if (pair_error || (accept_pixel && !push) || (pair_valid && !pop)) out_error <= 1'b1;
        end
    end
    reg [23:0] selected_rgb;
    always @* begin
        case (read_tag[2:1])
            2'd0: selected_rgb=original_d;
            2'd1: selected_rgb=gray_rgb;
            2'd2: selected_rgb=edge_d;
            2'd3: selected_rgb={24{read_tag[0]}};
            default: selected_rgb=24'd0;
        endcase
    end
    assign out_valid=gray_valid;
    assign out_rgb=gray_valid ? selected_rgb : 24'd0;
    assign out_mode=gray_valid ? read_tag[2:1] : 2'd0;
    assign {out_sof,out_eol,out_eof,out_x,out_y,out_source_frame_id}=gray_valid ? metadata_d : 57'd0;
endmodule
