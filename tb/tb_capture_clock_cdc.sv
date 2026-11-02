`timescale 1ns/1ps
module tb_capture_clock_cdc;
 reg dc=0,cc=0,pc=0;always #7.5 dc=~dc;always #8.333 cc=~cc;always #6.666 pc=~pc;
 reg rst=0,csi=0,isp=0;wire [31:0] tick,ptick,gray,ctick;
 f_gray_time tm(.sclk(dc),.dclk(pc),.rst_n(rst),.tick(tick),.remote_tick(ptick),.gray_tick(gray));
 f_gray_receive rx(.clk(cc),.rst_n(rst),.gray(gray),.tick(ctick));
 wire send,ready,pulse;wire [64:0] packet,received;
 f_capture_tag tagger(.clk(cc),.rst_n(rst),.csi_sof(csi),.isp_sof(isp),.tick(ctick),.send(send),.packet(packet));
 f_cdc #(.W(65)) mailbox(.sclk(cc),.dclk(dc),.rst_n(rst),.send(send),.din(packet),.ready(ready),.pulse(pulse),.dout(received));
 integer n,count=0;reg [31:0] expected_stamp;reg [31:0] prev_c=0,prev_p=0;
 always @(posedge cc)if(rst && tick>20)begin
  if(ctick<prev_c || tick-ctick>6)$fatal(1,"capture Gray time incoherent");prev_c=ctick;
 end
 always @(posedge pc)if(rst && tick>20)begin
  if(ptick<prev_p || tick-ptick>5)$fatal(1,"display Gray time incoherent");prev_p=ptick;
 end
 always @(posedge dc)if(rst && pulse)begin
  count=count+1;
  if(received!={1'b1,32'(count),expected_stamp})$fatal(1,"mailbox timestamp/frame payload");
 end
 initial begin
  repeat(8)@(negedge cc);rst=1;repeat(25)@(negedge cc);
  for(n=0;n<100;n=n+1)begin
   csi=1;expected_stamp=ctick;@(negedge cc);csi=0;
   repeat(53+n%13)@(negedge cc);isp=1;@(negedge cc);isp=0;
   repeat(33)@(negedge cc);
  end
  if(count!=100)$fatal(1,"lost timestamp mailbox");
  $display("PASS 100 capture timestamps across 66.667/60/75 MHz asynchronous domains, bounded Gray lag and exact packet identity");$finish;
 end
endmodule
