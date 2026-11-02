`timescale 1ns/1ps
module tb_f2x_integration;
 reg clk=0;always #5 clk=~clk;reg rst=0,de=0,user=0,k1=0,k2=0,k3=0;
 reg [1:0] page=0;reg [82:0] ae=0;reg [80:0] meta=0;reg [31:0] tick=10000;
 wire hold_req,lock_req,profile_event,hold_event,ov;wire [23:0] rgb;
 f_vision #(.WIDTH(128),.HEIGHT(96),.INTEGRATED(1)) dut(.clk(clk),.rst_n(rst),.vs(1'b0),.hs(1'b0),.de(de),.user(user),.rgb(24'h801010),
 .source_meta(meta),.tick(tick),.mode_event(k1),.color_event(k2),.cal_event(k3),.view_page(page),
 .ae_status(ae),.ae_inhibit(lock_req),.ae_profile_event(profile_event),.ae_hold_event(hold_event),
 .source_live(1'b1),.tracking_state(3'd5),.pan_us(12'd1500),.tilt_us(12'd1500),.diagnostics(20'd0),
 .motion_hold(hold_req),.ode(ov),.orgb(rgb));
 integer xx,yy,f=0,n,cal_count=0,motion_count=0;reg prev_ov=0;
 always @(posedge clk)if(rst)begin
  if(dut.cal_dispatch)cal_count=cal_count+1;
  if(dut.motion_dispatch)motion_count=motion_count+1;
  // Every frame's first HDMI pixel and latency sample must coincide.
  if(dut.hdmi_sof[4] && (!ov || prev_ov))$fatal(1,"latency endpoint misaligned");
  prev_ov<=ov;
 end
 task frame;begin
  f=f+1;meta={16'd60,1'b1,32'(f),32'd1000};
  @(negedge clk);user=1;@(negedge clk);user=0;repeat(8)@(negedge clk);
  for(yy=0;yy<96;yy=yy+1)begin
   for(xx=0;xx<128;xx=xx+1)begin @(negedge clk);de=1;end
   @(negedge clk);de=0;repeat(369)@(negedge clk);
  end
  repeat(1500)@(negedge clk);
 end endtask
 task key(input integer k);begin @(negedge clk);k1=k==1;k2=k==2;k3=k==3;@(negedge clk);k1=0;k2=0;k3=0;end endtask
 initial begin
  repeat(5)@(negedge clk);rst=1;
  key(3);if(!hold_req || !lock_req)$fatal(1,"calibration must request hold immediately");
  frame();if(cal_count!=0)$fatal(1,"calibration started before exposure lock");
  ae[82]=1;frame();frame();if(cal_count!=1)$fatal(1,"delayed calibration was lost or repeated");
  for(n=0;n<6;n=n+1)key(1);ae[82]=0;
  if(!hold_req || !lock_req)$fatal(1,"pending motion hold");frame();key(3);frame();
  if(motion_count!=0)$fatal(1,"background started before exposure lock");
  ae[82]=1;frame();if(motion_count!=1)$fatal(1,"background request lost");
  key(1);frame();if(dut.mode!=7 || hold_req || lock_req)$fatal(1,"exit motion did not restore tracking/exposure");
  k2=1;#1;if(!profile_event || dut.next_color)$fatal(1,"AE key changes color");@(negedge clk);k2=0;
  k3=1;#1;if(!hold_event || dut.normal_cal)$fatal(1,"AE hold triggers calibration");@(negedge clk);k3=0;
  page=3;frame();key(1);key(2);key(3);frame();
  if(!dut.paused || dut.graph_scale!=1 || dut.mode!=7 || cal_count!=1 || motion_count!=1)$fatal(1,"latency controls leaked into mode/calibration");
  if(dut.latency_samples!=0)$fatal(1,"clear while paused");
  page=0;key(1);frame();if(dut.mode!=0)$fatal(1,"return to original");
  $display("PASS F2X integrated calibration/MOTION exposure interlock, delayed K3 routing, AE/latency page keys, HDMI endpoint alignment");$finish;
 end
 initial begin #200000000;$fatal(1,"timeout");end
endmodule
