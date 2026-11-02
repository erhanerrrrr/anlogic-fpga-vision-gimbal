// 3-of-4 spatial support, largest area >=8 cells, two fresh-frame
// overlapping candidates. Broad changes (>25% cells) reset confirmation.
// No valid change on the next new frame clears the box immediately.
module f_motion_regions #(parameter WIDTH=1280,HEIGHT=720)(
 input clk,rst_n,frame_start,frame_end,invalidate,
 input sample_valid,hit,input [10:0] x,y,
 input [31:0] source_id,
 output reg [14:0] count,output reg [10:0] x0,x1,y0,y1
);
 localparam GW=(WIDTH+7)/8,GH=(HEIGHT+7)/8;
 reg previous_row[0:GW-1];
 reg left_hit,up_left;
 wire up=(y!=0) && previous_row[x];
 wire l=(x!=0) && left_hit;
 wire ul=(x!=0 && y!=0) && up_left;
 wire supported=hit && ((l && up) || (l && ul) || (up && ul));
 reg [14:0] raw_count;
 reg previous_valid;
 reg [10:0] px0,px1,py0,py1;
 reg ready,cv;
 reg [10:0] ax0,ax1,ay0,ay1;
 wire local_change=ready && cv && raw_count<=GW*GH/4;
 // Association margin: two motion cells in each direction.
 wire nearby=({1'b0,ax0}<={1'b0,px1}+12'd16) &&
             ({1'b0,px0}<={1'b0,ax1}+12'd16) &&
             ({1'b0,ay0}<={1'b0,py1}+12'd16) &&
             ({1'b0,py0}<={1'b0,ay1}+12'd16);
 function [10:0] stable_edge;
 input [10:0] current,previous;
 reg [10:0] distance;
 begin
   distance=current>previous?current-previous:previous-current;
   stable_edge=distance<=8?previous:current;
 end endfunction
 reg sv,sm,ss,se;
 reg [10:0] sx,sy;
 reg [31:0] sid;
 wire done,accepted;
 wire [19:0] area;
 wire [10:0] xmin,xmax,ymin,ymax;
 wire [31:0] rid;
 wire [2:0] reason;
 h4e_region_select #(.WIDTH(GW),.HEIGHT(GH),.MIN_AREA(8)) regions(
 .clk(clk),.rst_n(rst_n),.mask_valid(sv),.mask(sm),.x(sx),.y(sy),.sof(ss),.eof(se),
 .frame_id(sid),.cfg_id(16'd0),.target_id(2'd0),.result_strobe(done),.target_valid(accepted),.reason(reason),
 .result_frame_id(rid),.area(area),.xmin(xmin),.xmax(xmax),.ymin(ymin),.ymax(ymax));
 reg [14:0] ca;
 wire [13:0] right_edge={xmax,3'b111},bottom_edge={ymax,3'b111};
 always @(posedge clk)if(sample_valid)previous_row[x]<=hit;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
   left_hit<=0;up_left<=0;sv<=0;sm<=0;ss<=0;se<=0;sx<=0;sy<=0;sid<=0;
   ready<=0;cv<=0;ca<=0;ax0<=0;ax1<=0;ay0<=0;ay1<=0;
   count<=0;x0<=0;x1<=0;y0<=0;y1<=0;
   raw_count<=0;previous_valid<=0;px0<=0;px1<=0;py0<=0;py1<=0;
 end else begin
   sv<=sample_valid;sm<=supported;ss<=sample_valid && x==0 && y==0;
   se<=sample_valid && x==GW-1 && y==GH-1;sx<=x;sy<=y;sid<=source_id;
   if(sample_valid)begin left_hit<=hit;up_left<=up;end
   if(frame_start)begin ready<=0;raw_count<=0;end
   else if(sample_valid && hit)raw_count<=raw_count+1'b1;
   if(done && rid==source_id && !frame_start && !invalidate)begin
     ready<=1;cv<=accepted;ca<=accepted?area[14:0]:0;
     // Spatial support removes the leading row/column; include their cell.
     ax0<=xmin==0?0:(xmin-11'd1)<<3;ay0<=ymin==0?0:(ymin-11'd1)<<3;
     ax1<=right_edge>=WIDTH?WIDTH-1:right_edge[10:0];
     ay1<=bottom_edge>=HEIGHT?HEIGHT-1:bottom_edge[10:0];
   end
   if(frame_end)begin
     previous_valid<=local_change;
     px0<=ax0;px1<=ax1;py0<=ay0;py1<=ay1;
     if(local_change && previous_valid && nearby)begin
       count<=ca;
       x0<=count!=0?stable_edge(ax0,x0):ax0;x1<=count!=0?stable_edge(ax1,x1):ax1;
       y0<=count!=0?stable_edge(ay0,y0):ay0;y1<=count!=0?stable_edge(ay1,y1):ay1;
     end else begin count<=0;x0<=0;x1<=0;y0<=0;y1<=0;end
   end
   if(invalidate)begin previous_valid<=0;raw_count<=0;ready<=0;count<=0;x0<=0;x1<=0;y0<=0;y1<=0;end
 end
endmodule
