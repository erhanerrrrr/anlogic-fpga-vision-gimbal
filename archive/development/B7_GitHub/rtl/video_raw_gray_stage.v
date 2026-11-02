// One shared metadata stage for parallel RAW and GRAY display candidates.
// No frame admission or mode control here: input is the checked B2a stream.
module video_raw_gray_stage(
    input wire clk,rst_n,stream_abort,
    input wire in_valid,in_mask,in_sof,in_eol,in_eof,
    input wire [23:0] in_rgb,
    input wire [10:0] in_x,in_y,
    input wire [31:0] in_epoch,in_frame_id,
    input wire [15:0] in_cfg_id,
    input wire [1:0] in_target_id,
    output wire out_valid,
    output wire [23:0] out_raw_rgb,out_gray_rgb,
    output wire out_mask,out_sof,out_eol,out_eof,
    output wire [10:0] out_x,out_y,
    output wire [31:0] out_epoch,out_frame_id,
    output wire [15:0] out_cfg_id,
    output wire [1:0] out_target_id,
    output reg out_abort
);
    wire accept=in_valid && !stream_abort;
    wire gray_valid;
    wire [23:0] gray;
    reg [23:0] raw;
    reg [107:0] metadata;
    rgb_to_gray_lut gray_pixel(.clk(clk),.rst_n(rst_n),.in_valid(accept),
        .in_rgb(in_rgb),.out_valid(gray_valid),.out_rgb(gray));
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin raw<=0;metadata<=0;out_abort<=0;end
        else begin
            out_abort<=stream_abort;
            raw<=accept?in_rgb:24'd0;
            metadata<=accept?{in_mask,in_sof,in_eol,in_eof,in_x,in_y,in_epoch,in_frame_id,in_cfg_id,in_target_id}:108'd0;
        end
    end
    assign out_valid=gray_valid && !stream_abort && !out_abort;
    assign out_raw_rgb=out_valid?raw:24'd0;
    assign out_gray_rgb=out_valid?gray:24'd0;
    assign {out_mask,out_sof,out_eol,out_eof,out_x,out_y,out_epoch,out_frame_id,out_cfg_id,out_target_id}=
        out_valid?metadata:108'd0;
endmodule
