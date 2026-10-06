// C1-C4 integration. active_color/cfg_id are externally frozen for each frame.
module rgb_target_result #(
    parameter X_WIDTH=11,Y_WIDTH=11,FRAME_WIDTH=32,COUNT_WIDTH=20,CFG_WIDTH=16,
    parameter [7:0] MIN_MAIN=80,MIN_DIFF_1=40,MIN_DIFF_2=40
)(
    input wire clk,rst_n,pixel_valid,
    input wire [23:0] rgb,
    input wire [X_WIDTH-1:0] x,
    input wire [Y_WIDTH-1:0] y,
    input wire sof,eol,eof,
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
    wire mv,m,ms,ml,me;
    wire [X_WIDTH-1:0] mx;
    wire [Y_WIDTH-1:0] my;
    wire [FRAME_WIDTH-1:0] mf;
    reg [CFG_WIDTH-1:0] mask_cfg;
    reg [1:0] mask_color;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin mask_cfg<=0;mask_color<=0;end
        else begin mask_cfg<=cfg_id;mask_color<=active_color;end
    end
    color_mask_stream #(.X_WIDTH(X_WIDTH),.Y_WIDTH(Y_WIDTH),.FRAME_WIDTH(FRAME_WIDTH),
        .MIN_MAIN(MIN_MAIN),.MIN_DIFF_1(MIN_DIFF_1),.MIN_DIFF_2(MIN_DIFF_2))
        segmenter(clk,rst_n,pixel_valid,rgb,active_color,x,y,sof,eol,eof,source_frame_id,
                  mv,m,mx,my,ms,ml,me,mf);
    mask_target_result #(.X_WIDTH(X_WIDTH),.Y_WIDTH(Y_WIDTH),.FRAME_WIDTH(FRAME_WIDTH),
        .COUNT_WIDTH(COUNT_WIDTH),.CFG_WIDTH(CFG_WIDTH))
        detector(clk,rst_n,mv,m,mx,my,ms,me,mf,mask_cfg,mask_color,result_strobe,target_valid,
                 result_frame_id,result_cfg_id,target_id,area,cx,xmin,xmax,cy,ymin,ymax);
endmodule
