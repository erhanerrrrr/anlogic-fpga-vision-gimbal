// Associate the most recent CSI frame-start timestamp with an ISP output frame.
// A missing/reused CSI SOF makes the tag invalid rather than inventing a time.
module f_capture_tag(input clk,rst_n,csi_sof,isp_sof,input [31:0] tick,
 output reg send,output reg [64:0] packet);
 reg [31:0] csi_id,used_id,stamp,isp_id;reg seen,prev_csi,prev_isp;
 wire cstart=csi_sof && !prev_csi,istart=isp_sof && !prev_isp;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin csi_id<=0;used_id<=0;stamp<=0;isp_id<=0;seen<=0;prev_csi<=0;prev_isp<=0;send<=0;packet<=0;end
 else begin
   send<=0;prev_csi<=csi_sof;prev_isp<=isp_sof;
   if(cstart)begin csi_id<=csi_id+1'b1;stamp<=tick;seen<=1;end
   if(istart)begin
     isp_id<=isp_id+1'b1;send<=1;
     packet<={cstart || (seen && csi_id!=used_id),isp_id+32'd1,cstart?tick:stamp};
     used_id<=cstart?csi_id+32'd1:csi_id;
   end
 end
endmodule

// Receiver for a registered Gray counter. All bits cross through two stages.
module f_gray_receive(input clk,rst_n,input [31:0] gray,output reg [31:0] tick);
 (* async_reg="true" *) reg [31:0] g1,g2;reg [31:0] decoded;integer i;
 always @*begin decoded[31]=g2[31];for(i=30;i>=0;i=i-1)decoded[i]=decoded[i+1]^g2[i];end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin g1<=0;g2<=0;tick<=0;end else begin g1<=gray;g2<=g1;tick<=decoded;end
endmodule
