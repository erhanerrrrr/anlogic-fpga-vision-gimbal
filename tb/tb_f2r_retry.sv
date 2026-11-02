`timescale 1ns/1ps
module tb_f2r_retry;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,en=1,ok=1,req=0,fs=0,fe=0,sv=0,stable=1;
 reg [10:0] x=0,y=0;reg [7:0] gray=80;reg [31:0] fid=0;
 wire [14:0] count,changes,diff,old_count,old_changes;
 wire [2:0] state,why,old_state;wire learned;
 f_motion_bg #(.WIDTH(128),.HEIGHT(96),.SETTLE_FRAMES(2),.ACQUIRE_LIMIT(48)) dut(
 .clk(clk),.rst_n(rst),.enable(en),.source_ok(ok),.request(req),.frame_start(fs),.frame_end(fe),.camera_stable(stable),
 .sample_valid(sv),.x(x),.y(y),.gray(gray),.source_id(fid),.count(count),.changes(changes),.status(state),
 .learned(learned),.capture_diff(diff),.capture_reason(why));
 f2p_motion_bg_reference #(.WIDTH(128),.HEIGHT(96),.SETTLE_FRAMES(2)) old(
 .clk(clk),.rst_n(rst),.enable(en),.source_ok(ok),.request(req),.frame_start(fs),.frame_end(fe),.camera_stable(stable),
 .sample_valid(sv),.x(x),.y(y),.gray(gray),.source_id(fid),.count(old_count),.changes(old_changes),.status(old_state));
 integer xx,yy,i,cycles=0,events=0,before_events,level;
 always @(negedge clk)if(learned)events=events+1;
 task capture;begin @(negedge clk);req=1;@(negedge clk);req=0;end endtask
 task frame(input integer noise,input integer object,input integer global_light);begin
  @(negedge clk);fid=fid+1;fs=1;@(negedge clk);fs=0;
  for(yy=0;yy<12;yy=yy+1)begin
   for(xx=0;xx<16;xx=xx+1)begin
    x=xx;y=yy;gray=80+global_light;
    if(xx==1 && yy==1)gray=gray+noise;
    if(object!=0 && xx>=8 && xx<12 && yy>=4 && yy<8)gray=gray+object;
    sv=1;@(negedge clk);sv=0;repeat(7)@(negedge clk);
   end
   repeat(800)@(negedge clk);
  end
  repeat(1500)@(negedge clk);fe=1;@(negedge clk);fe=0;repeat(3)@(negedge clk);
 end endtask
 task learn_start;begin capture();repeat(10)frame(0,0,0);if(!dut.verifying)$fatal(1,"verify phase missing");end endtask
 initial begin
  repeat(5)@(negedge clk);rst=1;
  // One isolated cell drifts 9 levels/frame. Frame CHANGE remains zero,
  // but the old zero-raw-count rule repeatedly rejects the empty scene.
  capture();
  for(i=0;i<40;i=i+1)begin
   level=old.verifying?(old.verified==0?18:27):(old.learning && old.captures==7?9:0);
   frame(level,0,0);
   if(old_state==7 && level==27)begin
    if(old_changes!=0)$fatal(1,"reproduction must have CHANGE=0000");cycles=cycles+1;
   end
  end
  if(cycles<3 || state!=2 || events!=1 || count)$fatal(1,"noise loop not fixed/reproduced %0d %0d %0d",cycles,state,events);
  frame(0,70,0);if(state!=3 || count!=15)$fatal(1,"real moving object suppressed");
  repeat(10)begin frame(0,70,0);if(state!=4 || count!=15)$fatal(1,"static target absorbed");end
  frame(0,0,0);if(state!=2 || count)$fatal(1,"removal ghost");
  // A coherent region drifting <12 per frame must still reject capture.
  before_events=events;capture();repeat(9)frame(0,0,0);frame(0,9,0);frame(0,18,0);frame(0,27,0);
  if(state!=7 || why!=1 || diff!=16 || changes!=0 || events!=before_events || count)$fatal(1,"qualified-region capture accepted or diagnostic wrong: %0d/%0d/%0d",state,why,diff);
  // Continuous variation must fail finitely, never force successful capture.
  capture();for(i=0;i<48;i=i+1)frame(0,0,(i%2)*60);
  if(state!=5 || why!=2 || count || events!=before_events)$fatal(1,"bounded capture failed");
  repeat(12)frame(0,0,0);if(state!=5 || events!=before_events)$fatal(1,"failure must latch until K3");
  learn_start();frame(0,0,0);frame(0,0,0);if(state!=2 || events!=before_events+1)$fatal(1,"K3 recovery after timeout");
  // Missing completed region scan cannot be accepted as an empty background.
  learn_start();force dut.ready=0;frame(0,0,0);release dut.ready;
  if(state!=7 || why!=4 || count)$fatal(1,"missing scan accepted");
  capture();stable=0;repeat(48)frame(0,0,0);stable=1;
  if(state!=5 || why!=3)$fatal(1,"camera-unstable acquisition not bounded");
  ok=0;repeat(3)@(negedge clk);if(state!=6)$fatal(1,"source loss override");
  $display("PASS F2R: F2P retry loop reproduced 3x with CHANGE=0000, isolated-noise capture, coherent foreground rejection, finite failure, K3 recovery, missing-scan rejection, camera/source faults, move/still/remove");$finish;
 end
endmodule
