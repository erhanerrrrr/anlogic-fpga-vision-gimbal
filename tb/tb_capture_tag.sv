`timescale 1ns/1ps
module tb_capture_tag;
 reg clk=0;always #5 clk=~clk;reg rst=0,csi=0,isp=0;reg [31:0] tick=0;
 wire send;wire [64:0] packet;
 f_capture_tag dut(.clk(clk),.rst_n(rst),.csi_sof(csi),.isp_sof(isp),.tick(tick),.send(send),.packet(packet));
 integer n=0;
 always @(posedge clk)if(send)n=n+1;
 task check(input integer id,input integer stamp,input bit ok);
 begin #1;if(packet!={ok,32'(id),32'(stamp)})$fatal(1,"CSI to ISP tag mismatch %h",packet);end endtask
 initial begin
  repeat(4)@(negedge clk);rst=1;
  tick=123;csi=1;@(negedge clk);csi=0;repeat(9)@(negedge clk);isp=1;@(negedge clk);check(1,123,1);isp=0;
  repeat(3)@(negedge clk);isp=1;@(negedge clk);check(2,123,0);isp=0;
  repeat(3)@(negedge clk);csi=1;isp=1;tick=32'hfffffff0;@(negedge clk);check(3,32'hfffffff0,1);
  repeat(5)@(negedge clk);if(n!=3)$fatal(1,"wide SOF retriggered");
  csi=0;isp=0;@(negedge clk);tick=20;csi=1;@(negedge clk);csi=0;@(negedge clk);isp=1;@(negedge clk);check(4,20,1);
  $display("PASS CSI/ISP frame identity, missing CSI SOF, simultaneous boundaries, wide pulse and timestamp wrap");$finish;
 end
endmodule
