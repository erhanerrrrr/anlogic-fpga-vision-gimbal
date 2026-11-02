// Metadata belongs to the SAME slot chosen by video_out. Commit is after the
// exact number of RGB128 beats has entered the ordered DDR command queue.
// Stamp starts at ISP-output SOF synchronized into DDR, not optical exposure.
module f_frame_meta #(parameter BEATS=172800,CLOCK_HZ=66666667)(
 input clk,rst_n,write_start,input [1:0] write_slot,
 input write_beat,write_error,input [31:0] tick,
 input read_start,input [1:0] read_slot,
 output reg [1:0] latest_slot,output reg publish,
 output reg [80:0] packet,
 output reg [31:0] capture_count,output reg [15:0] rejected
);
 reg [31:0] ids[0:3],stamps[0:3];
 reg [3:0] valid;
 reg [1:0] active_slot;
 reg [18:0] beats;
 reg writing,bad;
 reg [$clog2(CLOCK_HZ)-1:0] second_counter;
 reg [15:0] fps_count,capture_fps;
 integer i;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
   valid<=0;active_slot<=0;beats<=0;writing<=0;bad<=0;
   latest_slot<=0;publish<=0;packet<=0;capture_count<=0;rejected<=0;
   second_counter<=0;fps_count<=0;capture_fps<=0;
   for(i=0;i<4;i=i+1)begin ids[i]<=0;stamps[i]<=0;end
 end else begin
   publish<=0;
   if(second_counter==CLOCK_HZ-1)begin
     second_counter<=0;capture_fps<=fps_count+write_start;fps_count<=0;
   end else begin
     second_counter<=second_counter+1'b1;
     if(write_start && fps_count!=65535)fps_count<=fps_count+1'b1;
   end
   if(write_start)begin
     if(writing && beats!=BEATS && rejected!=65535)rejected<=rejected+1'b1;
     capture_count<=capture_count+1'b1;
     active_slot<=write_slot;valid[write_slot]<=0;
     ids[write_slot]<=capture_count+1'b1;stamps[write_slot]<=tick;
     beats<=0;writing<=1;bad<=0;
   end else if(writing)begin
     if(write_error)begin bad<=1;valid[active_slot]<=0;end
     if(write_beat && beats<BEATS)begin
       beats<=beats+1'b1;
       if(beats==BEATS-1)begin
         valid[active_slot]<=!bad && !write_error;
         if(!bad && !write_error)latest_slot<=active_slot;
       end
     end else if(write_beat)begin
       valid[active_slot]<=0;bad<=1;
     end
   end
   if(read_start)begin
     publish<=1;
     packet<={capture_fps,valid[read_slot] && !(write_start && write_slot==read_slot),
              ids[read_slot],stamps[read_slot]};
   end
 end
endmodule
