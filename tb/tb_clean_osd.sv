`timescale 1ns/1ps
// Verify the user-visible contract on every pixel, including all OSD regions.
module tb_clean_osd;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,valid=0,vs=0,hs=0;reg [10:0] x=0,y=0;reg [23:0] rgb=0;
 reg [1:0] page=2;
 wire ov,ovs,ohs;wire [23:0] out;
 f_osd dut(.clk(clk),.rst_n(rst),.diagnostics(20'd0),.valid(valid),.vs(vs),.hs(hs),.x(x),.y(y),.rgb(rgb),
 .view_page(page),.source_live(1'b1),.mode(3'd0),.source_ok(1'b1),.source_id(32'd9),.result_id(32'd8),.latency(32'd1234),
 .target_valid(1'b1),.reason(3'd0),.cx(11'd640),.cy(11'd360),.x0(11'd100),.x1(11'd900),.y0(11'd300),.y1(11'd600),
 .area(20'd240000),.object_class(2'd1),.color(2'd0),.state(3'd0),.pan(12'd1500),.tilt(12'd1500),
 .motion(15'd20),.gain(7'd16),.mean(8'd80),.cfg(16'd1),.cal(5'd0),.active_calibrated(1'b0),
 .sample_rgb(24'h0c2014),.sample_pixels(9'd256),.sample_span(8'd4),
 .threshold_main(8'd12),.threshold_d1(8'd3),.threshold_d2(8'd3),
 .source_fps(16'd30),.display_fps(16'd60),.capture_fps(16'd30),.ov(ov),.ovs(ovs),.ohs(ohs),.orgb(out));
 reg [23:0] reference0=0,reference1=0,reference2=0;
 reg [2:0] vpipe=0,hpipe=0,spipe=0;
 integer xx,yy,count=0;
 always @(posedge clk)if(rst)begin
   reference2=reference1;reference1=reference0;reference0=rgb;
   vpipe={vpipe[1:0],valid};hpipe={hpipe[1:0],hs};spipe={spipe[1:0],vs};
   #1;
   if(ov!==vpipe[2] || ohs!==hpipe[2] || ovs!==spipe[2])$fatal(1,"OSD sync latency changed");
   if(page==2 && ov)begin
     if(out!==reference2)$fatal(1,"clean image contaminated by OSD: %h expected %h",out,reference2);
     count=count+1;
   end
 end
 task sample(input [1:0] p,input [10:0] px,py,input [23:0] want);
 begin
   @(negedge clk);page=p;valid=1;x=px;y=py;rgb=24'h2468ac;
   repeat(3)@(negedge clk);
   if(out!==want)$fatal(1,"page %d pixel %d,%d: %h expected %h",p,px,py,out,want);
   valid=0;repeat(3)@(negedge clk);
 end endtask
 task check_line(input [10:0] row,input [511:0] want);
 integer col;
 begin
   page=0;valid=0;y=row;
   for(col=0;col<64;col=col+1)begin
     @(negedge clk);x=16+16*col;
     @(posedge clk);#2;
     if(dut.ch!==want[(63-col)*8+:8])$fatal(1,"diagnostic output row=%0d col=%0d",row,col);
   end
   @(negedge clk);page=2;
 end endtask
 initial begin
   repeat(5)@(negedge clk);rst=1;
   check_line(160,{"LAT 000004D2 RGB 0C 20 14 N 100 SP 04 K3 HEX",160'b0});
   check_line(192,{"MOTION 0014 GAIN Q4 010 MEAN 050 TH 0C 03 03",160'b0});
   for(yy=0;yy<720;yy=yy+1)begin
     for(xx=0;xx<1280;xx=xx+1)begin
       valid=1;x=xx;y=yy;rgb={8'(xx),8'(yy),8'(xx^yy)};hs=0;vs=yy==0;
       @(negedge clk);
     end
     valid=0;hs=1;repeat(6)@(negedge clk);
   end
   repeat(5)@(negedge clk);if(count!=921600)$fatal(1,"clean pixel count %d",count);
   sample(0,28,200,24'h101010); // detailed panel background
   sample(1,28,200,24'h2468ac); // compact releases lower panel area
   sample(1,28,20,24'h101010);  // compact retains top two rows
   sample(0,100,400,24'h00ff00);// target outline remains in detailed view
   sample(1,640,360,24'h00ff00);// target center remains in compact view
   $display("PASS clean OSD: 921600 exact RGB pixels, no text/background/logo/boxes/crosses; both legacy pages and three-cycle sync aligned");$finish;
 end
endmodule
