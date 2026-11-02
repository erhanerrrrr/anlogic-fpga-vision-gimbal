// bounded per-cell illumination envelope, learned only after explicit K3.
// Store exact low[8] + span[5], rather than two full 8-bit endpoints.
// Ordinary flicker inside the learned range does not restart acquisition or
// classify a stationary foreground as moving. Freeze the model after capture.
module f_motion_bg #(parameter WIDTH=1280,HEIGHT=720,SETTLE_FRAMES=30,LEARN_FRAMES=8,VERIFY_FRAMES=2,ACQUIRE_LIMIT=255)(
 input clk,rst_n,enable,source_ok,request,frame_start,frame_end,camera_stable,
 input sample_valid,input [10:0] x,y,input [7:0] gray,input [31:0] source_id,
 output reg [14:0] count,changes,output reg [2:0] status,
 output reg [10:0] x0,x1,y0,y1,output reg learned,
 output reg [14:0] capture_diff,output reg [2:0] capture_reason
);
 localparam GW=(WIDTH+7)/8,GH=(HEIGHT+7)/8,N=GW*GH;
 localparam QUIET_CELLS=(N/512<1)?1:N/512;
 reg [12:0] background[0:N-1];
 reg [7:0] history[0:N-1];
 reg [12:0] bg;reg [7:0] old,current;
 reg [13:0] qa;wire [13:0] addr=(WIDTH==1280)?({y[6:0],7'b0}+{2'b0,y[6:0],5'b0}+{6'b0,x[7:0]}):(y*GW+x);
 reg qv,ql,qb,qh,qfirst;reg [10:0] qx,qy;reg [31:0] qid;
 reg pending,bg_valid,hist_valid,learning,verifying;
 reg [7:0] acquire_frames;
 reg [5:0] settled;reg [3:0] captures,verified;
 wire [7:0] bg_low=bg[7:0];
 wire [4:0] bg_span=bg[12:8];
 wire [8:0] bg_high={1'b0,bg_low}+{4'b0,bg_span};
 wire [7:0] next_low=current<bg_low?current:bg_low;
 wire [8:0] next_high={1'b0,current}>bg_high?{1'b0,current}:bg_high;
 wire [8:0] next_span=next_high-{1'b0,next_low};
 wire [8:0] diff_bg={1'b0,current}>bg_high?{1'b0,current}-bg_high:
                    current<bg_low?{1'b0,bg_low}-{1'b0,current}:9'd0;
 wire [8:0] diff_old=current>old?current-old:old-current;
 wire foreground=qb && diff_bg>=18;
 wire [8:0] move_threshold=9'd12+(qb?{4'b0,bg_span}:9'd0);
 wire moving=qh && diff_old>=move_threshold;
 // Significant changes still restart capture. Learned range may not exceed 31.
 wire gross_change=qh && diff_old>31;
 reg previous_row[0:GW-1];reg left,up_left;
 wire up=qy!=0 && previous_row[qx];
 wire supported=foreground && ((qx!=0 && left) || up || (qx!=0 && qy!=0 && up_left));
 reg [14:0] raw_count,change_count,gross_count,spread_count;
 reg sv,sm,ss,se;reg [10:0] sx,sy;reg [31:0] sid;
 wire [2:0] region_reason;
 wire done,accepted;wire [19:0] area;wire [10:0] ax,bx,ay,by;wire [31:0] rid;
 reg ready,found;reg [14:0] found_count;reg [10:0] fx0,fx1,fy0,fy1;
 wire verify_bad=!ready || region_reason>=3 || found || raw_count>N/2 || gross_count>QUIET_CELLS;
 h4e_region_select #(.WIDTH(GW),.HEIGHT(GH),.MIN_AREA(8)) regions(
 .clk(clk),.rst_n(rst_n),.mask_valid(sv),.mask(sm),.sof(ss),.eof(se),.x(sx),.y(sy),
 .frame_id(sid),.cfg_id(16'd0),.target_id(2'd0),.result_strobe(done),.target_valid(accepted),
 .reason(region_reason),.result_frame_id(rid),.area(area),.xmin(ax),.xmax(bx),.ymin(ay),.ymax(by));
 always @(posedge clk)begin
  if(sample_valid)begin bg<=background[addr];old<=history[addr];end
  if(qv && enable && source_ok)begin
   history[qa]<=current;
   if(ql)background[qa]<=qfirst?{5'd0,current}:{(next_span>31?5'd31:next_span[4:0]),next_low};
   previous_row[qx]<=foreground;
  end
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  qv<=0;ql<=0;qb<=0;qh<=0;qfirst<=0;qa<=0;qx<=0;qy<=0;qid<=0;current<=0;
  pending<=0;bg_valid<=0;hist_valid<=0;learning<=0;verifying<=0;settled<=0;captures<=0;verified<=0;acquire_frames<=0;capture_diff<=0;capture_reason<=0;
  left<=0;up_left<=0;raw_count<=0;change_count<=0;gross_count<=0;spread_count<=0;
  sv<=0;sm<=0;ss<=0;se<=0;sx<=0;sy<=0;sid<=0;
  ready<=0;found<=0;found_count<=0;fx0<=0;fx1<=0;fy0<=0;fy1<=0;
  count<=0;changes<=0;status<=0;x0<=0;x1<=0;y0<=0;y1<=0;learned<=0;
 end else begin
  learned<=0;
  qv<=sample_valid && enable && source_ok;ql<=learning;qfirst<=captures==0;qb<=bg_valid && !learning;qh<=hist_valid;
  qa<=addr;qx<=x;qy<=y;qid<=source_id;current<=gray;
  sv<=qv && enable && source_ok;sm<=supported;ss<=qv && qx==0 && qy==0;
  se<=qv && qx==GW-1 && qy==GH-1;sx<=qx;sy<=qy;sid<=qid;
  if(qv)begin
   left<=foreground;up_left<=up;
   if(foreground)raw_count<=raw_count+1'b1;
   if(moving)change_count<=change_count+1'b1;
   if(gross_change)gross_count<=gross_count+1'b1;
   if(ql && !qfirst && next_span>31)spread_count<=spread_count+1'b1;
  end
  if(done && rid==source_id)begin
   ready<=1;found<=accepted;found_count<=area[14:0];
   fx0<=ax<<3;fx1<=((bx+1)*8>WIDTH)?WIDTH-1:(bx<<3)+7;
   fy0<=ay<<3;fy1<=((by+1)*8>HEIGHT)?HEIGHT-1:(by<<3)+7;
  end
  if(frame_start)begin
   ready<=0;raw_count<=0;change_count<=0;gross_count<=0;spread_count<=0;
   if(pending && camera_stable)begin
    if(settled<SETTLE_FRAMES)settled<=settled+1'b1;
    else begin pending<=0;learning<=1;captures<=0;status<=1;end
   end
   if(!camera_stable)begin
    settled<=0;bg_valid<=0;count<=0;learning<=0;verifying<=0;
    if(pending || learning || verifying)capture_reason<=3;
    pending<=pending || learning || verifying;
    status<=(pending || learning || verifying)?7:(status==5?5:0);
   end
  end
  if(frame_end)begin
   hist_valid<=1;changes<=change_count;
   if(pending && hist_valid && gross_count>QUIET_CELLS)begin settled<=0;capture_reason<=2;end
   if(learning)begin
    // Material frame changes or excessive range restart all cells
    // on the next full source frame. Never publish a partially captured RAM.
    if((hist_valid && gross_count>QUIET_CELLS) || spread_count>QUIET_CELLS)begin captures<=0;capture_reason<=2;end
    else if(captures==LEARN_FRAMES-1)begin
     learning<=0;bg_valid<=1;verifying<=1;verified<=0;
    end else captures<=captures+1'b1;
   end else if(verifying)begin
    capture_diff<=raw_count;
    // Use the same qualified-region criterion as the normal detector; a
    // single unsupported cell must not repeatedly invalidate an empty scene.
    // Missing/failed CCL results and wide changes still reject capture.
    if(verify_bad)begin
     capture_reason<=!ready || region_reason>=3?4:(gross_count>QUIET_CELLS?2:1);
     bg_valid<=0;verifying<=0;pending<=1;settled<=0;status<=7;
    end else if(verified==VERIFY_FRAMES-1)begin
     verifying<=0;status<=2;learned<=1;capture_reason<=0;
    end else verified<=verified+1'b1;
   end else if(bg_valid && !pending)begin
    if(raw_count>N/2 || gross_count>N/2)begin
     bg_valid<=0;count<=0;status<=5;capture_diff<=raw_count;capture_reason<=2;
    end else if(ready && found)begin
     count<=found_count;x0<=fx0;x1<=fx1;y0<=fy0;y1<=fy1;
     status<=change_count>=4?3:4;
    end else begin count<=0;status<=2;end
   end
  end
  // One finite acquisition budget across settling and all automatic retries.
  // Never accept a bad background to satisfy the timeout; require a fresh K3.
  if(frame_end && (pending || learning || verifying))begin
   if(acquire_frames>=ACQUIRE_LIMIT-1 && !(verifying && verified==VERIFY_FRAMES-1 && !verify_bad))begin
    pending<=0;learning<=0;verifying<=0;bg_valid<=0;count<=0;status<=5;learned<=0;
    if(capture_reason==0 && !verifying)capture_reason<=5;
   end else acquire_frames<=acquire_frames+1'b1;
  end
  // Request has priority over a simultaneous frame boundary. Require a NEW
  // post-button settle interval, even if the camera was stationary beforehand.
  if(request)begin
   pending<=1;settled<=0;bg_valid<=0;hist_valid<=0;learning<=0;verifying<=0;
   captures<=0;verified<=0;count<=0;changes<=0;status<=7;learned<=0;acquire_frames<=0;capture_diff<=0;capture_reason<=0;
  end
  if(!enable || !source_ok)begin
   pending<=0;bg_valid<=0;hist_valid<=0;learning<=0;verifying<=0;settled<=0;captures<=0;verified<=0;acquire_frames<=0;capture_diff<=0;capture_reason<=0;
   qv<=0;sv<=0;count<=0;changes<=0;status<=source_ok?0:6;
  end
 end
endmodule
