// C2: classifier and metadata use the same single output register stage.
module color_mask_stream #(
    parameter X_WIDTH=11, Y_WIDTH=11, FRAME_WIDTH=32,
    parameter [7:0] MIN_MAIN=80, MIN_DIFF_1=40, MIN_DIFF_2=40
)(
    input wire clk, rst_n, pixel_valid,
    input wire [23:0] rgb,
    input wire [1:0] active_color,
    input wire [X_WIDTH-1:0] x,
    input wire [Y_WIDTH-1:0] y,
    input wire sof, eol, eof,
    input wire [FRAME_WIDTH-1:0] source_frame_id,
    output wire mask_valid, mask,
    output reg [X_WIDTH-1:0] mask_x,
    output reg [Y_WIDTH-1:0] mask_y,
    output reg mask_sof, mask_eol, mask_eof,
    output reg [FRAME_WIDTH-1:0] mask_frame_id
);
    reg in_frame;
    wire accept_pixel = pixel_valid && (in_frame || sof);
    color_classifier #(.MIN_MAIN(MIN_MAIN), .MIN_DIFF_1(MIN_DIFF_1),
        .MIN_DIFF_2(MIN_DIFF_2)) classifier (
        .clk(clk), .rst_n(rst_n), .pixel_valid(accept_pixel), .rgb(rgb),
        .active_color(active_color), .mask_valid(mask_valid), .mask(mask));
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_frame <= 0;
            mask_x <= 0; mask_y <= 0; mask_frame_id <= 0;
            mask_sof <= 0; mask_eol <= 0; mask_eof <= 0;
        end else begin
            if (accept_pixel) begin
                in_frame <= !eof;
                mask_x <= x; mask_y <= y; mask_frame_id <= source_frame_id;
                mask_sof <= sof; mask_eol <= eol; mask_eof <= eof;
            end else begin
                mask_x <= 0; mask_y <= 0; mask_frame_id <= 0;
                mask_sof <= 0; mask_eol <= 0; mask_eof <= 0;
            end
        end
    end
endmodule
