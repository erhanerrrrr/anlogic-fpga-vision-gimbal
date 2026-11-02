`timescale 1ns/1ps
module tb_f2x_char_equiv;
 reg [511:0] extra_line;reg extra_draw;reg [23:0] extra_rgb;integer j;
 reg clk=0;
 reg  rst_n=0;
 reg  valid=0;
 reg  vs=0;
 reg  hs=0;
 reg [10:0] x=0;
 reg [10:0] y=0;
 reg [23:0] rgb=0;
 reg [2:0] motion_status=0;
 reg [14:0] motion_changes=0;
 reg [14:0] motion_capture_diff=0;reg [2:0] motion_capture_reason=0;
 reg [1:0] view_page=0;
 reg  source_live=0;
 reg [2:0] mode=0;
 reg  source_ok=0;
 reg [31:0] source_id=0;
 reg [31:0] result_id=0;
 reg [31:0] latency=0;
 reg  target_valid=0;
 reg [2:0] reason=0;
 reg [10:0] cx=0;
 reg [10:0] cy=0;
 reg [10:0] x0=0;
 reg [10:0] x1=0;
 reg [10:0] y0=0;
 reg [10:0] y1=0;
 reg [19:0] area=0;
 reg [1:0] object_class=0;
 reg [1:0] color=0;
 reg [2:0] state=0;
 reg [11:0] pan=0;
 reg [11:0] tilt=0;
 reg [14:0] motion=0;
 reg [6:0] gain=0;
 reg [7:0] mean=0;
 reg [15:0] cfg=0;
 reg [4:0] cal=0;
 reg  active_calibrated=0;
 reg [15:0] source_fps=0;
 reg [15:0] display_fps=0;
 reg [15:0] capture_fps=0;
 reg [19:0] diagnostics=0;
 reg [23:0] sample_rgb=0;
 reg [8:0] sample_pixels=0;
 reg [7:0] sample_span=0;
 reg [7:0] threshold_main=0;
 reg [7:0] threshold_d1=0;
 reg [7:0] threshold_d2=0;
 wire  a_ov,b_ov;
 wire  a_ovs,b_ovs;
 wire  a_ohs,b_ohs;
 wire [23:0] a_orgb,b_orgb;
 always #5 clk=~clk;
 integer xx,yy,p,m,seed=32'h24be9901,checked=0;
f_osd #(.INTEGRATED(1)) dut(.extra_line(extra_line),.extra_draw(extra_draw),.extra_rgb(extra_rgb),.clk(clk),.rst_n(rst_n),.valid(valid),.vs(vs),.hs(hs),.x(x),.y(y),.rgb(rgb),.motion_status(motion_status),.motion_changes(motion_changes),.motion_capture_diff(motion_capture_diff),.motion_capture_reason(motion_capture_reason),.view_page(view_page),.source_live(source_live),.mode(mode),.source_ok(source_ok),.source_id(source_id),.result_id(result_id),.latency(latency),.target_valid(target_valid),.reason(reason),.cx(cx),.cy(cy),.x0(x0),.x1(x1),.y0(y0),.y1(y1),.area(area),.object_class(object_class),.color(color),.state(state),.pan(pan),.tilt(tilt),.motion(motion),.gain(gain),.mean(mean),.cfg(cfg),.cal(cal),.active_calibrated(active_calibrated),.source_fps(source_fps),.display_fps(display_fps),.capture_fps(capture_fps),.diagnostics(diagnostics),.sample_rgb(sample_rgb),.sample_pixels(sample_pixels),.sample_span(sample_span),.threshold_main(threshold_main),.threshold_d1(threshold_d1),.threshold_d2(threshold_d2),.ov(a_ov),.ovs(a_ovs),.ohs(a_ohs),.orgb(a_orgb));
f2x_osd_r3_reference #(.INTEGRATED(1)) reference(.extra_line(extra_line),.extra_draw(extra_draw),.extra_rgb(extra_rgb),.clk(clk),.rst_n(rst_n),.valid(valid),.vs(vs),.hs(hs),.x(x),.y(y),.rgb(rgb),.motion_status(motion_status),.motion_changes(motion_changes),.motion_capture_diff(motion_capture_diff),.motion_capture_reason(motion_capture_reason),.view_page(view_page),.source_live(source_live),.mode(mode),.source_ok(source_ok),.source_id(source_id),.result_id(result_id),.latency(latency),.target_valid(target_valid),.reason(reason),.cx(cx),.cy(cy),.x0(x0),.x1(x1),.y0(y0),.y1(y1),.area(area),.object_class(object_class),.color(color),.state(state),.pan(pan),.tilt(tilt),.motion(motion),.gain(gain),.mean(mean),.cfg(cfg),.cal(cal),.active_calibrated(active_calibrated),.source_fps(source_fps),.display_fps(display_fps),.capture_fps(capture_fps),.diagnostics(diagnostics),.sample_rgb(sample_rgb),.sample_pixels(sample_pixels),.sample_span(sample_span),.threshold_main(threshold_main),.threshold_d1(threshold_d1),.threshold_d2(threshold_d2),.ov(b_ov),.ovs(b_ovs),.ohs(b_ohs),.orgb(b_orgb));
 reg prev_ov=0,prev_vs=0,prev_hs=0;reg [23:0] prev_rgb=0;
 always @(posedge clk)if(rst_n)begin
  #1;
  if(a_ov!==b_ov)$fatal(1,"OSD ov mismatch page=%0d mode=%0d xy=%0d,%0d",view_page,mode,x,y);
  if(a_ovs!==b_ovs)$fatal(1,"OSD ovs mismatch page=%0d mode=%0d xy=%0d,%0d",view_page,mode,x,y);
  if(a_ohs!==b_ohs)$fatal(1,"OSD ohs mismatch page=%0d mode=%0d xy=%0d,%0d",view_page,mode,x,y);
  if(a_orgb!==b_orgb)$fatal(1,"OSD orgb mismatch page=%0d mode=%0d xy=%0d,%0d",view_page,mode,x,y);
  prev_ov=b_ov;prev_vs=b_ovs;prev_hs=b_ohs;prev_rgb=b_orgb;
  if(a_ov)checked=checked+1;
 end
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  for(p=0;p<4;p=p+1)if(p!=2)for(m=0;m<8;m=m+1)begin
   view_page=p;mode=m;
   for(yy=0;yy<720;yy=yy+17)begin
    for(j=0;j<16;j=j+1)extra_line[j*32+:32]=$random(seed);extra_draw=$random(seed);extra_rgb=$random(seed);
    motion_status=$random(seed);
    motion_changes=$random(seed);motion_capture_diff=$random(seed);motion_capture_reason=$random(seed);
    source_live=$random(seed);
    source_ok=$random(seed);
    source_id=$random(seed);
    result_id=$random(seed);
    latency=$random(seed);
    target_valid=$random(seed);
    reason=$random(seed);
    cx=$random(seed);
    cy=$random(seed);
    x0=$random(seed);
    x1=$random(seed);
    y0=$random(seed);
    y1=$random(seed);
    area=$random(seed);
    object_class=$random(seed);
    color=$random(seed);
    state=$random(seed);
    pan=$random(seed);
    tilt=$random(seed);
    motion=$random(seed);
    gain=$random(seed);
    mean=$random(seed);
    cfg=$random(seed);
    cal=$random(seed);
    active_calibrated=$random(seed);
    source_fps=$random(seed);
    display_fps=$random(seed);
    capture_fps=$random(seed);
    diagnostics=$random(seed);
    sample_rgb=$random(seed);
    sample_pixels=$random(seed);
    sample_span=$random(seed);
    threshold_main=$random(seed);
    threshold_d1=$random(seed);
    threshold_d2=$random(seed);
    for(xx=0;xx<1280;xx=xx+3)begin
     valid=1;x=xx;y=yy;rgb={8'(xx),8'(yy),8'(xx^yy)};hs=0;vs=yy==0;
     @(negedge clk);
    end
    valid=0;hs=1;repeat(4)@(negedge clk);
   end
  end
  valid=0;repeat(4)@(negedge clk);
  if(checked!=440664)$fatal(1,"pixel count %0d",checked);
  $display("PASS F2X shared hex decoder equals frozen r3: 440664 pixel/sync comparisons, all 8 modes and 3 unchanged pages (logo-only page tested separately), arbitrary extra text and randomized diagnostics");$finish;
 end
endmodule
