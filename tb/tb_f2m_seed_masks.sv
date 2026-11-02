`timescale 1ns/1ps
module tb_f2m_seed_masks;
 reg clk=0;always #5 clk=~clk;reg rst=0,v=0;reg [10:0] x=0,y=0;reg [23:0] rgb=0;
 reg [1:0] color=1;reg [7:0] mt=32,d1=12,d2=12;wire strong_bit,weak_bit;
 f_seed_color_mask #(.WIDTH(32)) dut(.clk(clk),.rst_n(rst),.valid(v),.x(x),.y(y),.rgb(rgb),.color(color),
 .min_main(mt),.diff1(d1),.diff2(d2),.strong_mask(strong_bit),.weak_mask(weak_bit));
 integer pixels[0:767];integer f,xx,yy,i,r,g,b,main,other,rel,wm,wd1,wd2,checks=0;
 reg es,ew;reg [31:0] rng=32'h17283;
 function integer channel(input integer p,input integer shift);channel=(p>>shift)&255;endfunction
 function integer mx(input integer a,b);mx=a>b?a:b;endfunction
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(f=0;f<12;f=f+1)begin
   for(yy=0;yy<24;yy=yy+1)begin
    for(xx=0;xx<32;xx=xx+1)begin
     @(negedge clk);rng=rng*1664525+1013904223;rgb=rng[23:0];
     if(f<4)rgb=f==0?24'h132718:f==1?24'h0d1d12:f==2?24'h153240:24'h142532;
     color=f%2?2:1;mt=color==1?32:64;d1=color==1?12:16;d2=d1;
     if(f>=8)begin mt=32+rng[5:0];d1=12+rng[3:0];d2=12+rng[7:4];end
     v=1;x=xx;y=yy;pixels[yy*32+xx]=rgb;es=0;ew=0;
     if(xx>0 && yy>0)begin
      r=0;g=0;b=0;
      for(i=0;i<4;i=i+1)begin
       r=r+channel(pixels[(yy-i/2)*32+xx-i%2],16);
       g=g+channel(pixels[(yy-i/2)*32+xx-i%2],8);
       b=b+channel(pixels[(yy-i/2)*32+xx-i%2],0);
      end
      r=r/4;g=g/4;b=b/4;main=color==1?g:b;other=color==1?b:g;
      rel=color==1?(main+3)/4:(main+7)/8;
      es=main>=mt && main-r>=mx(d1,rel) && main-other>=mx(d2,rel);
      wm=mx(16,mt/2);wd1=mx(6,d1/2);wd2=mx(6,d2/2);rel=(main+7)/8;
      ew=main>=wm && main-r>=mx(wd1,rel) && main-other>=mx(wd2,rel);
     end
     @(posedge clk);#1;if(strong_bit!==es || weak_bit!==ew)$fatal(1,"mask mismatch f%0d %0d/%0d",f,xx,yy);
     if(strong_bit && !weak_bit)$fatal(1,"strong_bit not subset");checks=checks+1;
    end
    @(negedge clk);v=0;repeat(f%4+1)@(negedge clk);
   end
   repeat(7)@(negedge clk);
  end
  $display("PASS F2M %0d independent 2x2 RGB strong_bit/weak_bit comparisons; GREEN/BLUE, variable thresholds, borders/frame stale RAM/blanking",checks);$finish;
 end
endmodule
