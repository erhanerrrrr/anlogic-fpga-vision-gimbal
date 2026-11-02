// One additional registered gate after C5's temporary count>0 packet.
module target_validated_pack #(
    parameter [19:0] MIN_AREA=20'd9,MAX_AREA=20'd921600,
    parameter [11:0] MIN_WIDTH=12'd3,MIN_HEIGHT=12'd3
)(
    input wire clk,rst_n,input_strobe,
    input wire [31:0] input_frame_id,
    input wire [15:0] input_cfg_id,
    input wire [1:0] input_target_id,
    input wire [19:0] input_count,
    input wire [10:0] input_xmin,input_ymin,input_xmax,input_ymax,
    output wire result_strobe,target_valid,
    output wire [31:0] result_frame_id,
    output wire [15:0] result_cfg_id,
    output wire [1:0] target_id,
    output wire [19:0] area,
    output wire [10:0] cx,xmin,xmax,cy,ymin,ymax,
    output reg [2:0] reject_reason,
    output reg [19:0] debug_count,
    output reg [10:0] debug_xmin,debug_ymin,debug_xmax,debug_ymax
);
    wire accepted;wire [2:0] reason;
    wire [19:0] public_count=accepted?input_count:20'b0;
    target_validity #(.MIN_AREA(MIN_AREA),.MAX_AREA(MAX_AREA),.MIN_WIDTH(MIN_WIDTH),.MIN_HEIGHT(MIN_HEIGHT))
        rule(input_count,input_xmin,input_ymin,input_xmax,input_ymax,accepted,reason);
    target_result_pack packet(clk,rst_n,input_strobe,input_frame_id,input_cfg_id,input_target_id,
        public_count,input_xmin,input_xmax,input_ymin,input_ymax,
        result_strobe,target_valid,result_frame_id,result_cfg_id,target_id,area,cx,xmin,xmax,cy,ymin,ymax);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            reject_reason<=0;debug_count<=0;debug_xmin<=0;debug_ymin<=0;debug_xmax<=0;debug_ymax<=0;
        end else if(input_strobe) begin
            reject_reason<=reason;debug_count<=input_count;
            debug_xmin<=input_xmin;debug_ymin<=input_ymin;debug_xmax<=input_xmax;debug_ymax<=input_ymax;
        end
    end
endmodule
