`timescale 1ns/1ps
module tb_f3a_motion_overlay;
 reg clk=0;always #5 clk=~clk;reg rst=0,de=0,user=0,mode_key=0,k3=0;
 reg [23:0] rgb=0;reg [80:0] meta=0;reg [1:0] page=2;
 wire hold_request,send;wire [71:0] packet;wire [63:0] info;wire ov;wire [23:0] out;
 f_vision #(.WIDTH(128),.HEIGHT(96),.INTEGRATED(1)) dut(.clk(clk),.rst_n(rst),.vs(1'b0),.hs(1'b0),.de(de),.user(user),.rgb(rgb),
 .source_meta(meta),.tick(32'd1000),.mode_event(mode_key),.color_event(1'b0),.cal_event(k3),.view_page(page),
 .source_live(1'b1),.tracking_state(3'd5),.pan_us(12'd1500),.tilt_us(12'd1500),.diagnostics(20'd0),
 .ae_status({1'b1,82'd0}),.motion_hold(hold_request),.result_send(send),.result_packet(packet),.result_info(info),.ode(ov),.orgb(out));
 // Simulation-only reduction of the already-verified settling duration.
 defparam dut.image_path.motion_regions.SETTLE_FRAMES=3;
 integer f=0,xx,yy,i,yellow=0,tries;
 always @(posedge clk)begin #1;if(ov && out==24'hffff00)yellow=yellow+1;end
 task frame(input integer kind);begin
  f=f+1;meta={16'd60,1'b1,32'(f),32'd0};yellow=0;
  for(yy=0;yy<96;yy=yy+1)begin
   for(xx=0;xx<128;xx=xx+1)begin
    @(negedge clk);de=1;user=xx==0&&yy==0;rgb=24'h141414;
    if(kind==1 && xx>=32 && xx<72 && yy>=32 && yy<72)rgb=24'h969696;
    if(kind==2)rgb=24'h969696;
   end
   @(negedge clk);de=0;user=0;repeat(369)@(negedge clk);
  end
  repeat(1500)@(negedge clk);
 end endtask
 task key;begin @(negedge clk);k3=1;@(negedge clk);k3=0;end endtask
 task empty_capture;begin
  key();tries=0;
  while(dut.motion_status!=2 && tries<60)begin frame(0);tries=tries+1;end
  if(dut.motion_status!=2 || tries<12)$fatal(1,"post-K3 wait/learn/verify %d",tries);
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(i=0;i<6;i=i+1)begin mode_key=1;@(negedge clk);mode_key=0;@(negedge clk);end
  if(!hold_request)$fatal(1,"pending MOTION must request hold");
  for(i=0;i<3;i=i+1)frame(0);
  if(dut.mode!=6 || dut.motion_status!=0)$fatal(1,"entry state");
  empty_capture();if(dut.motion_status!=2 || dut.cfg!=1 || dut.active_calibrated)$fatal(1,"K3 must learn background, not color");
  if(yellow!=0)$fatal(1,"empty background has a yellow box");
  frame(1);if(dut.motion_status!=3 || dut.motion<20)$fatal(1,"pipeline foreground missing");
  // Demo page exposes the complete scene, including foreground in the former text area.
  if(dut.image_path.motion_regions.x0!=32 || dut.image_path.motion_regions.x1!=71)$fatal(1,"pipeline region geometry");
  frame(1);if(dut.motion_status!=4)$fatal(1,"stationary status");
  if(yellow<100)$fatal(1,"MOTION yellow box hidden on demo page: %0d",yellow);
  frame(0);if(dut.motion)$fatal(1,"removed ghost");
  frame(0);if(yellow!=0)$fatal(1,"yellow display ghost after removal");
  frame(2);if(dut.motion_status!=5)$fatal(1,"scene change");
  empty_capture();frame(1);if(!dut.motion)$fatal(1,"recovery");
  frame(1);if(yellow<100)$fatal(1,"yellow overlay missing after recapture");
  mode_key=1;@(negedge clk);mode_key=0;frame(0);if(hold_request || dut.mode!=7)$fatal(1,"leaving mode must release hold");
  $display("PASS F3A integrated demo MOTION: K3 background capture, clear/moving/still/removal/global/recovery, real yellow output pixels inside former information-panel area, no yellow residual after removal, unchanged hold/mode exit");$finish;
 end
endmodule
