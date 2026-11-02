// C4 temporary validity rule: raw_count > 0. No interference rejection yet.
module target_result_pack #(
    parameter X_WIDTH=11,Y_WIDTH=11,FRAME_WIDTH=32,COUNT_WIDTH=20,CFG_WIDTH=16
)(
    input wire clk,rst_n,raw_strobe,
    input wire [FRAME_WIDTH-1:0] raw_frame_id,
    input wire [CFG_WIDTH-1:0] raw_cfg_id,
    input wire [1:0] raw_target_id,
    input wire [COUNT_WIDTH-1:0] raw_count,
    input wire [X_WIDTH-1:0] raw_xmin,raw_xmax,
    input wire [Y_WIDTH-1:0] raw_ymin,raw_ymax,
    output reg result_strobe,target_valid,
    output reg [FRAME_WIDTH-1:0] result_frame_id,
    output reg [CFG_WIDTH-1:0] result_cfg_id,
    output reg [1:0] target_id,
    output reg [COUNT_WIDTH-1:0] area,
    output reg [X_WIDTH-1:0] cx,xmin,xmax,
    output reg [Y_WIDTH-1:0] cy,ymin,ymax
);
    wire [X_WIDTH:0] sum_x={1'b0,raw_xmin}+{1'b0,raw_xmax};
    wire [Y_WIDTH:0] sum_y={1'b0,raw_ymin}+{1'b0,raw_ymax};
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_strobe<=0;target_valid<=0;result_frame_id<=0;result_cfg_id<=0;target_id<=0;
            area<=0;cx<=0;cy<=0;xmin<=0;xmax<=0;ymin<=0;ymax<=0;
        end else begin
            result_strobe<=raw_strobe;
            if (raw_strobe) begin
                result_frame_id<=raw_frame_id;result_cfg_id<=raw_cfg_id;target_id<=raw_target_id;
                target_valid<=(raw_count!=0);
                if (raw_count!=0) begin
                    area<=raw_count;cx<=sum_x[X_WIDTH:1];cy<=sum_y[Y_WIDTH:1];
                    xmin<=raw_xmin;xmax<=raw_xmax;ymin<=raw_ymin;ymax<=raw_ymax;
                end else begin
                    area<=0;cx<=0;cy<=0;xmin<=0;xmax<=0;ymin<=0;ymax<=0;
                end
            end
        end
    end
endmodule
