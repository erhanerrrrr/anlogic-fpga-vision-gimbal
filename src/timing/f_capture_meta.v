// DDR slot metadata. A frame is publishable only after both its full image and
// its matching capture tag arrive. Handles tag arrival before/after write SOF.
module f_capture_meta #(parameter BEATS=172800,CLOCK_HZ=66666667)(
 input clk,rst_n,write_start,input [1:0] write_slot,input write_beat,write_error,
 input tag_pulse,input [64:0] tag,
 input read_start,input [1:0] read_slot,
 output reg [1:0] latest_slot,output reg publish,output reg [80:0] packet,
 output reg [31:0] capture_count,output reg [15:0] rejected
);
 reg [31:0] ids[0:3],stamps[0:3];reg [3:0] valid;
 reg [1:0] active_slot;reg [18:0] beats;reg writing,bad,stamped;
 reg [64:0] queued_tag;reg queued;
 reg [$clog2(CLOCK_HZ)-1:0] second_counter;reg [15:0] fps_count,capture_fps;
 wire direct_match=tag_pulse && tag[63:32]==capture_count+32'd1;
 wire queued_match=queued && queued_tag[63:32]==capture_count+32'd1;
 wire current_match=tag_pulse && tag[63:32]==ids[active_slot];
 wire current_stamp_ok=current_match?tag[64]:stamped;
 integer i;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
   valid<=0;active_slot<=0;beats<=0;writing<=0;bad<=0;stamped<=0;queued<=0;queued_tag<=0;
   latest_slot<=0;publish<=0;packet<=0;capture_count<=0;rejected<=0;second_counter<=0;fps_count<=0;capture_fps<=0;
   for(i=0;i<4;i=i+1)begin ids[i]<=0;stamps[i]<=0;end
 end else begin
   publish<=0;
   if(tag_pulse)begin queued<=1;queued_tag<=tag;end
   if(second_counter==CLOCK_HZ-1)begin second_counter<=0;capture_fps<=fps_count+write_start;fps_count<=0;end
   else begin second_counter<=second_counter+1'b1;if(write_start && fps_count!=65535)fps_count<=fps_count+1'b1;end
   if(write_start)begin
     if(writing && (beats!=BEATS || bad || !stamped) && rejected!=65535)rejected<=rejected+1'b1;
     capture_count<=capture_count+1'b1;active_slot<=write_slot;valid[write_slot]<=0;
     ids[write_slot]<=capture_count+1'b1;beats<=0;writing<=1;bad<=0;
     stamped<=direct_match?tag[64]:queued_match?queued_tag[64]:1'b0;
     stamps[write_slot]<=direct_match?tag[31:0]:queued_match?queued_tag[31:0]:32'd0;
   end else if(writing)begin
     if(current_match)begin stamped<=tag[64];stamps[active_slot]<=tag[31:0];end
     if(write_error)begin bad<=1;valid[active_slot]<=0;end
     if(write_beat && beats<BEATS)begin
       beats<=beats+1'b1;
       if(beats==BEATS-1)begin
         valid[active_slot]<=!bad && !write_error && current_stamp_ok;
         if(!bad && !write_error && current_stamp_ok)latest_slot<=active_slot;
       end
     end else if(write_beat)begin valid[active_slot]<=0;bad<=1;end
   end
   if(read_start)begin
     publish<=1;packet<={capture_fps,valid[read_slot] && !(write_start && write_slot==read_slot),ids[read_slot],stamps[read_slot]};
   end
 end
endmodule
