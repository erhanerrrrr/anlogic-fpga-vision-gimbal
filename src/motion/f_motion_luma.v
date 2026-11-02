// Mean of the upper-left 4x4 pixels in each 8x8 motion cell.
// Registered output is aligned with input (x%8,y%8)==(3,3).
// Every cell is initialized on its first row: no RAM reset or old-frame data.
module f_motion_luma #(parameter WIDTH=1280)(
 input clk,rst_n,valid,input [10:0] x,y,input [7:0] gray,
 output reg [7:0] mean
);
 localparam GW=(WIDTH+7)/8;
 reg [9:0] horizontal;
 reg [11:0] columns[0:GW-1];
 reg [11:0] above;
 wire [9:0] row_sum=horizontal+{2'b0,gray};
 wire [11:0] block_sum=(y[2:0]==0?12'd0:above)+{2'b0,row_sum};
 always @(posedge clk)begin
   if(valid && x[2:0]==2 && y[2:0]<4)above<=columns[x>>3];
   if(valid && x[2:0]==3 && y[2:0]<4)columns[x>>3]<=block_sum;
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin horizontal<=0;mean<=0;end
 else if(valid)begin
   if(x[2:0]==0)horizontal<={2'b0,gray};
   else if(x[2:0]<4)horizontal<=row_sum;
   if(x[2:0]==3 && y[2:0]==3)mean<=block_sum[11:4];
 end
endmodule
