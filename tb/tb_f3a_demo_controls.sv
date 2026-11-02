`timescale 1ns/1ps
module tb_f3a_demo_controls;
 reg clk=0,cclk=0;always #5 clk=~clk;always #7 cclk=~cclk;
 reg rst=0;reg [3:0] keys=15,sw=0;
 wire enabled,toggle;wire [3:0] pressed,sv;wire [1:0] page,pixel_page;
 wire page_ready;wire [11:0] pan,tilt;wire [2:0] state;wire pp,tp;
 f2_inputs #(.CLK_HZ(1000000),.DEBOUNCE_US(3),.LONG_US(100),.EXTENDED_PAGES(1),.DEFAULT_PAGE(2)) inputs(
 .clk(cclk),.rst_n(rst),.key_n(keys),.sw(sw),.enabled(enabled),.pressed(pressed),.sw_value(sv),
 .toggle_enable(toggle),.page(page));
 f_cdc #(.W(2)) pages(.sclk(cclk),.dclk(clk),.rst_n(rst),.send(page_ready),.din(page),.ready(page_ready),.dout(pixel_page));
 reg de=0,user=0;reg [23:0] rgb=0;reg [80:0] meta=0;
 wire [1:0] send,hold_req;wire [71:0] packet[0:1];
 genvar g;
 generate for(g=0;g<2;g=g+1)begin:v
 f_vision #(.WIDTH(128),.HEIGHT(96),.INTEGRATED(1)) vision(
 .clk(clk),.rst_n(rst),.vs(1'b0),.hs(1'b0),.de(de),.user(user),.rgb(rgb),.source_meta(meta),.tick(32'd1000),
 .view_page(g==0?pixel_page:2'd0),.source_live(1'b1),.mode_event(1'b0),.color_event(1'b0),.cal_event(1'b0),
 .tracking_state(state),.pan_us(pan),.tilt_us(tilt),.diagnostics(20'd0),.ae_status({1'b1,82'd0}),
 .motion_hold(hold_req[g]),.result_send(send[g]),.result_packet(packet[g]));
 end endgenerate
 wire pulse,ready;wire [71:0] cp;
 f_cdc #(.W(72)) result_cdc(.sclk(clk),.dclk(cclk),.rst_n(rst),.send(send[0]),.din(packet[0]),.ready(ready),.pulse(pulse),.dout(cp));
 reg mh1=0,mh2=0;
 always @(posedge cclk)if(!rst)begin mh1<=0;mh2<=0;end else begin mh1<=hold_req[0];mh2<=mh1;end
 f_control #(.CLK_HZ(1000000),.HOLD_ENABLE(1),.CENTER_X(64),.CENTER_Y(48),
 .PAN_MIN_US(1000),.PAN_MAX_US(2000),.TILT_MIN_US(1200),.TILT_MAX_US(1800)) control(
 .clk(cclk),.rst_n(rst),.toggle_enable(toggle),.recenter(1'b0),.hold_request(mh2),
 .result_strobe(pulse),.source_ok(cp[71]),.target_valid(cp[70] && !mh2),.source_id(cp[69:38]),.cfg_id(cp[37:22]),
 .cx(cp[21:11]),.cy(cp[10:0]),.pan_us(pan),.tilt_us(tilt),.state(state),.enabled(enabled),.pan_pwm(pp),.tilt_pwm(tp));
 integer packets=0,pulses=0,id=0,x,y,n,p,oldp,oldt,before_pulses;
 always @(posedge pp)pulses=pulses+1;
 always @(posedge clk)if(rst)begin
  #1;
  if({send[0],packet[0],hold_req[0]}!=={send[1],packet[1],hold_req[1]})$fatal(1,"page altered control packet or hold request");
  if(send[0])begin
   packets=packets+1;
   if(!packet[0][70] || packet[0][21:11]<95 || packet[0][10:0]<72)$fatal(1,"synthetic target not detected");
  end
 end
 task cycles(input integer n);repeat(n)@(negedge cclk);endtask
 task press4(input integer n);begin keys[3]=0;cycles(n);keys[3]=1;cycles(20);end endtask
 task frame;begin
  id=id+1;meta={16'd60,1'b1,32'(id),32'd0};
  @(negedge clk);user=1;@(negedge clk);user=0;repeat(8)@(negedge clk);
  for(y=0;y<96;y=y+1)begin
   for(x=0;x<128;x=x+1)begin
    @(negedge clk);de=1;rgb=(x>=80 && x<125 && y>=58 && y<94)?24'hc02010:24'h101010;
   end
   @(negedge clk);de=0;repeat(120)@(negedge clk);
  end
  repeat(1500)@(negedge clk);
 end endtask
 initial begin
  cycles(5);rst=1;cycles(30);
  if(page!=2 || enabled || pp || tp)$fatal(1,"power-up must be overlay demo and OFF");
  // No fresh arming gesture: granting permission while K4 is held stays OFF.
  keys[3]=0;cycles(20);sw=1;cycles(150);
  if(enabled)$fatal(1,"held K4 bypassed fresh press");keys[3]=1;cycles(20);
  for(p=0;p<4;p=p+1)begin
   if(page!=(p+2)%4)$fatal(1,"page order");
   sw=1;cycles(30);press4(150);
   if(!enabled || page!=(p+2)%4)$fatal(1,"cannot arm on selected page");
   oldp=pan;oldt=tilt;before_pulses=pulses;
   for(n=0;n<12;n=n+1)frame();
   if(state!=2 || pan<=oldp || tilt<=oldt || pulses<=before_pulses)$fatal(1,"tracking/PWM absent page=%0d pan=%0d/%0d tilt=%0d/%0d state=%0d",page,oldp,pan,oldt,tilt,state);
   if(pixel_page!=page || v[0].vision.display_page!=page)$fatal(1,"selected page lost in CDC or on enable");
   // A long stopping press remains a stop; it never changes page or re-arms.
   press4(180);if(enabled || pp || tp || page!=(p+2)%4)$fatal(1,"stop priority/page retention");
   press4(150);if(!enabled)$fatal(1,"restart on current page");
   sw=0;cycles(30);if(enabled || pp || tp)$fatal(1,"SW1 stop");
   sw=1;cycles(150);if(enabled)$fatal(1,"permission automatically armed");
   sw=0;cycles(30);press4(25);
  end
  if(page!=2 || packets!=48)$fatal(1,"page wrap or frame coverage");
  $display("PASS F3A all-page arming: default overlay demo OFF, real debounced keys + page/result CDC + color/CCL + dual PWM, 48 frames cycle-exact control vs detailed page, preserved page, K4/SW1 stop and no accidental rearm");$finish;
 end
 initial begin #50000000;$fatal(1,"timeout");end
endmodule
