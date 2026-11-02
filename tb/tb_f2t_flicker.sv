`timescale 1ns/1ps
module tb_f2t_flicker;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,en=1,ok=1,req=0,fs=0,fe=0,sv=0,stable=1;
 reg [10:0] x=0,y=0;reg [7:0] gray=0;reg [31:0] fid=0;
 wire [14:0] count,changes,diff,old_count,old_changes,old_diff;
 wire [2:0] state,why,old_state,old_why;wire learned;
 f_motion_bg #(.WIDTH(128),.HEIGHT(96),.SETTLE_FRAMES(2),.ACQUIRE_LIMIT(64)) dut(
 .clk(clk),.rst_n(rst),.enable(en),.source_ok(ok),.request(req),.frame_start(fs),.frame_end(fe),.camera_stable(stable),
 .sample_valid(sv),.x(x),.y(y),.gray(gray),.source_id(fid),.count(count),.changes(changes),.status(state),
 .learned(learned),.capture_diff(diff),.capture_reason(why));
 f2s_motion_bg_reference #(.WIDTH(128),.HEIGHT(96),.SETTLE_FRAMES(2),.ACQUIRE_LIMIT(64)) old(
 .clk(clk),.rst_n(rst),.enable(en),.source_ok(ok),.request(req),.frame_start(fs),.frame_end(fe),.camera_stable(stable),
 .sample_valid(sv),.x(x),.y(y),.gray(gray),.source_id(fid),.count(old_count),.changes(old_changes),.status(old_state),
 .capture_diff(old_diff),.capture_reason(old_why));
 integer xx,yy,i,j,g,events=0,base;
 always @(negedge clk)if(learned)events=events+1;
 task capture;begin @(negedge clk);req=1;@(negedge clk);req=0;end endtask
 task frame(input integer light,input integer global_light,input integer object);begin
  @(negedge clk);fid=fid+1;fs=1;@(negedge clk);fs=0;
  for(yy=0;yy<12;yy=yy+1)begin
   for(xx=0;xx<16;xx=xx+1)begin
    x=xx;y=yy;gray=40+2*xx+yy;
    if(global_light || (xx<7 && yy<7))gray=gray+light;
    if(object && xx>=8 && xx<12 && yy>=4 && yy<8)gray=220;
    sv=1;@(negedge clk);sv=0;repeat(7)@(negedge clk);
   end
   repeat(800)@(negedge clk);
  end
  repeat(1500)@(negedge clk);fe=1;@(negedge clk);fe=0;repeat(3)@(negedge clk);
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=1;
  // Same coherent low-amplitude corner variations: the old average lags the
  // learned range and rejects with REGION, although adjacent-frame CHANGE=0.
  capture();frame(24,0,0);frame(24,0,0);
  frame(24,0,0);frame(18,0,0);frame(12,0,0);frame(6,0,0);
  repeat(4)frame(0,0,0);frame(10,0,0);frame(20,0,0);
  if(old_state!=7 || old_why!=1 || old_changes!=0 || old_diff!=49)
   $fatal(1,"F2S REGION reproduction %0d %0d %0d %0d",old_state,old_why,old_changes,old_diff);
  if(state!=2 || count || events!=1)$fatal(1,"local flicker capture failed");
  // Independently check every packed cell: exact minimum and bounded span.
  for(yy=0;yy<12;yy=yy+1)for(xx=0;xx<16;xx=xx+1)begin
   base=40+2*xx+yy;
   if(dut.background[yy*16+xx]!=={5'((xx<7&&yy<7)?24:0),8'(base)})
    $fatal(1,"packed envelope mismatch %0d,%0d",xx,yy);
  end
  repeat(10)begin frame(0,0,0);frame(24,0,0);if(state!=2 || count || changes)$fatal(1,"local flicker ghost");end
  for(g=0;g<2;g=g+1)begin
   // All-frame 24-level flicker used to block settling forever. It is
   // measured during acquisition and then excluded from motion classification.
   capture();frame(0,g,0);frame(0,g,0);
   for(i=0;i<8;i=i+1)frame((i%2)*24,g,0);
   frame(0,g,0);frame(24,g,0);
   if(state!=2 || count)$fatal(1,"flicker acquisition %0d",g);
   for(i=0;i<12;i=i+1)begin frame((i%2)*24,g,0);if(state!=2 || count || changes)$fatal(1,"empty flicker ghost %0d",g);end
   frame(0,g,1);if(state!=3 || count!=15)$fatal(1,"real object suppressed %0d %0d",state,count);
   for(i=0;i<20;i=i+1)begin frame((i%2)*24,g,1);if(state!=4 || count!=15)$fatal(1,"stationary object flicker/absorption %0d %0d",state,count);end
   frame(0,g,0);if(state!=2 || count)$fatal(1,"removal ghost");
  end
  // Slow unbounded drift exceeds the range cap even without >=32 frame jumps.
  capture();frame(0,1,0);frame(0,1,0);
  for(i=0;i<8;i=i+1)frame(i*6,1,0);
  if(dut.verifying || state==2 || why!=2)$fatal(1,"excessive spread accepted");
  // Broad severe flicker must fail finitely; no forced background acceptance.
  capture();for(i=0;i<64;i=i+1)frame((i%2)*60,1,0);
  if(state!=5 || why!=2 || count)$fatal(1,"severe change not bounded");
  repeat(3)frame(0,1,0);if(state!=5)$fatal(1,"timeout not latched");
  capture();repeat(12)frame(0,1,0);if(state!=2)$fatal(1,"K3 recovery");
  frame(100,1,0);if(state!=5)$fatal(1,"large scene change must invalidate");
  $display("PASS F2T paired F2S REGION/CHANGE=0 reproduction; all 192 packed cells; local/global 24-level flicker capture and no false box; move/still/remove under flicker; bounded range, severe-change rejection and K3 recovery");$finish;
 end
endmodule
