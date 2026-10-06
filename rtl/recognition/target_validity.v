// C6 deterministic single-region screening, not connected-component selection.
module target_validity #(
    parameter [19:0] MIN_AREA=20'd9,MAX_AREA=20'd921600,
    parameter [11:0] MIN_WIDTH=12'd3,MIN_HEIGHT=12'd3
)(
    input wire [19:0] raw_count,
    input wire [10:0] xmin,ymin,xmax,ymax,
    output reg accepted,
    output reg [2:0] reason
);
    wire [11:0] width={1'b0,xmax}-{1'b0,xmin}+12'd1;
    wire [11:0] height={1'b0,ymax}-{1'b0,ymin}+12'd1;
    wire [23:0] box_area=width*height;
    wire [25:0] count_times_four={4'b0,raw_count,2'b0};
    wire [25:0] box_times_three={2'b0,box_area}+{1'b0,box_area,1'b0};
    always @* begin
        accepted=0;reason=0;
        if(raw_count==0) reason=3'd1; // EMPTY
        else if(xmax<xmin || ymax<ymin || {4'b0,raw_count}>box_area) reason=3'd6; // BAD_GEOMETRY
        else if(raw_count<MIN_AREA) reason=3'd2; // TOO_SMALL
        else if(width<MIN_WIDTH || height<MIN_HEIGHT) reason=3'd3; // TOO_NARROW
        else if(raw_count>MAX_AREA) reason=3'd4; // TOO_LARGE
        else if(count_times_four<box_times_three) reason=3'd5; // SPARSE
        else accepted=1;
    end
endmodule
