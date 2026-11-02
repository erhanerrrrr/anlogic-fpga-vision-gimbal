`timescale 1ns/1ps
module tb_f2n_panel;
 reg clk=0;always #5 clk=~clk;reg rst=0,motion=0,strobe=0;reg [31:0] fid=0;
 reg [2:0] status=7;reg [14:0] area=0;wire [3:0] led;
 f2_panel #(.CLK_HZ(1000000),.DEMO_MODE(1)) panel(.clk(clk),.rst_n(rst),.dual_mode(1'b0),.page(1'b0),.enabled(1'b1),.state(3'd5),
 .motion_mode(motion),.motion_status(status),.motion_area(area),.result_strobe(strobe),.source_ok(1'b1),.target_valid(1'b0),
 .source_id(fid),.cx(11'd0),.cy(11'd0),.pan_us(12'd1500),.tilt_us(12'd1500),.cal_event(1'b0),.cal_ok(1'b0),.led(led));
 reg [10:0] y=32,x=16;
 f_osd osd(.clk(clk),.rst_n(rst),.valid(1'b1),.vs(1'b0),.hs(1'b0),.x(x),.y(y),.rgb(24'd0),.view_page(2'd0),
 .motion_capture_diff(15'd1),.motion_capture_reason(3'd1),.mode(3'd6),.motion_status(status),.motion_changes(15'd7),.motion(area),.pan(12'd1500),.tilt(12'd1500),.target_valid(1'b1));
 task check_line(input [10:0] row,input [511:0] want);
 integer col;
 begin
   y=row;
   for(col=0;col<64;col=col+1)begin
     @(negedge clk);x=16+16*col;
     @(posedge clk);#2;
     if(osd.ch!==want[(63-col)*8+:8])$fatal(1,"MOTION output row=%0d col=%0d",row,col);
   end
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=1;motion=1;status=0;fid=1;strobe=1;@(negedge clk);strobe=0;
  repeat(1200)@(negedge clk);
  if(panel.digits!=32'h00000000 || led[2])$fatal(1,"waiting panel");
  check_line(32,{"MOTION K3 SET EMPTY BG  FIX CAMERA K3 EMPTY BG",144'b0});
  status=3;area=299;repeat(1200)@(negedge clk);
  if(panel.digits!=32'h02990003 || !led[2] || panel.sound_ms==0)$fatal(1,"motion panel/tone");
  if(panel.red_on!=8'hff || panel.green_on!=0)$fatal(1,"moving must select eight board RED lamps");
  check_line(64,{"FOREGROUND 012B CHANGE 0007 CELLS HEX",216'b0});
  status=4;repeat(85000)@(negedge clk);if(panel.sound_ms!=0)$fatal(1,"stationary foreground repeats sound");
  if(panel.red_on!=8'h0f || panel.green_on!=0)$fatal(1,"still must select four board RED lamps");
  check_line(96,{"CAMERA HOLD PAN 5DC TILT 5DC US HEX",232'b0});
  check_line(192,{"BG DIFF 0001 RETRY REGION   K3 EMPTY",224'b0});
  status=5;area=0;repeat(1200)@(negedge clk);if(led[2])$fatal(1,"scene invalid LED");
  motion=0;repeat(1200)@(negedge clk);if(panel.digits!=32'h15001500)$fatal(1,"normal display restore");
  $display("PASS F2N panel/OSD: background prompts aligned, foreground count/status digits, presence LED and single event sound, normal page restore");$finish;
 end
endmodule
