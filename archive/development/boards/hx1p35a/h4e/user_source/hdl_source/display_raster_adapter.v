// Display-domain raster coordinates. IDs count HDMI refreshes, NOT camera frames.
// Accept a native USER either before DE or on the first DE pixel. Ignore the
// startup partial frame until USER has been seen. Geometry uses configured size.
module display_raster_adapter #(
    parameter WIDTH=1280, HEIGHT=720
)(
    input wire clk, rst_n, de, user,
    output wire valid, sof, eof,
    output wire [10:0] x, y,
    output wire [31:0] refresh_id
);
    reg active, pending_sof;
    reg [10:0] next_x, next_y;
    reg [31:0] frame_number;
    wire restart = user || pending_sof;
    assign valid = de && (active || restart);
    assign x = restart ? 11'd0 : next_x;
    assign y = restart ? 11'd0 : next_y;
    assign sof = valid && restart;
    assign eof = valid && x==WIDTH-1 && y==HEIGHT-1;
    assign refresh_id = restart ? frame_number+32'd1 : frame_number;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            active<=0; pending_sof<=0; next_x<=0; next_y<=0; frame_number<=0;
        end else begin
            if(user) begin
                active<=1; pending_sof<=1; next_x<=0; next_y<=0;
            end
            if(valid) begin
                pending_sof<=0;
                active<=!eof;
                if(sof) frame_number<=frame_number+32'd1;
                if(x==WIDTH-1) begin
                    next_x<=0;
                    next_y<=eof ? 11'd0 : y+11'd1;
                end else begin
                    next_x<=x+11'd1; next_y<=y;
                end
            end
        end
    end
endmodule
