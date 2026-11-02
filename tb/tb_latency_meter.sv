`timescale 1ns/1ps
module tb_latency_meter;
 reg clk=0;always #5 clk=~clk;reg rst=0,sof=0,ok=1,pause=0,clear=0;
 reg [31:0] id=1,stamp=0,now_tick=0;wire pub;wire [11:0] cur,mn,mx;
 wire [15:0] samples,repeats,invalid;wire [1:0] status;wire [31:0] did;
 f_latency_meter #(.PIXEL_HZ(4000)) dut(.clk(clk),.rst_n(rst),.display_sof(sof),.source_ok(ok),.source_id(id),.capture_tick(stamp),.now_tick(now_tick),
 .pause(pause),.clear(clear),.publish(pub),.current_tenths(cur),.min_tenths(mn),.max_tenths(mx),.samples(samples),.repeats(repeats),.invalid(invalid),.status(status),.displayed_id(did));
 integer n,delta,expected,lo=4095,hi=0,prev_samples;
 task measure(input integer value);
 begin
   @(negedge clk);now_tick=stamp+value;sof=1;@(negedge clk);sof=0;repeat(35)@(negedge clk);
 end endtask
 initial begin
   repeat(4)@(negedge clk);rst=1;
   measure(2000000);if(cur!=300 || mn!=300 || mx!=300 || status!=1)$fatal(1,"30 ms");
   measure(3000000);if(cur!=450 || repeats!=1 || mx!=450 || mn!=300)$fatal(1,"repeated frame age");
   for(n=0;n<100;n=n+1)begin
     id=id+1;stamp=$random;delta=$urandom_range(0,16660000);expected=(delta*3+10000)/20000;
     measure(delta);if(cur!=expected)$fatal(1,"round conversion %d %d",cur,expected);
   end
   stamp=32'hffff0000;id=id+1;measure(2000000);if(cur!=300)$fatal(1,"counter wrap");
   prev_samples=samples;pause=1;id=id+1;measure(1000000);if(samples!=prev_samples || cur!=300)$fatal(1,"pause changed statistics");
   pause=0;ok=0;measure(1000000);if(status!=3 || invalid!=1 || samples!=prev_samples)$fatal(1,"invalid metadata");
   ok=1;id=id+1;measure(20000000);if(status!=3 || invalid!=2)$fatal(1,"outlier accepted");
   id=id+1;measure(1000000);repeat(1100)@(negedge clk);if(status!=2)$fatal(1,"source stale");
   clear=1;@(negedge clk);clear=0;if(samples!=0 || repeats!=0 || invalid!=0 || cur!=0)$fatal(1,"clear");
   id=id+1;measure(6666667);if(cur!=1000 || mn!=1000 || mx!=1000 || samples!=1)$fatal(1,"100 ms after clear");
   $display("PASS latency units/rounding 100 random values, repeated frames, counter wrap, pause, invalid/stale and reset");$finish;
 end
endmodule
