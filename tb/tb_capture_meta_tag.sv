`timescale 1ns/1ps
module tb_capture_meta_tag;
 reg clk=0;always #5 clk=~clk;reg rst=0,ws=0,beat=0,err=0,tp=0,rs=0;
 reg [1:0] slot=0,read_slot=0;reg [64:0] tag=0;wire [1:0] latest;wire pub;wire [80:0] packet;
 wire [31:0] count;wire [15:0] rejected;
 f_capture_meta #(.BEATS(4),.CLOCK_HZ(100)) dut(.clk(clk),.rst_n(rst),.write_start(ws),.write_slot(slot),.write_beat(beat),.write_error(err),
 .tag_pulse(tp),.tag(tag),.read_start(rs),.read_slot(read_slot),.latest_slot(latest),.publish(pub),.packet(packet),.capture_count(count),.rejected(rejected));
 task tag_send(input integer id,input integer stamp,input bit ok);
 begin tag={ok,32'(id),32'(stamp)};tp=1;@(negedge clk);tp=0;end endtask
 task start_frame(input integer s);
 begin slot=s;ws=1;@(negedge clk);ws=0;end endtask
 task data_beats(input integer n);
 begin beat=1;repeat(n)@(negedge clk);beat=0;end endtask
 task read_check(input integer s,input integer id,input integer stamp,input bit ok);
 begin read_slot=s;rs=1;@(negedge clk);rs=0;#1;
  if(packet[64]!==ok || packet[63:32]!=id || packet[31:0]!=stamp)$fatal(1,"slot association s=%d packet=%h",s,packet);
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=1;
  tag_send(1,100,1);start_frame(1);data_beats(4);read_check(1,1,100,1);
  if(latest!=1)$fatal(1,"early tag");
  start_frame(2);data_beats(1);tag_send(2,200,1);data_beats(3);read_check(2,2,200,1);
  if(latest!=2)$fatal(1,"late tag");
  start_frame(3);tag_send(2,999,1);data_beats(4);read_check(3,3,0,0);
  if(latest!=2)$fatal(1,"mismatched tag published");
  tag_send(4,400,0);start_frame(0);data_beats(4);read_check(0,4,400,0);
  tag_send(5,500,1);start_frame(1);data_beats(2);
  // Partial frame must not publish even though its timestamp is present.
  read_check(1,5,500,0);if(latest!=2)$fatal(1,"partial publish");
  tag_send(6,600,1);start_frame(3);err=1;data_beats(1);err=0;data_beats(3);read_check(3,6,600,0);
  // A tag on exactly the final beat must be accepted atomically.
  start_frame(0);data_beats(3);beat=1;tag_send(7,700,1);beat=0;read_check(0,7,700,1);
  if(latest!=0 || rejected!=4)$fatal(1,"recovery or rejected count %d",rejected);
  // Reuse the slot: no old timestamp may escape while the new image is incomplete.
  start_frame(0);read_check(0,8,0,0);data_beats(4);if(latest!=0 || dut.valid[0])$fatal(1,"stale slot tag reused");
  $display("PASS capture timestamp/DDR-slot association: early, late, final-beat, missing, invalid, partial, error and slot reuse");$finish;
 end
endmodule
