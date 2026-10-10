// Associate frame configuration with C3 statistics before packing C4 results.
module mask_target_result #(
    parameter X_WIDTH=11,Y_WIDTH=11,FRAME_WIDTH=32,COUNT_WIDTH=20,CFG_WIDTH=16
)(
    input wire clk,rst_n,mask_valid,mask,
    input wire [X_WIDTH-1:0] x,
    input wire [Y_WIDTH-1:0] y,
    input wire sof,eof,
    input wire [FRAME_WIDTH-1:0] source_frame_id,
    input wire [CFG_WIDTH-1:0] cfg_id,
    input wire [1:0] active_color,
    output wire result_strobe,target_valid,
    output wire [FRAME_WIDTH-1:0] result_frame_id,
    output wire [CFG_WIDTH-1:0] result_cfg_id,
    output wire [1:0] target_id,
    output wire [COUNT_WIDTH-1:0] area,
    output wire [X_WIDTH-1:0] cx,xmin,xmax,
    output wire [Y_WIDTH-1:0] cy,ymin,ymax
);
    wire raw_strobe;
    wire [FRAME_WIDTH-1:0] raw_frame_id;
    wire [COUNT_WIDTH-1:0] raw_count;
    wire [X_WIDTH-1:0] raw_xmin,raw_xmax;
    wire [Y_WIDTH-1:0] raw_ymin,raw_ymax;
    reg in_frame;
    reg [CFG_WIDTH-1:0] frame_cfg,raw_cfg;
    reg [1:0] frame_color,raw_color;
    wire accept_pixel=mask_valid && (in_frame || sof);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_frame<=0;frame_cfg<=0;raw_cfg<=0;frame_color<=0;raw_color<=0;
        end else if (accept_pixel) begin
            in_frame<=!eof;
            if (sof) begin frame_cfg<=cfg_id;frame_color<=active_color;end
            if (eof) begin
                raw_cfg<=sof ? cfg_id : frame_cfg;
                raw_color<=sof ? active_color : frame_color;
            end
        end
    end
    mask_frame_stats #(.X_WIDTH(X_WIDTH),.Y_WIDTH(Y_WIDTH),.FRAME_WIDTH(FRAME_WIDTH),.COUNT_WIDTH(COUNT_WIDTH))
        stats(clk,rst_n,mask_valid,mask,x,y,sof,eof,source_frame_id,
              raw_strobe,raw_frame_id,raw_count,raw_xmin,raw_xmax,raw_ymin,raw_ymax);
    target_result_pack #(.X_WIDTH(X_WIDTH),.Y_WIDTH(Y_WIDTH),.FRAME_WIDTH(FRAME_WIDTH),
        .COUNT_WIDTH(COUNT_WIDTH),.CFG_WIDTH(CFG_WIDTH))
        packer(clk,rst_n,raw_strobe,raw_frame_id,raw_cfg,raw_color,raw_count,
               raw_xmin,raw_xmax,raw_ymin,raw_ymax,result_strobe,target_valid,
               result_frame_id,result_cfg_id,target_id,area,cx,xmin,xmax,cy,ymin,ymax);
endmodule
