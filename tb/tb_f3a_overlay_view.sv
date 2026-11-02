`timescale 1ns/1ps
module tb_f3a_overlay_view;
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
// Cache the frozen full-color/alpha reference once. Never use DUT ROM data.
 reg [14:0] ref_address=0;
 wire [24:0] reference_logo;
 reg [24:0] golden_logo[0:25599];
 f2q_logo_reference logo_ref(.I_addr(ref_address),.O_pixel(reference_logo));
 wire inside_logo=x>=1104 && x<1264 && y>=16 && y<176;
 wire [24:0] logo=inside_logo?golden_logo[(y-16)*160+x-1104]:25'd0;
 reg [23:0] expected;
 integer dx,dy;
 always @*begin
  expected=rgb;
  if(mode!=6)begin
   // Existing 720p center cross and calibration outline, independent fixtures.
   if((x==640 && y>=352 && y<=368) || (y==360 && x>=632 && x<=648) ||
      ((x==631 || x==648) && y>=351 && y<=368) ||
      ((y==351 || y==368) && x>=631 && x<=648))expected=24'hff00ff;
   dx=$signed({1'b0,x})-$signed({1'b0,cx});dy=$signed({1'b0,y})-$signed({1'b0,cy});
   if(target_valid && (((x==40 || x==1180) && y>=32 && y<=600) ||
       ((y==32 || y==600) && x>=40 && x<=1180) ||
       (dx==0 && dy>=-6 && dy<=6) || (dy==0 && dx>=-6 && dx<=6)))expected=24'h00ff00;
  end
  if(logo[24])expected=logo[23:0];
 end
 reg [23:0] e0=0,e1=0,e2=0;
 reg [2:0] vp=0,hp=0,sp=0;
 integer logo_pixels=0,purple_pixels=0,green_pixels=0,stimuli=0,a;
 always @(posedge clk)if(rst_n)begin
  e2=e1;e1=e0;e0=expected;
  vp={vp[1:0],valid};hp={hp[1:0],hs};sp={sp[1:0],vs};
  if(valid)begin
   stimuli=stimuli+1;
   if(logo[24])logo_pixels=logo_pixels+1;
   if(expected==24'hff00ff)purple_pixels=purple_pixels+1;
   if(expected==24'h00ff00)green_pixels=green_pixels+1;
  end
  #1;
  if({a_ov,a_ohs,a_ovs}!=={vp[2],hp[2],sp[2]})$fatal(1,"overlay sync latency");
  if(a_orgb!==(vp[2]?e2:24'd0))$fatal(1,"overlay pixel mismatch mode=%0d xy=%0d,%0d got=%h expected=%h",mode,x,y,a_orgb,e2);
  if(a_ov)checked=checked+1;
 end
 initial begin
  for(a=0;a<25600;a=a+1)begin ref_address=a;#1;golden_logo[a]=reference_logo;end
  repeat(4)@(negedge clk);rst_n=1;
  view_page=2;x0=40;x1=1180;y0=32;y1=600;
  extra_draw=1;extra_rgb=24'hff9900;extra_line={64{8'h58}};
  for(m=0;m<8;m=m+1)begin
   mode=m;state=m%6;target_valid=m!=0;
   cx=m==7?640:250;cy=m==7?360:200;
   // Full-frame no-target and coincident-center cases. Other modes scan logo,
   // old information-panel area, off-center target and central markers.
   for(yy=0;yy<720;yy=yy+1)if(m==0 || m==7 || yy<180 ||
       (yy>=194 && yy<=206) || (yy>=350 && yy<=370) || yy==600)begin
    for(xx=0;xx<1280;xx=xx+1)begin
     valid=1;x=xx;y=yy;rgb={8'(xx),8'(yy),8'(xx^yy)};hs=0;vs=yy==0;
     @(negedge clk);
    end
    valid=0;hs=1;repeat(4)@(negedge clk);
   end
  end
  valid=0;repeat(4)@(negedge clk);
  if(checked!=stimuli || checked<3000000 || logo_pixels<10000 || purple_pixels<500 || green_pixels<10000)
   $fatal(1,"coverage pixels=%0d/%0d logo=%0d purple=%0d green=%0d",checked,stimuli,logo_pixels,purple_pixels,green_pixels);
  $display("PASS F3A overlay demo: %0d pixels, all 8 modes, frozen RGB/alpha logo, purple center/calibration box, green target box/cross, no information panel or AE graph, exact three-cycle video sync",checked);$finish;
 end
endmodule
