// C9: raw ROI sampling, generated settings, atomic frame application, dynamic detection.
module rgb_calibrated_result #(
    parameter WIDTH=1280,HEIGHT=720,
    parameter ROI_X=(WIDTH-16)/2,ROI_Y=(HEIGHT-16)/2,
    parameter [19:0] MIN_AREA=20'd9,MAX_AREA=WIDTH*HEIGHT,
    parameter [11:0] MIN_WIDTH=12'd3,MIN_HEIGHT=12'd3
)(
    input wire clk,rst_n,pixel_valid,
    input wire [23:0] rgb,
    input wire [10:0] x,y,
    input wire sof,eol,eof,
    input wire [31:0] source_frame_id,
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
    output wire [10:0] debug_xmin,debug_ymin,debug_xmax,debug_ymax,
    input wire calibrate_req,color_select_req,
    input wire [1:0] color_select,
    output wire busy,request_ignored,
    output wire [15:0] ignored_requests,
    output wire sample_done,sample_ok,
    output wire [1:0] sample_reason,
    output wire [31:0] sample_frame_id,
    output wire [15:0] sample_cfg_id,
    output wire [1:0] sample_target_id,
    output wire [8:0] sample_count,
    output wire [15:0] sum_r,sum_g,sum_b,
    output wire [7:0] min_r,min_g,min_b,max_r,max_g,max_b,mean_r,mean_g,mean_b,
    output wire select_ignored,calibration_done,calibration_ok,cfg_applied,pending_valid,
    output wire [2:0] calibration_reason,
    output wire [31:0] calibration_frame_id,
    output wire [15:0] active_cfg_id,
    output wire [1:0] active_color,pending_color,
    output wire [7:0] active_main,active_diff_1,active_diff_2,pending_main,pending_diff_1,pending_diff_2
);
    wire sample_req,params_valid;wire [2:0] params_reason;
    wire [1:0] params_color,pixel_color;wire [15:0] pixel_cfg_id;
    wire [7:0] params_main,params_diff_1,params_diff_2,pixel_main,pixel_diff_1,pixel_diff_2;
    calibration_params generator(sample_ok,sample_count,mean_r,mean_g,mean_b,min_r,min_g,min_b,max_r,max_g,max_b,
        params_valid,params_reason,params_color,params_main,params_diff_1,params_diff_2);
    calibration_control control(
        .clk(clk),
        .rst_n(rst_n),
        .pixel_valid(pixel_valid),
        .sof(sof),
        .source_frame_id(source_frame_id),
        .calibrate_req(calibrate_req),
        .color_select_req(color_select_req),
        .color_select(color_select),
        .sample_done(sample_done),
        .params_valid(params_valid),
        .params_reason(params_reason),
        .sample_frame_id(sample_frame_id),
        .params_color(params_color),
        .params_main(params_main),
        .params_diff_1(params_diff_1),
        .params_diff_2(params_diff_2),
        .sample_req(sample_req),
        .busy(busy),
        .request_ignored(request_ignored),
        .select_ignored(select_ignored),
        .ignored_requests(ignored_requests),
        .calibration_done(calibration_done),
        .calibration_ok(calibration_ok),
        .calibration_reason(calibration_reason),
        .calibration_frame_id(calibration_frame_id),
        .cfg_applied(cfg_applied),
        .pending_valid(pending_valid),
        .pending_color(pending_color),
        .active_color(active_color),
        .pending_main(pending_main),
        .pending_diff_1(pending_diff_1),
        .pending_diff_2(pending_diff_2),
        .active_main(active_main),
        .active_diff_1(active_diff_1),
        .active_diff_2(active_diff_2),
        .active_cfg_id(active_cfg_id),
        .pixel_color(pixel_color),
        .pixel_main(pixel_main),
        .pixel_diff_1(pixel_diff_1),
        .pixel_diff_2(pixel_diff_2),
        .pixel_cfg_id(pixel_cfg_id));
    roi_color_sampler #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.ROI_X(ROI_X),.ROI_Y(ROI_Y)) sampler(
        .clk(clk),
        .rst_n(rst_n),
        .pixel_valid(pixel_valid),
        .rgb(rgb),
        .x(x),
        .y(y),
        .sof(sof),
        .eof(eof),
        .source_frame_id(source_frame_id),
        .sample_req(sample_req),
        .sample_done(sample_done),
        .sample_ok(sample_ok),
        .sample_reason(sample_reason),
        .sample_frame_id(sample_frame_id),
        .sample_cfg_id(sample_cfg_id),
        .sample_target_id(sample_target_id),
        .sample_count(sample_count),
        .sum_r(sum_r),
        .sum_g(sum_g),
        .sum_b(sum_b),
        .min_r(min_r),
        .min_g(min_g),
        .min_b(min_b),
        .max_r(max_r),
        .max_g(max_g),
        .max_b(max_b),
        .mean_r(mean_r),
        .mean_g(mean_g),
        .mean_b(mean_b),
        .cfg_id(pixel_cfg_id),.active_color(pixel_color));
    reg in_frame;
    wire accept_pixel=pixel_valid && (in_frame || sof);
    wire raw_valid,raw_mask;
    reg [10:0] raw_x,raw_y;reg raw_sof,raw_eol,raw_eof;
    reg [31:0] raw_frame_id;reg [15:0] raw_cfg_id;reg [1:0] raw_color;
    color_classifier_runtime classifier(pixel_main,pixel_diff_1,pixel_diff_2,
        clk,rst_n,accept_pixel,rgb,pixel_color,raw_valid,raw_mask);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            in_frame<=0;raw_x<=0;raw_y<=0;raw_sof<=0;raw_eol<=0;raw_eof<=0;
            raw_frame_id<=0;raw_cfg_id<=0;raw_color<=0;
        end else begin
            if(accept_pixel) in_frame<=!eof;
            raw_x<=accept_pixel ? x : 11'b0;raw_y<=accept_pixel ? y : 11'b0;
            raw_sof<=accept_pixel && sof;raw_eol<=accept_pixel && eol;raw_eof<=accept_pixel && eof;
            raw_frame_id<=accept_pixel ? source_frame_id : 32'b0;
            raw_cfg_id<=pixel_cfg_id;raw_color<=pixel_color;
        end
    end
    wire s0,v0,s1,v1;wire [31:0] f0,f1;wire [15:0] c0,c1;wire [1:0] t0,t1;
    wire [19:0] a0,a1,dc;wire [10:0] x0,y0,x1,y1,pcx,pcy,old_cx,old_cy,dl,dt,dr,db;
    wire [2:0] reason;wire [171:0] published;
    mask_denoised_result #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) detector(
        clk,rst_n,raw_valid,raw_mask,raw_x,raw_y,raw_sof,raw_eof,raw_frame_id,raw_cfg_id,raw_color,
        filtered_valid,filtered_mask,filtered_x,filtered_y,filtered_sof,filtered_eol,filtered_eof,
        filtered_frame_id,filtered_cfg_id,filtered_target_id,
        s0,v0,f0,c0,t0,a0,old_cx,x0,x1,old_cy,y0,y1);
    wire [10:0] xmin_valid,xmax_valid,ymin_valid,ymax_valid;
    target_validated_pack #(.MIN_AREA(MIN_AREA),.MAX_AREA(MAX_AREA),.MIN_WIDTH(MIN_WIDTH),.MIN_HEIGHT(MIN_HEIGHT))
        gate(clk,rst_n,s0,f0,c0,t0,a0,x0,y0,x1,y1,
        s1,v1,f1,c1,t1,a1,pcx,xmin_valid,xmax_valid,pcy,ymin_valid,ymax_valid,reason,dc,dl,dt,dr,db);
    result_new_frame dedup(clk,rst_n,s1,f1,
        {v1,c1,t1,a1,xmin_valid,ymin_valid,xmax_valid,ymax_valid,pcx,pcy,reason,dc,dl,dt,dr,db},
        result_strobe,result_frame_id,published);
    assign {target_valid,result_cfg_id,target_id,area,xmin,ymin,xmax,ymax,cx,cy,reject_reason,
            debug_count,debug_xmin,debug_ymin,debug_xmax,debug_ymax}=published;
endmodule
