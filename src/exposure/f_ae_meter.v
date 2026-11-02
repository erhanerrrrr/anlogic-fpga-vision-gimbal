// Measure unmodified RGB before OSD, once per distinct complete source frame.
// A 64 x 32 spatial grid in the central 1024 x 512 ROI gives 2048 samples.
module f_ae_meter #(
 parameter X0=128,Y0=104,NX=64,NY=32,STEP=16,LOG_SAMPLES=11
)(
 input clk,rst_n,valid,sof,eof,source_ok,input [31:0] frame_id,
 input [10:0] x,y,input [23:0] rgb,
 output reg sample,output reg [7:0] mean,output reg [11:0] clipped,near_clip,
 output reg [15:0] rejected
);
 reg active,seen;reg [31:0] last_id;reg [23:0] sum;
 reg [11:0] count,high_count,near_count;
 wire [9:0] luma_sum={2'b0,rgb[23:16]}+{1'b0,rgb[15:8],1'b0}+{2'b0,rgb[7:0]};
 wire pick=valid && active && x>=X0 && x<X0+NX*STEP && y>=Y0 && y<Y0+NY*STEP &&
           ((x-X0)%STEP)==0 && ((y-Y0)%STEP)==0;
 wire high_pixel=rgb[23:16]>=248 || rgb[15:8]>=248 || rgb[7:0]>=248;
 wire near_pixel=rgb[23:16]>=224 || rgb[15:8]>=224 || rgb[7:0]>=224;
 wire [23:0] final_sum=sum+(pick?luma_sum[9:2]:8'd0);
 wire [11:0] final_count=count+pick;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin active<=0;seen<=0;last_id<=0;sum<=0;count<=0;high_count<=0;near_count<=0;sample<=0;mean<=0;clipped<=0;near_clip<=0;rejected<=0;end
 else begin
   sample<=0;
   if(sof)begin
     active<=source_ok && (!seen || frame_id!=last_id);seen<=1;last_id<=frame_id;
     sum<=0;count<=0;high_count<=0;near_count<=0;
   end else begin
     if(pick)begin sum<=final_sum;count<=final_count;high_count<=high_count+high_pixel;near_count<=near_count+near_pixel;end
     if(eof && active)begin
       active<=0;
       if(source_ok && final_count==NX*NY)begin
         mean<=final_sum>>LOG_SAMPLES;clipped<=high_count+(pick && high_pixel);near_clip<=near_count+(pick && near_pixel);sample<=1;
       end else if(rejected!=65535)rejected<=rejected+1'b1;
     end
   end
 end
endmodule
