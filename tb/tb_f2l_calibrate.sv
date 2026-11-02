`timescale 1ns/1ps
module tb_f2l_calibrate;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,v=0,s=0,e=0,req=0,next_color=0;reg [10:0] x=0,y=0;reg [23:0] rgb=24'h1e6414;
 reg [31:0] id=1;wire [1:0] color;wire [7:0] main_t,d1,d2;wire [15:0] cfg;wire busy,ok;wire [2:0] reason;
 wire [23:0] sampled;wire [8:0] pixels;wire [7:0] span;wire calibrated;
 f_calibrate #(.WIDTH(32),.HEIGHT(24)) dut(clk,rst,v,s,e,x,y,rgb,id,req,next_color,color,main_t,d1,d2,cfg,busy,ok,reason,,sampled,pixels,span,calibrated);
 integer xx,yy;reg [1:0] varied=0;
 task frame;
 begin
  for(yy=0;yy<24;yy=yy+1)begin
   for(xx=0;xx<32;xx=xx+1)begin
    @(negedge clk);v=1;s=xx==0&&yy==0;e=xx==31&&yy==23;x=xx;y=yy;
    if(varied==1)rgb=xx[0]?24'h0c8014:24'h0c5014;
    else if(varied==2)rgb=xx[0]?24'h203d28:24'h14311c;
   end
   @(negedge clk);v=0;s=0;e=0;repeat(4)@(negedge clk);
  end
  repeat(10)@(negedge clk);
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=1;
  if(main_t!=24 || d1!=16 || d2!=16)$fatal(1,"H4E defaults lost");
  req=1;@(negedge clk);req=0;frame();
  if(!ok || !busy || cfg!=1 || color!=0)$fatal(1,"premature commit");
  frame();if(cfg!=1)$fatal(1,"duplicate committed config");
  id=2;frame();if(cfg!=2 || color!=1 || main_t!=50 || d1!=35 || d2!=40)$fatal(1,"calibration %d %d %d %d",color,main_t,d1,d2);
  if(sampled!=rgb || pixels!=256 || span!=0)$fatal(1,"sample diagnostic");
  rgb=24'hffffff;req=1;@(negedge clk);req=0;id=3;frame();
  if(ok || busy || cfg!=2 || reason==0)$fatal(1,"invalid calibration accepted");
  next_color=1;@(negedge clk);next_color=0;id=4;frame();
  if(color!=2 || cfg!=3 || main_t!=64 || d1!=16 || d2!=16)$fatal(1,"manual blue preset");
  rgb=24'h519d67;req=1;@(negedge clk);req=0;id=5;frame();
  if(!ok || !busy || cfg!=3 || sampled!=rgb)$fatal(1,"measured green sample");
  frame();if(cfg!=3)$fatal(1,"duplicate source applied dim calibration");
  id=6;frame();if(cfg!=4 || color!=1 || main_t!=78 || d1!=38 || d2!=27)$fatal(1,"measured green calibration");
  rgb=24'h204080;req=1;@(negedge clk);req=0;id=7;frame();
  id=8;frame();if(cfg!=5 || color!=2 || main_t!=64 || d1!=48 || d2!=32)$fatal(1,"blue calibration floor");
  rgb=24'h636562;req=1;@(negedge clk);req=0;id=9;frame();
  if(ok || reason!=5 || cfg!=5 || sampled!=rgb || pixels!=256)$fatal(1,"near-neutral reject/diagnostic");
  rgb=24'h010f02;req=1;@(negedge clk);req=0;id=10;frame();
  if(ok || reason!=3 || cfg!=5)$fatal(1,"too dark accepted");
  rgb=24'hf0e0e0;req=1;@(negedge clk);req=0;id=11;frame();
  if(ok || reason!=3 || cfg!=5)$fatal(1,"clipped sample accepted");
  next_color=1;@(negedge clk);next_color=0;id=12;frame();
  if(color!=0 || cfg!=6 || main_t!=24 || d1!=16 || d2!=16)$fatal(1,"red preset changed");
  rgb=24'hc02010;req=1;@(negedge clk);req=0;id=13;frame();id=14;frame();
  if(!ok || color!=0 || cfg!=7 || main_t!=160 || d1!=128 || d2!=144)$fatal(1,"red calibration changed");
  varied=1;req=1;@(negedge clk);req=0;id=15;frame();
  if(ok || reason!=4 || cfg!=7 || sampled!=24'h0c6814 || pixels!=256 || span!=48)$fatal(1,"nonuniform sample diagnostics/rejection");
  varied=0;rgb=24'h0c1420;req=1;@(negedge clk);req=0;id=16;frame();
  if(ok || reason!=3 || cfg!=7 || !calibrated)$fatal(1,"dim blue bypassed floor or lost previous configuration source");
  rgb=24'h204080;req=1;@(negedge clk);req=0;id=17;frame();id=18;frame();
  if(!ok || !calibrated || cfg!=8 || color!=2 || main_t!=64 || d1!=48 || d2!=32)$fatal(1,"blue calibration floor/source");
  next_color=1;@(negedge clk);next_color=0;id=19;frame();
  if(calibrated || cfg!=9 || color!=0 || !ok)$fatal(1,"PRESET source must be independent from retained CAL status");
  next_color=1;@(negedge clk);next_color=0;id=20;frame();
  if(calibrated || color!=1 || main_t!=32 || d1!=12 || d2!=12)$fatal(1,"green preset floor/restoration");
  next_color=1;@(negedge clk);next_color=0;id=21;frame();
  if(calibrated || color!=2 || cfg!=11 || main_t!=64 || d1!=16 || d2!=16)$fatal(1,"blue preset restoration");
  rgb=24'h4fb2ee;req=1;@(negedge clk);req=0;id=22;frame();
  if(ok || reason!=3 || cfg!=11 || calibrated || sampled!=rgb)$fatal(1,"measured bright-blue mean must retain upper-limit rejection and diagnostic");
  rgb=24'h1a1b1b;req=1;@(negedge clk);req=0;id=23;frame();
  if(ok || reason!=3 || cfg!=11 || calibrated || sampled!=rgb)$fatal(1,"measured neutral background mean rejection");
  rgb=24'h323740;req=1;@(negedge clk);req=0;id=24;frame();
  if(ok || reason!=5 || cfg!=11)$fatal(1,"weak blue cannot generate self-rejecting thresholds");
  rgb=24'h0e271d;req=1;@(negedge clk);req=0;id=25;frame();
  if(ok || reason!=5 || cfg!=11 || calibrated || sampled!=rgb)$fatal(1,"old dim-green object must be explicitly rejected, not weaken preset");
  rgb=24'h648064;req=1;@(negedge clk);req=0;id=26;frame();
  if(ok || reason!=5 || cfg!=11)$fatal(1,"weak green cannot bypass relative dominance");
  varied=2;req=1;@(negedge clk);req=0;id=27;frame();
  if(!ok || !busy || cfg!=11 || sampled!=24'h1a3722 || pixels!=256 || span!=12)$fatal(1,"F2L measured lowlight sample rejected/misreported");
  frame();if(cfg!=11)$fatal(1,"duplicate source prematurely committed lowlight calibration");
  id=28;frame();
  if(!ok || !calibrated || cfg!=12 || color!=1 || main_t!=32 || d1!=14 || d2!=12)$fatal(1,"F2L lowlight parameters not committed");
  varied=0;rgb=24'h2a372c;req=1;@(negedge clk);req=0;id=29;frame();
  if(ok || reason!=5 || cfg!=12 || !calibrated || main_t!=32)$fatal(1,"weak lowlight calibration must fail and retain last good config");
  $display("PASS calibration: F2L measured RGB26/55/34 SP12 accepted, atomic commit and failed-sample retention; preserved red/blue, measured green and dim/weak rejection, blue floor and preset restoration, measured means, neutral/dark/bright/nonuniform rejection, retained diagnostic vs PRESET/CALIB source, atomic fresh-SOF commit");$finish;
 end
endmodule
