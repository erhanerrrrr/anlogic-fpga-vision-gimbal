// A integration step: only minimum-area screening; retain C's result packer.
// Each notification represents a completed HDMI refresh, NOT capture freshness.
module h4b_min_area_gate #(
    parameter [19:0] MIN_AREA=20'd256
)(
    input wire clk,rst_n,input_strobe,
    input wire [31:0] input_frame_id,
    input wire [15:0] input_cfg_id,
    input wire [1:0] input_target_id,
    input wire [19:0] input_count,
    input wire [10:0] input_xmin,input_xmax,input_ymin,input_ymax,
    output wire result_strobe,target_valid,
    output wire [31:0] result_frame_id,
    output wire [15:0] result_cfg_id,
    output wire [1:0] target_id,
    output wire [19:0] area,
    output wire [10:0] cx,xmin,xmax,cy,ymin,ymax,
    output reg [1:0] reject_reason
);
    wire accepted=(input_count!=0) && (input_count>=MIN_AREA);
    wire [19:0] public_count=accepted ? input_count : 20'd0;
    target_result_pack packet(
        .clk(clk),.rst_n(rst_n),.raw_strobe(input_strobe),
        .raw_frame_id(input_frame_id),.raw_cfg_id(input_cfg_id),.raw_target_id(input_target_id),
        .raw_count(public_count),.raw_xmin(input_xmin),.raw_xmax(input_xmax),
        .raw_ymin(input_ymin),.raw_ymax(input_ymax),
        .result_strobe(result_strobe),.target_valid(target_valid),
        .result_frame_id(result_frame_id),.result_cfg_id(result_cfg_id),.target_id(target_id),
        .area(area),.cx(cx),.xmin(xmin),.xmax(xmax),.cy(cy),.ymin(ymin),.ymax(ymax)
    );
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) reject_reason<=0;
        else if(input_strobe) reject_reason<=input_count==0 ? 2'd1 : (accepted ? 2'd0 : 2'd2);
    end
endmodule
