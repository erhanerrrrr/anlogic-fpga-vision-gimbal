module f_calibrate #(parameter WIDTH=1280,HEIGHT=720)(
 input clk,rst_n,valid,sof,eof,input [10:0] x,y,input [23:0] rgb,
 input [31:0] frame_id,input request,next_color,
 output [1:0] color,output [7:0] main_threshold,diff1,diff2,
 output [15:0] cfg,output busy,output calibration_ok,output [2:0] reason,output calibration_done,
 output [23:0] sample_rgb,output [8:0] sample_pixels,output [7:0] sample_span,output active_calibrated
);
 wire req,done,ok,pvalid;
 wire [2:0] preason;
 wire [1:0] pcolor,active_color;
 wire [7:0] pm,pd1,pd2,mr,mg,mb,lr,lg,lb,hr,hg,hb;
 wire [8:0] count;
 wire [31:0] sample_id;
 // Completed K3 sample, retained even if parameter validation rejects it.
 wire [7:0] span_r=hr-lr,span_g=hg-lg,span_b=hb-lb;
 wire [7:0] span_rg=span_r>span_g?span_r:span_g;
 assign sample_rgb={mr,mg,mb};
 assign sample_pixels=count;
 assign sample_span=span_rg>span_b?span_rg:span_b;
 calibration_control #(.INITIAL_CFG_ID(1)) control(
 .clk(clk),.rst_n(rst_n),.pixel_valid(valid),.sof(sof),.source_frame_id(frame_id),
 .calibrate_req(request),.color_select_req(next_color),.color_select(active_color==2?2'd0:active_color+2'd1),
 .sample_done(done),.params_valid(pvalid),.params_reason(preason),.sample_frame_id(sample_id),
 .params_color(pcolor),.params_main(pm),.params_diff_1(pd1),.params_diff_2(pd2),
 .sample_req(req),.calibration_done(calibration_done),.busy(busy),.calibration_ok(calibration_ok),.calibration_reason(reason),
 .active_calibrated(active_calibrated),.active_color(active_color),.pixel_color(color),.pixel_main(main_threshold),
 .pixel_diff_1(diff1),.pixel_diff_2(diff2),.pixel_cfg_id(cfg));
 roi_color_sampler #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) sampler(
 .clk(clk),.rst_n(rst_n),.pixel_valid(valid),.rgb(rgb),.x(x),.y(y),.sof(sof),.eof(eof),
 .source_frame_id(frame_id),.cfg_id(cfg),.active_color(color),.sample_req(req),
 .sample_done(done),.sample_ok(ok),.sample_frame_id(sample_id),.sample_count(count),
 .min_r(lr),.min_g(lg),.min_b(lb),.max_r(hr),.max_g(hg),.max_b(hb),.mean_r(mr),.mean_g(mg),.mean_b(mb));
 calibration_params params(.sample_ok(ok),.sample_count(count),.mean_r(mr),.mean_g(mg),.mean_b(mb),
 .min_r(lr),.min_g(lg),.min_b(lb),.max_r(hr),.max_g(hg),.max_b(hb),
 .valid(pvalid),.reason(preason),.color(pcolor),.min_main(pm),.diff_1(pd1),.diff_2(pd2));
endmodule
