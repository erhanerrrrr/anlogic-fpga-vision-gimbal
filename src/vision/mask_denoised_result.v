module mask_denoised_result #(
    parameter WIDTH=1280,HEIGHT=720
)(
    input wire clk,rst_n,mask_valid,mask,
    input wire [10:0] x,y,
    input wire sof,eof,
    input wire [31:0] source_frame_id,
    input wire [15:0] cfg_id,
    input wire [1:0] active_color,
    output wire filtered_valid,filtered_mask,
    output wire [10:0] filtered_x,filtered_y,
    output wire filtered_sof,filtered_eol,filtered_eof,
    output wire [31:0] filtered_frame_id,
    output wire [15:0] filtered_cfg_id,
    output wire [1:0] filtered_target_id,
    output wire result_strobe,target_valid,
    output wire [31:0] result_frame_id,
    output wire [15:0] result_cfg_id,
    output wire [1:0] target_id,
    output wire [19:0] area,
    output wire [10:0] cx,xmin,xmax,cy,ymin,ymax
);
    mask_majority_3x3 #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) filter(
        clk,rst_n,mask_valid,mask,x,y,sof,eof,source_frame_id,cfg_id,active_color,
        filtered_valid,filtered_mask,filtered_x,filtered_y,filtered_sof,filtered_eol,filtered_eof,
        filtered_frame_id,filtered_cfg_id,filtered_target_id);
    mask_target_result detector(clk,rst_n,filtered_valid,filtered_mask,filtered_x,filtered_y,
        filtered_sof,filtered_eof,filtered_frame_id,filtered_cfg_id,filtered_target_id,
        result_strobe,target_valid,result_frame_id,result_cfg_id,target_id,area,cx,xmin,xmax,cy,ymin,ymax);
endmodule
