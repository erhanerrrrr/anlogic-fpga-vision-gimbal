// C7: preserve display masks; publish only new source-frame observations.
module rgb_fresh_result #(
    parameter WIDTH=1280,HEIGHT=720,
    parameter [19:0] MIN_AREA=20'd9,MAX_AREA=WIDTH*HEIGHT,
    parameter [11:0] MIN_WIDTH=12'd3,MIN_HEIGHT=12'd3
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
    output wire [10:0] cx,xmin,xmax,cy,ymin,ymax,
    output wire [2:0] reject_reason,
    output wire [19:0] debug_count,
    output wire [10:0] debug_xmin,debug_ymin,debug_xmax,debug_ymax
);
    wire candidate_strobe,v;
    wire [31:0] candidate_frame_id;
    wire [15:0] c;wire [1:0] t;wire [19:0] a,dc;
    wire [10:0] pcx,pcy,x0,y0,x1,y1,dl,dt,dr,db;wire [2:0] reason;
    wire [171:0] candidate_payload={v,c,t,a,x0,y0,x1,y1,pcx,pcy,reason,dc,dl,dt,dr,db};
    wire [171:0] published;
    rgb_validated_result #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MIN_AREA(MIN_AREA),.MAX_AREA(MAX_AREA),
        .MIN_WIDTH(MIN_WIDTH),.MIN_HEIGHT(MIN_HEIGHT)) detector(
        clk,rst_n,pixel_valid,rgb,x,y,sof,eol,eof,source_frame_id,cfg_id,active_color,
        filtered_valid,filtered_mask,filtered_x,filtered_y,filtered_sof,filtered_eol,filtered_eof,
        filtered_frame_id,filtered_cfg_id,filtered_target_id,
        candidate_strobe,v,candidate_frame_id,c,t,a,pcx,x0,x1,pcy,y0,y1,reason,dc,dl,dt,dr,db);
    result_new_frame dedup(clk,rst_n,candidate_strobe,candidate_frame_id,candidate_payload,
        result_strobe,result_frame_id,published);
    assign {target_valid,result_cfg_id,target_id,area,xmin,ymin,xmax,ymax,cx,cy,reject_reason,
            debug_count,debug_xmin,debug_ymin,debug_xmax,debug_ymax}=published;
endmodule
