module f_keys #(parameter CLK_HZ=50000000)(
 input clk,rst_n,input [3:0] key_n,input tracking_enabled,
 output [3:0] pressed,output reg enable_event
);
 localparam DIV=CLK_HZ/1000000;
 reg [$clog2(DIV+1)-1:0] div;
 wire tick=div==DIV-1;
 wire [3:0] down;
 reg [19:0] hold_count;
 reg long_sent;
 reg allow_arm;
 genvar i;
 generate for(i=0;i<4;i=i+1)begin:keys
   s1_key_filter f(.clk(clk),.reset(!rst_n),.us_tick(tick),.key_n(key_n[i]),.down(down[i]),.pressed(pressed[i]));
 end endgenerate
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin div<=0;hold_count<=0;long_sent<=0;enable_event<=0;allow_arm<=0;end
 else begin
   enable_event<=0;
   // A press that stopped tracking must never re-arm it while still held.
   if(pressed[3])allow_arm<=!tracking_enabled;
   if(tick)div<=0;else div<=div+1'b1;
   if(!down[3])begin hold_count<=0;long_sent<=0;end
   else if(tick && !long_sent)begin
     if(hold_count==999999)begin enable_event<=allow_arm;long_sent<=1;end
     else hold_count<=hold_count+1'b1;
   end
 end
endmodule
