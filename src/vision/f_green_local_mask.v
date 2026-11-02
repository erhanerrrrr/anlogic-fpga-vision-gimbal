// GREEN-only spatial RGB filtering before thresholding.
// One input register stage, matching the existing RED/BLUE classifier latency.
// Causal 2x2 mean: current, left, above, above-left. No temporal/frame averaging.
// The output is tagged at the current (bottom-right) pixel: a <=1px spatial
// footprint offset at a boundary; first row/column are suppressed, no wrap.
module f_green_local_mask #(parameter WIDTH=1280)(
 input clk,rst_n,valid,input [10:0] x,y,input [23:0] rgb,
 input [7:0] min_main,diff1,diff2,output mask
);
 reg [23:0] line[0:WIDTH-1];
 reg [23:0] above;
 // Synchronous read-before-write. No memory reset, allowing ERAM inference.
 always @(posedge clk)if(rst_n && valid)begin above<=line[x];line[x]<=rgb;end
 reg qvalid;reg [10:0] qx,qy;
 reg [23:0] current,left,above_left;
 reg [7:0] qm,qd1,qd2;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  qvalid<=0;qx<=0;qy<=0;current<=0;left<=0;above_left<=0;qm<=0;qd1<=0;qd2<=0;
 end else begin
  qvalid<=valid;qx<=x;qy<=y;current<=rgb;qm<=min_main;qd1<=diff1;qd2<=diff2;
  if(qvalid)begin left<=current;above_left<=above;end
 end
 wire [9:0] sum_r={2'b0,current[23:16]}+{2'b0,left[23:16]}+{2'b0,above[23:16]}+{2'b0,above_left[23:16]};
 wire [9:0] sum_g={2'b0,current[15:8]}+{2'b0,left[15:8]}+{2'b0,above[15:8]}+{2'b0,above_left[15:8]};
 wire [9:0] sum_b={2'b0,current[7:0]}+{2'b0,left[7:0]}+{2'b0,above[7:0]}+{2'b0,above_left[7:0]};
 wire [7:0] r=sum_r[9:2],g=sum_g[9:2],b=sum_b[9:2];
 wire [8:0] rounded={1'b0,g}+9'd3;
 wire [7:0] relative_floor={1'b0,rounded[8:2]};
 wire [7:0] req1=qd1>relative_floor?qd1:relative_floor;
 wire [7:0] req2=qd2>relative_floor?qd2:relative_floor;
 wire signed [8:0] gr=$signed({1'b0,g})-$signed({1'b0,r});
 wire signed [8:0] gb=$signed({1'b0,g})-$signed({1'b0,b});
 assign mask=qvalid && qx!=0 && qy!=0 && g>=qm &&
             gr>=$signed({1'b0,req1}) && gb>=$signed({1'b0,req2});
endmodule
