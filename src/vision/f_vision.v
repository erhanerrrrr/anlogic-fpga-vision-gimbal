module f_vision #(parameter WIDTH=1280,HEIGHT=720,MOTION_ONLY=0,INTEGRATED=0)(
 input clk,rst_n,vs,hs,de,user,input [23:0] rgb,
 input [80:0] source_meta,input [31:0] tick,
 input mode_event,color_event,cal_event,
 input [82:0] ae_status,output ae_inhibit,ae_profile_event,ae_hold_event,
 output ae_sample,output [31:0] ae_sample_data,
 input [1:0] view_page,input source_live,
 output [7:0] local_status,
 input [2:0] tracking_state,input [11:0] pan_us,tilt_us,input [19:0] diagnostics,
 output ovs,ohs,ode,output [23:0] orgb,
 output motion_hold,output [63:0] result_info,
 output result_send,output [71:0] result_packet
);
 wire valid,sof,eof;
 wire [10:0] x,y;
 wire [31:0] refresh;
 display_raster_adapter #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) raster(
 .clk(clk),.rst_n(rst_n),.de(de),.user(user),.valid(valid),.sof(sof),.eof(eof),.x(x),.y(y),.refresh_id(refresh));
 reg [2:0] pending_mode,mode;
 reg [80:0] frame_meta;
 wire [80:0] pm=sof?source_meta:frame_meta;
 wire [31:0] fid=pm[63:32];
 reg [31:0] latency;
 wire [15:0] source_fps,display_fps;
 f_rate rate(.clk(clk),.rst_n(rst_n),.sof(sof),.source_ok(pm[64]),.source_id(fid),.source_fps(source_fps),.display_fps(display_fps));
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin pending_mode<=MOTION_ONLY?6:0;mode<=MOTION_ONLY?6:0;frame_meta<=0;latency<=0;end
 else begin
   if(mode_event && !MOTION_ONLY && (!INTEGRATED || view_page!=3))pending_mode<=pending_mode+1'b1;
   // Commit in blanking on USER; SOF may coincide with first active pixel.
   if(user)mode<=pending_mode;
   if(sof)begin frame_meta<=source_meta;latency<=tick-source_meta[31:0];end
 end
 wire [1:0] color;
 wire [7:0] main_threshold,diff1,diff2;
 wire [15:0] cfg;

 reg [11:0] last_pan,last_tilt;
 reg camera_stable;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin last_pan<=1500;last_tilt<=1500;camera_stable<=0;end
 else if(sof)begin camera_stable<=pan_us==last_pan && tilt_us==last_tilt;last_pan<=pan_us;last_tilt<=tilt_us;end
 wire motion_learned;
 wire cal_busy,cal_ok,cal_done,active_calibrated;
 wire diagnostic_page=INTEGRATED && view_page==3;
 wire normal_cal=cal_event && !diagnostic_page && mode!=6 && (!INTEGRATED || mode!=7);
 wire motion_cal=cal_event && !diagnostic_page && mode==6;
 wire next_color=color_event && !diagnostic_page && (!INTEGRATED || mode!=7);
 reg cal_pending,cal_dispatch,motion_pending,motion_dispatch;
 wire exposure_ready=!INTEGRATED || ae_status[82];
 assign ae_inhibit=mode==6 || pending_mode==6 || cal_pending || cal_dispatch || cal_busy || normal_cal;
 assign ae_profile_event=INTEGRATED && mode==7 && !diagnostic_page && color_event;
 assign ae_hold_event=INTEGRATED && mode==7 && !diagnostic_page && cal_event;
 assign motion_hold=(mode==6 || pending_mode==6 || cal_busy || (INTEGRATED && (cal_pending || cal_dispatch || normal_cal)));
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin cal_pending<=0;cal_dispatch<=0;motion_pending<=0;motion_dispatch<=0;end
 else begin
   cal_dispatch<=0;motion_dispatch<=0;
   if(normal_cal)cal_pending<=1;
   if(motion_cal)motion_pending<=1;
   if(sof && exposure_ready && source_live)begin
     if(cal_pending && mode!=6 && mode!=7)begin cal_dispatch<=1;cal_pending<=0;end
     if(motion_pending && mode==6)begin motion_dispatch<=1;motion_pending<=0;end
   end
   if(mode_event || next_color)cal_pending<=0;
   if(mode!=6 && pending_mode!=6)motion_pending<=0;
 end
 wire [7:0] ae_mean;wire [11:0] ae_clipped,ae_near;
 f_ae_meter meter(.clk(clk),.rst_n(rst_n),.valid(valid),.sof(sof),.eof(eof),
   .source_ok(pm[64]),.frame_id(fid),.x(x),.y(y),.rgb(rgb),
   .sample(ae_sample),.mean(ae_mean),.clipped(ae_clipped),.near_clip(ae_near),.rejected());
 assign ae_sample_data={ae_mean,ae_clipped,ae_near};
 reg paused;reg [1:0] graph_scale;
 wire clear_stats=diagnostic_page && cal_event;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin paused<=0;graph_scale<=0;end
 else if(diagnostic_page)begin
   if(mode_event)paused<=!paused;
   if(color_event)graph_scale<=graph_scale==2?0:graph_scale+1'b1;
 end
 // Two image stages plus three shared OSD stages end at HDMI TX input.
 reg [4:0] hdmi_sof;
 always @(posedge clk or negedge rst_n)if(!rst_n)hdmi_sof<=0;else hdmi_sof<={hdmi_sof[3:0],sof};
 wire latency_publish;wire [11:0] latency_now,latency_min,latency_max;
 wire [15:0] latency_samples,latency_repeats,latency_invalid;wire [1:0] latency_status;wire [31:0] latency_id;
 f_latency_meter latency_meter(.clk(clk),.rst_n(rst_n),.display_sof(hdmi_sof[4]),
   .source_ok(frame_meta[64]),.source_id(frame_meta[63:32]),.capture_tick(frame_meta[31:0]),.now_tick(tick),
   .pause(paused),.clear(clear_stats),.publish(latency_publish),.current_tenths(latency_now),
   .min_tenths(latency_min),.max_tenths(latency_max),.samples(latency_samples),.repeats(latency_repeats),
   .invalid(latency_invalid),.status(latency_status),.displayed_id(latency_id));
 wire [511:0] dashboard_line;wire dashboard_pixel;wire [23:0] dashboard_rgb;
 wire [2:0] cal_reason;
 wire [23:0] sample_rgb;
 wire [8:0] sample_pixels;
 wire [7:0] sample_span;
 reg cal_sequence;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)cal_sequence<=0;else if((!MOTION_ONLY && cal_done) || motion_learned)cal_sequence<=!cal_sequence;
 assign local_status=MOTION_ONLY?{3'd6,cal_sequence,1'b1,3'd0}:{mode,cal_sequence,(mode==6?1'b1:cal_ok),cal_reason};
 f_calibrate #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) calibrate(
 .clk(clk),.rst_n(rst_n),.valid(valid && pm[64]),.sof(sof),.eof(eof),.x(x),.y(y),.rgb(rgb),
 .frame_id(fid),.request(INTEGRATED?cal_dispatch:(cal_event && mode!=6)),.next_color(next_color),.color(color),
 .main_threshold(main_threshold),.diff1(diff1),.diff2(diff2),.cfg(cfg),
 .busy(cal_busy),.calibration_ok(cal_ok),.reason(cal_reason),.calibration_done(cal_done),
 .sample_rgb(sample_rgb),.sample_pixels(sample_pixels),.sample_span(sample_span),.active_calibrated(active_calibrated));
 wire iv,is,ie,ivs,ihs,mv,mask,seed_mask;
 wire [10:0] ix,iy;
 wire [23:0] image_rgb;
 wire [31:0] image_id;
 wire [6:0] gain;
 wire [7:0] mean;
 wire [14:0] motion,motion_changes,motion_capture_diff;wire [2:0] motion_capture_reason;
 wire [2:0] motion_status;
 reg [1:0] display_page;
 f_image #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MOTION_ONLY(MOTION_ONLY),.SENSOR_AE(INTEGRATED)) image_path(
 .clk(clk),.rst_n(rst_n),.valid(valid),.sof(sof),.eof(eof),.vs(vs),.hs(hs),.x(x),.y(y),.rgb(rgb),
 .motion_capture(INTEGRATED?motion_dispatch:(cal_event && mode==6)),.camera_stable(camera_stable && exposure_ready),
 .hide_motion(!INTEGRATED && (sof ? view_page==2 : display_page==2)),.source_id(fid),.source_ok(pm[64] && source_live),.mode(mode),.color(MOTION_ONLY?2'd0:color),.min_main(MOTION_ONLY?8'd24:main_threshold),.diff1(MOTION_ONLY?8'd16:diff1),.diff2(MOTION_ONLY?8'd16:diff2),
 .ov(iv),.osof(is),.oeof(ie),.ovs(ivs),.ohs(ihs),.ox(ix),.oy(iy),.orgb(image_rgb),.oid(image_id),
 .mask_valid(mv),.mask(mask),.seed_mask(seed_mask),.gain(gain),.mean_luma(mean),.motion_count(motion),.motion_changes(motion_changes),.motion_capture_diff(motion_capture_diff),.motion_capture_reason(motion_capture_reason),.motion_status(motion_status),.motion_learned(motion_learned));
 reg v1,s1,e1;
 reg [10:0] x1,y1;
 reg [31:0] id1;
 reg [15:0] cfg1;
 reg [1:0] color1;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin v1<=0;s1<=0;e1<=0;x1<=0;y1<=0;id1<=0;cfg1<=0;color1<=0;end
 else begin v1<=valid;s1<=sof;e1<=eof;x1<=x;y1<=y;id1<=fid;cfg1<=cfg;color1<=color;end
 wire fv,fm,fs,fe;
 wire [10:0] fx,fy;
 wire [31:0] ff;
 wire [15:0] fc;
 wire [1:0] ft;
 mask_majority_3x3 #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) denoise(
 .clk(clk),.rst_n(rst_n),.mask_valid(mv && v1),.mask(mask && y1>=4 && y1<HEIGHT-4),
 .x(x1),.y(y1),.sof(s1),.eof(e1),.source_frame_id(id1),.cfg_id(cfg1),.target_id(color1),
 .out_valid(fv),.out_mask(fm),.out_x(fx),.out_y(fy),.out_sof(fs),.out_eof(fe),
 .out_frame_id(ff),.out_cfg_id(fc),.out_target_id(ft));
 // Identical pipeline gives strong/weak masks the same coordinates and frame ID.
 wire seed_fv,seed_fm;
 mask_majority_3x3 #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) seed_denoise(
 .clk(clk),.rst_n(rst_n),.mask_valid(mv && v1),.mask(seed_mask && y1>=4 && y1<HEIGHT-4),
 .x(x1),.y(y1),.sof(s1),.eof(e1),.source_frame_id(id1),.cfg_id(cfg1),.target_id(color1),
 .out_valid(seed_fv),.out_mask(seed_fm));
 wire strobe,tvalid,busy;
 wire [2:0] reason;
 wire [31:0] rid;
 wire [15:0] rcfg;
 wire [1:0] rcolor;
 wire [19:0] area;
 wire [10:0] cx,cy,x0,x2,y0,y2;
 wire [1023:0] shape_extrema;
 f_shape_regions #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.SEED_CHECK(1)) region(
 .clk(clk),.rst_n(rst_n),.mask_valid(fv),.mask(fm),.seed(seed_fm && seed_fv),.x(fx),.y(fy),.sof(fs),.eof(fe),
 .frame_id(ff),.cfg_id(fc),.target_id(ft),.result_strobe(strobe),.target_valid(tvalid),.reason(reason),
 .result_frame_id(rid),.result_cfg_id(rcfg),.result_target_id(rcolor),.area(area),.cx(cx),.cy(cy),
 .xmin(x0),.xmax(x2),.ymin(y0),.ymax(y2),.shape_extrema(shape_extrema),.busy(busy));
 assign result_info=MOTION_ONLY?{3'd6,2'd0,3'd0,motion_status,motion,latency,6'b0}:{mode,rcolor,reason,motion_status,motion,latency,6'b0};
 // Four pixel clocks after EOF: motion status has committed before the mailbox samples it.
 reg [3:0] motion_eof_delay;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)motion_eof_delay<=0;else motion_eof_delay<={motion_eof_delay[2:0],eof};
 assign result_send=MOTION_ONLY?motion_eof_delay[3]:strobe;
 assign result_packet=MOTION_ONLY?{frame_meta[64],1'b0,frame_meta[63:32],16'd1,11'd0,11'd0}:{frame_meta[64] && rid==frame_meta[63:32],tvalid,rid,rcfg,cx,cy};
 wire snapshot_publish,snapshot_seen,snapshot_valid;
 wire [2:0] snapshot_reason;
 wire [31:0] snapshot_id;
 wire [15:0] snapshot_cfg;
 wire [1:0] snapshot_color,object_class;
 wire [19:0] snapshot_area;
 wire [10:0] scx,scy,sx0,sx1,sy0,sy1;
 wire [6:0] fill;
 f_result_bundle #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.STABLE_EXTREMA(1)) results(
 .clk(clk),.rst_n(rst_n),.input_strobe(strobe),.input_valid(tvalid),
 .input_source_ok(frame_meta[64] && rid==frame_meta[63:32]),.input_reason(reason),
 .input_id(rid),.input_cfg(rcfg),.input_color(rcolor),.input_area(area),
 .input_extrema(shape_extrema),.input_cx(cx),.input_cy(cy),.input_x0(x0),.input_x1(x2),.input_y0(y0),.input_y1(y2),
 .publish(snapshot_publish),.seen(snapshot_seen),.result_valid(snapshot_valid),.result_reason(snapshot_reason),
 .result_id(snapshot_id),.result_cfg(snapshot_cfg),.result_color(snapshot_color),.object_class(object_class),
 .result_area(snapshot_area),.cx(scx),.cy(scy),.x0(sx0),.x1(sx1),.y0(sy0),.y1(sy1),.fill(fill));
 reg [1:0] result_age;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)result_age<=3;
 else if(snapshot_publish)result_age<=0;
 else if(sof && result_age!=3)result_age<=result_age+1'b1;
 wire display_result_ok=!MOTION_ONLY && snapshot_seen && result_age<3 && snapshot_cfg==cfg && pm[64] && source_live;
 wire display_target_ok=display_result_ok && snapshot_valid;
 reg dv,dlive,dcalibrated;
 reg [2:0] dreason,dstate;
 reg [1:0] dclass,dcolor;
 reg [10:0] dcx,dcy,dx0,dx1,dy0,dy1;
 reg [11:0] dpan,dtilt;
 reg [19:0] ddiagnostics;
 reg [31:0] dresult_id,dlatency;
 reg [19:0] darea;
 reg [14:0] dmotion,dchanges,dcapture_diff;reg [2:0] dmotion_status,dcapture_reason;
 reg [6:0] dgain;
 reg [7:0] dmean;
 reg [15:0] dcfg;
 reg [15:0] dsfps,ddfps,dcfps;
 reg [4:0] dcal;
 reg [23:0] dsample_rgb;
 reg [8:0] dsample_pixels;
 reg [7:0] dsample_span,dmain,ddiff1,ddiff2;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
   dcalibrated<=0;dv<=0;display_page<=0;dlive<=0;dreason<=4;dstate<=0;dclass<=0;dcolor<=0;dcx<=0;dcy<=0;dx0<=0;dx1<=0;dy0<=0;dy1<=0;
   ddiagnostics<=0;dpan<=1500;dtilt<=1500;dresult_id<=0;dlatency<=0;darea<=0;dmotion<=0;dchanges<=0;dcapture_diff<=0;dcapture_reason<=0;dmotion_status<=0;dgain<=16;dmean<=0;dcfg<=1;dcal<=0;dsfps<=0;ddfps<=0;dcfps<=0;
   dsample_rgb<=0;dsample_pixels<=0;dsample_span<=0;dmain<=24;ddiff1<=16;ddiff2<=16;
 end else if(sof)begin
   dv<=display_target_ok;display_page<=view_page;dlive<=source_live;
   dreason<=display_result_ok?snapshot_reason:3'd4;dstate<=tracking_state;
   dclass<=display_target_ok?object_class:0;dcolor<=MOTION_ONLY?2'd0:color;dcalibrated<=!MOTION_ONLY && active_calibrated;
   dcx<=display_target_ok?scx:0;dcy<=display_target_ok?scy:0;
   dx0<=display_target_ok?sx0:0;dx1<=display_target_ok?sx1:0;dy0<=display_target_ok?sy0:0;dy1<=display_target_ok?sy1:0;dpan<=pan_us;dtilt<=tilt_us;
   dresult_id<=MOTION_ONLY?frame_meta[63:32]:snapshot_id;dlatency<=tick-source_meta[31:0];darea<=display_target_ok?snapshot_area:0;dmotion<=motion;dchanges<=motion_changes;dcapture_diff<=motion_capture_diff;dcapture_reason<=motion_capture_reason;dmotion_status<=motion_status;dgain<=INTEGRATED?7'd16:gain;dmean<=INTEGRATED?ae_mean:mean;
   dcfg<=MOTION_ONLY?16'd1:cfg;dcal<=MOTION_ONLY?5'd0:{cal_busy,cal_ok,cal_reason};
   dsample_rgb<=MOTION_ONLY?24'd0:sample_rgb;dsample_pixels<=MOTION_ONLY?9'd0:sample_pixels;dsample_span<=MOTION_ONLY?8'd0:sample_span;
   dmain<=MOTION_ONLY?8'd24:main_threshold;ddiff1<=MOTION_ONLY?8'd16:diff1;ddiff2<=MOTION_ONLY?8'd16:diff2;
   dsfps<=source_fps;ddfps<=display_fps;dcfps<=pm[80:65];ddiagnostics<=diagnostics;
 end
 f_system_dashboard dashboard(.clk(clk),.rst_n(rst_n),.sof(sof),.x(ix),.y(iy),
   .latency_page(display_page==3),.ae_status(ae_status[81:0]),.state(dstate),
   .status(latency_status),.scale(graph_scale),.paused(paused),.clear(clear_stats),.publish(latency_publish),
   .current_tenths(latency_now),.min_tenths(latency_min),.max_tenths(latency_max),
   .samples(latency_samples),.repeats(latency_repeats),.invalid(latency_invalid),
   .capture_fps(dcfps),.display_fps(ddfps),.frame_id(latency_id),
   .textline(dashboard_line),.draw(dashboard_pixel),.pixel(dashboard_rgb));
 f_osd #(.MOTION_ONLY(MOTION_ONLY),.INTEGRATED(INTEGRATED)) osd(.motion_capture_diff(dcapture_diff),.motion_capture_reason(dcapture_reason),.motion_status(dmotion_status),.motion_changes(dchanges),.clk(clk),.rst_n(rst_n),.valid(iv),.vs(ivs),.hs(ihs),.x(ix),.y(iy),.rgb(image_rgb),
 .extra_line(dashboard_line),.extra_draw(dashboard_pixel),.extra_rgb(dashboard_rgb),.diagnostics(ddiagnostics),.view_page(display_page),.source_live(dlive),.mode(mode),.source_ok(frame_meta[64]),.source_id(image_id),.result_id(dresult_id),.latency(dlatency),
 .target_valid(dv),.reason(dreason),.cx(dcx),.cy(dcy),.x0(dx0),.x1(dx1),.y0(dy0),.y1(dy1),.area(darea),
 .object_class(dclass),.color(dcolor),.state(dstate),.pan(dpan),.tilt(dtilt),.motion(dmotion),
 .gain(dgain),.mean(dmean),.cfg(dcfg),.cal(dcal),.active_calibrated(dcalibrated),.source_fps(dsfps),.display_fps(ddfps),.capture_fps(dcfps),
 .sample_rgb(dsample_rgb),.sample_pixels(dsample_pixels),.sample_span(dsample_span),
 .threshold_main(dmain),.threshold_d1(ddiff1),.threshold_d2(ddiff2),.ov(ode),.ovs(ovs),.ohs(ohs),.orgb(orgb));
endmodule
