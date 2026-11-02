// Counts display refreshes and distinct VALID source frames separately.
module f_rate #(parameter CLOCK_HZ=75000000)(
 input clk,rst_n,sof,source_ok,input [31:0] source_id,
 output reg [15:0] source_fps,display_fps
);
 reg [$clog2(CLOCK_HZ)-1:0] seconds;
 reg [15:0] sc,dc;
 reg seen;
 reg [31:0] last_id;
 wire fresh=sof && source_ok && (!seen || source_id!=last_id);
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin seconds<=0;sc<=0;dc<=0;seen<=0;last_id<=0;source_fps<=0;display_fps<=0;end
 else begin
   if(fresh)begin seen<=1;last_id<=source_id;end
   if(seconds==CLOCK_HZ-1)begin
     seconds<=0;source_fps<=sc+fresh;display_fps<=dc+sof;sc<=0;dc<=0;
   end else begin
     seconds<=seconds+1'b1;
     if(fresh && sc!=65535)sc<=sc+1'b1;
     if(sof && dc!=65535)dc<=dc+1'b1;
   end
 end
endmodule
