// C3: raw geometry of all 1 pixels, not a trusted single-target decision.
module mask_frame_stats #(
    parameter X_WIDTH=11, Y_WIDTH=11, FRAME_WIDTH=32, COUNT_WIDTH=20
)(
    input wire clk, rst_n,
    input wire mask_valid, mask,
    input wire [X_WIDTH-1:0] x,
    input wire [Y_WIDTH-1:0] y,
    input wire sof, eof,
    input wire [FRAME_WIDTH-1:0] source_frame_id,
    output reg raw_strobe,
    output reg [FRAME_WIDTH-1:0] raw_frame_id,
    output reg [COUNT_WIDTH-1:0] raw_count,
    output reg [X_WIDTH-1:0] raw_xmin, raw_xmax,
    output reg [Y_WIDTH-1:0] raw_ymin, raw_ymax
);
    reg in_frame;
    reg [FRAME_WIDTH-1:0] frame_id;
    reg [COUNT_WIDTH-1:0] count, next_count;
    reg [X_WIDTH-1:0] xmin, xmax, next_xmin, next_xmax;
    reg [Y_WIDTH-1:0] ymin, ymax, next_ymin, next_ymax;
    wire accept_pixel = mask_valid && (in_frame || sof);

    // Include the current pixel BEFORE publishing the EOF result.
    always @* begin
        next_count = sof ? {COUNT_WIDTH{1'b0}} : count;
        next_xmin = sof ? {X_WIDTH{1'b0}} : xmin;
        next_xmax = sof ? {X_WIDTH{1'b0}} : xmax;
        next_ymin = sof ? {Y_WIDTH{1'b0}} : ymin;
        next_ymax = sof ? {Y_WIDTH{1'b0}} : ymax;
        if (accept_pixel && mask) begin
            if (next_count == 0) begin
                next_xmin=x; next_xmax=x;
                next_ymin=y; next_ymax=y;
            end else begin
                if (x < next_xmin) next_xmin=x;
                if (x > next_xmax) next_xmax=x;
                if (y < next_ymin) next_ymin=y;
                if (y > next_ymax) next_ymax=y;
            end
            next_count=next_count+1'b1;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_frame<=0; frame_id<=0;
            count<=0; xmin<=0; xmax<=0; ymin<=0; ymax<=0;
            raw_strobe<=0; raw_frame_id<=0; raw_count<=0;
            raw_xmin<=0; raw_xmax<=0; raw_ymin<=0; raw_ymax<=0;
        end else begin
            raw_strobe<=0;
            if (accept_pixel) begin
                if (sof) frame_id<=source_frame_id;
                in_frame<=!eof;
                if (eof) begin
                    raw_strobe<=1;
                    raw_frame_id<=sof ? source_frame_id : frame_id;
                    raw_count<=next_count;
                    raw_xmin<=next_xmin; raw_xmax<=next_xmax;
                    raw_ymin<=next_ymin; raw_ymax<=next_ymax;
                    count<=0; xmin<=0; xmax<=0; ymin<=0; ymax<=0;
                end else begin
                    count<=next_count;
                    xmin<=next_xmin; xmax<=next_xmax;
                    ymin<=next_ymin; ymax<=next_ymax;
                end
            end
        end
    end
endmodule
