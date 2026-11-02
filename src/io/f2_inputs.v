// Local controls: all switches/keys synchronize and debounce at 1us enables.
module f2_inputs #(
 parameter CLK_HZ=100000000, DEBOUNCE_US=20000, LONG_US=1000000, EXTENDED_PAGES=0, DEFAULT_PAGE=0
)(
 input clk,rst_n,input [3:0] key_n,sw,input enabled,
 output [3:0] pressed,sw_value,output reg toggle_enable,
 output reg [1:0] page,output reg pan_reverse,tilt_reverse
);
 localparam DIV=CLK_HZ/1000000;
 reg [$clog2(DIV+1)-1:0] div;
 wire tick=div==DIV-1;
 wire [3:0] down,unused;
 reg prev_down,allow_arm,long_sent,page_candidate;
 reg [19:0] held;
 genvar i;
 generate for(i=0;i<4;i=i+1)begin:filters
   s1_key_filter #(.DEBOUNCE_US(DEBOUNCE_US)) k(.clk(clk),.reset(!rst_n),.us_tick(tick),.key_n(key_n[i]),.down(down[i]),.pressed(pressed[i]));
   s1_key_filter #(.DEBOUNCE_US(DEBOUNCE_US)) s(.clk(clk),.reset(!rst_n),.us_tick(tick),.key_n(!sw[i]),.down(sw_value[i]),.pressed(unused[i]));
 end endgenerate
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
   div<=0;prev_down<=0;allow_arm<=0;long_sent<=0;held<=0;
   toggle_enable<=0;page<=DEFAULT_PAGE;page_candidate<=0;pan_reverse<=0;tilt_reverse<=0;
 end else begin
   toggle_enable<=0;prev_down<=down[3];
   if(tick)div<=0;else div<=div+1'b1;
   // Pulse only once even though the controller samples this a cycle later.
   if(enabled && (!sw_value[0] || pressed[3]) && !toggle_enable)toggle_enable<=1;
   if(pressed[3])begin
     allow_arm<=sw_value[0] && !enabled;
     page_candidate<=!sw_value[0] && !enabled;
   end
   if(!sw_value[0])allow_arm<=0;
   if(sw_value[0] || enabled)page_candidate<=0;
   if(!down[3])begin
     held<=0;long_sent<=0;
     if(prev_down && page_candidate && !long_sent && !sw_value[0] && !enabled)page<=page==(EXTENDED_PAGES?3:2)?2'd0:page+2'd1;
     page_candidate<=0;
   end else if(tick && !long_sent)begin
     if(held==LONG_US-1)begin
       long_sent<=1;
       if(allow_arm && sw_value[0] && !enabled)begin
         toggle_enable<=1;pan_reverse<=sw_value[2];tilt_reverse<=sw_value[3];
       end
     end else held<=held+1'b1;
   end
 end
endmodule
