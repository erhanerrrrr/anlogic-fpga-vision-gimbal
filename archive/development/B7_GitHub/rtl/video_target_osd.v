`timescale 1ns/1ps
// B1a extraction: target overlay and official Logo, internal pixel stream.
// Feed background RGB after existing mask/Gamma/diagnostic composition.
// No DDR read control, classifier, HDMI timing generator or control FSM here.
module video_target_osd #(
    parameter integer WIDTH=1280, HEIGHT=720,
    parameter integer LOGO_X=1104, LOGO_Y=16
)(
    input wire clk,rst_n,stream_abort,
    input wire in_valid,in_sof,in_eol,in_eof,
    input wire [10:0] in_x,in_y,
    input wire [23:0] in_rgb,
    input wire [31:0] in_refresh_id,
    input wire completed_ready,
    input wire [31:0] completed_refresh_id,
    input wire [15:0] expected_cfg_id,
    input wire [1:0] expected_target_id,
    input wire result_strobe,target_valid,
    input wire [31:0] result_frame_id,
    input wire [15:0] result_cfg_id,
    input wire [1:0] result_target_id,
    input wire [19:0] area,
    input wire [10:0] xmin,ymin,xmax,ymax,cx,cy,
    input wire [2:0] reason,
    input wire [7:0] labels_used,
    input wire [11:0] components,
    output reg out_valid,out_sof,out_eol,out_eof,
    output reg [10:0] out_x,out_y,
    output reg [23:0] out_rgb,
    output reg [31:0] out_refresh_id,
    output reg out_snapshot_ready,
    output reg [159:0] out_packet
);
    wire [159:0] incoming={result_frame_id,result_cfg_id,result_target_id,target_valid,
        area,xmin,ymin,xmax,ymax,cx,cy,reason,labels_used,components};
    wire [159:0] selected;
    wire opened,ready;
    b1_target_snapshot #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) snapshot(
        .clk(clk),.rst_n(rst_n),.stream_abort(stream_abort),
        .pixel_valid(in_valid),.pixel_sof(in_sof),
        .result_strobe(result_strobe),.result_packet(incoming),
        .completed_ready(completed_ready),.completed_refresh_id(completed_refresh_id),
        .expected_cfg_id(expected_cfg_id),.expected_target_id(expected_target_id),
        .pixel_frame_open(opened),.pixel_ready(ready),.pixel_packet(selected));
    reg v1,s1,l1,e1,ready1;
    reg [10:0] x1,y1;
    reg [23:0] rgb1;
    reg [31:0] id1;
    reg [159:0] packet1;
    wire [31:0] fid;
    wire [15:0] cfg;
    wire [1:0] tid;
    wire tv;
    wire [19:0] a;
    wire [10:0] left,top,right,bottom,center_x,center_y;
    wire [2:0] why;
    wire [7:0] slots;
    wire [11:0] count;
    assign {fid,cfg,tid,tv,a,left,top,right,bottom,center_x,center_y,why,slots,count}=packet1;
    wire inside_box=tv && x1>=left && x1<=right && y1>=top && y1<=bottom;
    wire [11:0] dl={1'b0,x1}-{1'b0,left}, dr={1'b0,right}-{1'b0,x1};
    wire [11:0] dt={1'b0,y1}-{1'b0,top}, db={1'b0,bottom}-{1'b0,y1};
    // Preserve H4E: inward 2-pixel border, 17x3 / 3x17 center cross.
    wire box_on=inside_box && (dl<2 || dr<2 || dt<2 || db<2);
    wire [11:0] dx=x1>=center_x ? {1'b0,x1}-{1'b0,center_x} : {1'b0,center_x}-{1'b0,x1};
    wire [11:0] dy=y1>=center_y ? {1'b0,y1}-{1'b0,center_y} : {1'b0,center_y}-{1'b0,y1};
    wire cross_on=tv && ((dx<=8 && dy<=1) || (dx<=1 && dy<=8));
    // Register the address in parallel with stage-one pixels. This separates
    // coordinate subtraction/address formation from the combinational ROM.
    wire logo_region=in_x>=LOGO_X && in_x<LOGO_X+160 && in_y>=LOGO_Y && in_y<LOGO_Y+160;
    wire [10:0] lx=in_x-LOGO_X,ly=in_y-LOGO_Y;
    wire [14:0] address={ly[7:0],7'b0}+{2'b0,ly[7:0],5'b0}+{7'b0,lx[7:0]};
    reg logo_on;
    reg [14:0] logo_address;
    wire [24:0] logo;
    anlogic_logo_rom logo_rom(.I_addr(logo_address),.O_pixel(logo));
    wire [23:0] composed=logo_on && logo[24] ? logo[23:0] :
        cross_on ? 24'h00ffff : box_on ? 24'h00ff00 : rgb1;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            logo_on<=0;logo_address<=0;
            v1<=0;s1<=0;l1<=0;e1<=0;ready1<=0;x1<=0;y1<=0;rgb1<=0;id1<=0;packet1<=0;
            out_valid<=0;out_sof<=0;out_eol<=0;out_eof<=0;out_x<=0;out_y<=0;out_rgb<=0;
            out_refresh_id<=0;out_snapshot_ready<=0;out_packet<=0;
        end else if(stream_abort) begin
            logo_on<=0;logo_address<=0;
            v1<=0;s1<=0;l1<=0;e1<=0;ready1<=0;x1<=0;y1<=0;rgb1<=0;id1<=0;packet1<=0;
            out_valid<=0;out_sof<=0;out_eol<=0;out_eof<=0;out_x<=0;out_y<=0;out_rgb<=0;
            out_refresh_id<=0;out_snapshot_ready<=0;out_packet<=0;
        end else begin
            logo_on<=logo_region;logo_address<=logo_region ? address : 15'd0;
            v1<=in_valid && opened && in_x<WIDTH && in_y<HEIGHT;
            s1<=in_sof;l1<=in_eol;e1<=in_eof;x1<=in_x;y1<=in_y;
            rgb1<=in_rgb;id1<=in_refresh_id;packet1<=selected;ready1<=ready;
            out_valid<=v1;out_sof<=v1 && s1;out_eol<=v1 && l1;out_eof<=v1 && e1;
            out_x<=x1;out_y<=y1;out_refresh_id<=id1;
            out_rgb<=v1 ? composed : 24'd0;
            out_snapshot_ready<=ready1;out_packet<=packet1;
        end
    end
endmodule
