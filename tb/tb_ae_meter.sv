`timescale 1ns/1ps
module tb_ae_meter;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,v=0,sof=0,eof=0,ok=1;reg [31:0] id=1;reg [10:0] x=0,y=0;reg [23:0] rgb=0;
 wire sample;wire [7:0] mean;wire [11:0] clip,near_clip;wire [15:0] rejected;
 f_ae_meter #(.X0(4),.Y0(2),.NX(4),.NY(2),.STEP(2),.LOG_SAMPLES(3)) dut(
 .clk(clk),.rst_n(rst),.valid(v),.sof(sof),.eof(eof),.source_ok(ok),.frame_id(id),.x(x),.y(y),.rgb(rgb),
 .sample(sample),.mean(mean),.clipped(clip),.near_clip(near_clip),.rejected(rejected));
 integer n,xx,yy,reports=0;
 always @(posedge clk)if(sample)reports=reports+1;
 task send_frame(input [23:0] color,input bit partial);
 begin
  @(negedge clk);sof=1;v=1;x=0;y=0;rgb=color;@(negedge clk);sof=0;
  for(yy=0;yy<8;yy=yy+1)for(xx=0;xx<16;xx=xx+1)begin
   x=xx;y=yy;v=!(partial && xx==4 && yy==2);eof=xx==15 && yy==7;@(negedge clk);
  end
  v=0;eof=0;repeat(3)@(negedge clk);
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=1;
  send_frame(24'h507850,0);if(mean!=100 || clip!=0 || reports!=1)$fatal(1,"mean arithmetic");
  send_frame(24'hffffff,0);if(reports!=1)$fatal(1,"duplicate source counted");
  id=2;send_frame(24'hff0000,0);if(mean!=63 || clip!=8 || reports!=2)$fatal(1,"colored highlight detection");
  id=3;send_frame(24'h888888,1);if(reports!=2 || rejected!=1)$fatal(1,"partial ROI accepted");
  id=4;ok=0;send_frame(24'hffffff,0);if(reports!=2)$fatal(1,"invalid metadata accepted");
  id=5;ok=1;send_frame(24'h808080,0);if(mean!=128 || reports!=3)$fatal(1,"recovery");
  id=6;send_frame(24'he80000,0);if(near_clip!=8 || clip!=0)$fatal(1,"preclip margin");
  $display("PASS AE metering independent luma, colored clipping, source deduplication, incomplete scan and recovery");$finish;
 end
endmodule
