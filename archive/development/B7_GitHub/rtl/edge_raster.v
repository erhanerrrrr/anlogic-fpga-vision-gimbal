`timescale 1ns/1ps

// Rebuild a complete raster from ordered interior Sobel rows.
// Four rotating 1-bit line slots; no frame buffer, no input backpressure.
// Input rows contain centers x=1..WIDTH-2, y=1..HEIGHT-2 in raster order.
module edge_raster #(
    parameter integer WIDTH=16,
    parameter integer HEIGHT=12
) (
    input wire clk, rst_n,
    input wire in_valid,
    input wire [7:0] in_edge,
    input wire in_eol,
    input wire [10:0] in_x, in_y,
    input wire [31:0] in_source_frame_id,
    output reg out_valid,
    output reg [23:0] out_rgb,
    output reg out_sof, out_eol, out_eof,
    output reg [10:0] out_x, out_y,
    output reg [31:0] out_source_frame_id,
    output reg out_error
);
    localparam integer ADDR_BITS=$clog2(4*WIDTH);
    reg pixels[0:4*WIDTH-1];
    reg read_pixel;
    reg [10:0] row_y[0:3];
    reg [31:0] row_id[0:3];
    reg [1:0] write_bank, read_bank;
    reg [2:0] available_rows;
    reg frame_active;
    reg [10:0] cursor_x, cursor_y;
    reg [31:0] frame_id;

    wire interior=(cursor_y != 0 && cursor_y != HEIGHT-1);
    wire emit_pixel=frame_active ? (!interior || available_rows != 0) : (available_rows != 0);
    wire pop_row=emit_pixel && frame_active && interior && cursor_x == WIDTH-1;
    wire input_coordinates_ok=(in_x >= 1 && in_x < WIDTH-1 && in_y >= 1 && in_y < HEIGHT-1);
    wire accept_edge=in_valid && input_coordinates_ok && (available_rows != 4 || pop_row);
    wire push_row=accept_edge && in_eol;
    wire [ADDR_BITS-1:0] write_address=write_bank*WIDTH+in_x;
    wire [ADDR_BITS-1:0] read_address=read_bank*WIDTH+cursor_x+1;
    wire border=(cursor_x == 0 || cursor_x == WIDTH-1 || !interior);

    // Synchronous read: while outputting column x, prefetch column x+1.
    // At x=0 the border is black, leaving one clock to fetch center x=1.
    // RAM and descriptors are never reset; available_rows controls validity.
    always @(posedge clk) begin
        if (rst_n && accept_edge)
            pixels[write_address] <= in_edge[7];
        if (rst_n && emit_pixel && frame_active && interior && cursor_x < WIDTH-2)
            read_pixel <= pixels[read_address];
        if (rst_n && push_row) begin
            row_y[write_bank] <= in_y;
            row_id[write_bank] <= in_source_frame_id;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_bank <= 2'd0;
            read_bank <= 2'd0;
            available_rows <= 3'd0;
            out_error <= 1'b0;
        end else begin
            if (push_row) write_bank <= write_bank+2'd1;
            if (pop_row) read_bank <= read_bank+2'd1;
            case ({push_row,pop_row})
                2'b10: available_rows <= available_rows+3'd1;
                2'b01: available_rows <= available_rows-3'd1;
                default: available_rows <= available_rows;
            endcase
            // Sticky diagnostic: a malformed stream must not silently pass.
            if (in_valid && (!input_coordinates_ok ||
                (available_rows == 4 && !pop_row) ||
                (in_eol != (in_x == WIDTH-2)) ||
                (in_edge != 8'd0 && in_edge != 8'd255)))
                out_error <= 1'b1;
            if (emit_pixel && !frame_active && row_y[read_bank] != 1)
                out_error <= 1'b1;
            if (emit_pixel && frame_active && interior && cursor_x == 0 &&
                (row_y[read_bank] != cursor_y || row_id[read_bank] != frame_id))
                out_error <= 1'b1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_active <= 1'b0;
            cursor_x <= 11'd0; cursor_y <= 11'd0; frame_id <= 32'd0;
            out_valid <= 1'b0; out_rgb <= 24'd0;
            out_sof <= 1'b0; out_eol <= 1'b0; out_eof <= 1'b0;
            out_x <= 11'd0; out_y <= 11'd0; out_source_frame_id <= 32'd0;
        end else begin
            out_valid <= emit_pixel;
            out_rgb <= (emit_pixel && !border && read_pixel) ? 24'hffffff : 24'd0;
            out_sof <= emit_pixel && cursor_x == 0 && cursor_y == 0;
            out_eol <= emit_pixel && cursor_x == WIDTH-1;
            out_eof <= emit_pixel && cursor_x == WIDTH-1 && cursor_y == HEIGHT-1;
            out_x <= emit_pixel ? cursor_x : 11'd0;
            out_y <= emit_pixel ? cursor_y : 11'd0;
            out_source_frame_id <= emit_pixel ? (frame_active ? frame_id : row_id[read_bank]) : 32'd0;
            if (emit_pixel) begin
                frame_active <= 1'b1;
                if (!frame_active) frame_id <= row_id[read_bank];
                if (cursor_x == WIDTH-1) begin
                    cursor_x <= 11'd0;
                    if (cursor_y == HEIGHT-1) begin
                        cursor_y <= 11'd0;
                        frame_active <= 1'b0;
                    end else cursor_y <= cursor_y+11'd1;
                end else cursor_x <= cursor_x+11'd1;
            end
        end
    end
endmodule
