// One small shared double-dabble engine for eight unsigned decimal fields.
module f_lab_numbers(input clk,rst_n,start,input [159:0] values,output reg [191:0] digits);
 reg [159:0] saved;reg [19:0] binary;reg [23:0] bcd,adjusted;
 reg [4:0] step;reg [2:0] field;reg busy;integer j;
 always @*begin
   adjusted=bcd;
   for(j=0;j<6;j=j+1)if(bcd[j*4+:4]>=5)adjusted[j*4+:4]=bcd[j*4+:4]+4'd3;
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin saved<=0;binary<=0;bcd<=0;step<=0;field<=0;busy<=0;digits<=0;end
 else if(start)begin saved<=values;binary<=values[19:0];bcd<=0;step<=0;field<=0;busy<=1;end
 else if(busy)begin
   bcd<={adjusted[22:0],binary[19]};binary<={binary[18:0],1'b0};step<=step+1'b1;
   if(step==19)begin
     digits[field*24+:24]<={adjusted[22:0],binary[19]};
     if(field==7)busy<=0;
     else begin field<=field+1'b1;binary<=saved[(field+1)*20+:20];bcd<=0;step<=0;end
   end
 end
endmodule
