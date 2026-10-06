module rgb_denoised_result #(
    parameter WIDTH=1280,HEIGHT=720
)(
    input wire clk,rst_n,pixel_valid,
    input wire [23:0] rgb,
    input wire [10:0] x,y,
    input wire sof,eol,eof,
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
    wire mv,m,ms,ml,me;wire [10:0] mx,my;wire [31:0] mf;
    reg [15:0] mc;reg [1:0] mt;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin mc<=0;mt<=0;end
        else begin mc<=cfg_id;mt<=active_color;end
    end
    color_mask_stream classifier(clk,rst_n,pixel_valid,rgb,active_color,x,y,sof,eol,eof,source_frame_id,
        mv,m,mx,my,ms,ml,me,mf);
    mask_denoised_result #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) detector(
        clk,rst_n,mv,m,mx,my,ms,me,mf,mc,mt,
        filtered_valid,filtered_mask,filtered_x,filtered_y,filtered_sof,filtered_eol,filtered_eof,
        filtered_frame_id,filtered_cfg_id,filtered_target_id,
        result_strobe,target_valid,result_frame_id,result_cfg_id,target_id,area,cx,xmin,xmax,cy,ymin,ymax);
endmodule
