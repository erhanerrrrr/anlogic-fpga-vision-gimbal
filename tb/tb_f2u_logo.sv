`timescale 1ns/1ps
module tb_f2u_logo;
 reg clk=0;always #5 clk=~clk;
 reg [14:0] addr=15'h7fff;wire [24:0] actual,expected;integer i;
 anlogic_logo_rom dut(.I_clk(clk),.I_addr(addr),.O_pixel(actual));
 f2q_logo_reference reference(.I_addr(addr),.O_pixel(expected));
 initial begin
  for(i=0;i<32768;i=i+1)begin
   @(negedge clk);addr=i;repeat(2)@(posedge clk);#1;
   if(actual!==expected)$fatal(1,"logo address %0d: %h != %h",i,actual,expected);
  end
  $display("PASS F2Q lossless logo: all 32768 addresses, all 25 RGB/alpha bits, two-clock ROM contract");$finish;
 end
endmodule
