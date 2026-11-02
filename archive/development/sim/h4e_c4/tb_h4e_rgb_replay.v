`timescale 1ns/1ps
module tb_h4e_rgb_replay;
parameter W=64,H=48;
reg clk=0;always #5 clk=~clk;
reg rst_n=1;
reg source_flush=0;
reg [31:0] active_epoch=0;
reg pixel_valid=0;
reg sof=0;
reg eof=0;
reg [23:0] rgb=0;
reg [10:0] x=0;
reg [10:0] y=0;
reg [31:0] source_frame_id=0;
reg [31:0] source_epoch=0;
reg [15:0] requested_cfg_id=0;
reg [1:0] requested_color=0;
reg [7:0] requested_min_main=0;
reg [7:0] requested_min_diff_1=0;
reg [7:0] requested_min_diff_2=0;
wire result_strobe;
wire new_observation;
wire new_source_sof;
wire accepted_sof;
wire frame_abort;
wire stream_error;
wire [15:0] active_cfg_id;
wire [1:0] active_color;
wire [7:0] active_min_main;
wire [7:0] active_min_diff_1;
wire [7:0] active_min_diff_2;
wire target_valid;
wire [31:0] frame_id;
wire [31:0] capture_epoch;
wire [15:0] cfg_id;
wire [1:0] target_id;
wire [19:0] area;
wire [10:0] cx;
wire [10:0] cy;
wire [10:0] xmin;
wire [10:0] xmax;
wire [10:0] ymin;
wire [10:0] ymax;
wire [2:0] reject_reason;
wire [7:0] peak_slots;
wire [11:0] component_count;
h4e_capture_tracker #(.WIDTH(W),.HEIGHT(H),.MAX_RUNS(64)) dut(.clk(clk),.rst_n(rst_n),.source_flush(source_flush),.active_epoch(active_epoch),.pixel_valid(pixel_valid),.sof(sof),.eof(eof),.rgb(rgb),.x(x),.y(y),.source_frame_id(source_frame_id),.source_epoch(source_epoch),.requested_cfg_id(requested_cfg_id),.requested_color(requested_color),.requested_min_main(requested_min_main),.requested_min_diff_1(requested_min_diff_1),.requested_min_diff_2(requested_min_diff_2),.result_strobe(result_strobe),.new_observation(new_observation),.new_source_sof(new_source_sof),.accepted_sof(accepted_sof),.frame_abort(frame_abort),.stream_error(stream_error),.active_cfg_id(active_cfg_id),.active_color(active_color),.active_min_main(active_min_main),.active_min_diff_1(active_min_diff_1),.active_min_diff_2(active_min_diff_2),.target_valid(target_valid),.frame_id(frame_id),.capture_epoch(capture_epoch),.cfg_id(cfg_id),.target_id(target_id),.area(area),.cx(cx),.cy(cy),.xmin(xmin),.xmax(xmax),.ymin(ymin),.ymax(ymax),.reject_reason(reject_reason),.peak_slots(peak_slots),.component_count(component_count));
integer control,raw,results,cm,fm,events=0,index=-1,hblank,n,xx,yy,r,g,b,cycle=0,eof_cycle=0;
integer class_count=0,filter_count=0,drain=0,total=0;
reg [1023:0] filename;
always @(posedge clk) begin
 cycle=cycle+1;
 if(rst_n && pixel_valid && eof) eof_cycle=cycle;
 if(rst_n && (frame_abort || stream_error)) $fatal(1,"unexpected input abort/error");
 if(rst_n && result_strobe) begin
  events=events+1;
  $fdisplay(results,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",index,cycle-eof_cycle,new_observation,target_valid,frame_id,capture_epoch,cfg_id,target_id,area,cx,cy,xmin,xmax,ymin,ymax,reject_reason,peak_slots,component_count);
 end
 #1;
 if(rst_n && dut.classified_valid) begin
  if(dut.classified_x!=class_count%W || dut.classified_y!=class_count/W) $fatal(1,"classified coordinates");
  if(active_cfg_id!=requested_cfg_id || active_color!=requested_color || active_min_main!=requested_min_main || active_min_diff_1!=requested_min_diff_1 || active_min_diff_2!=requested_min_diff_2) $fatal(1,"configuration mismatch");
  $fwrite(cm,"%c",{7'd0,dut.classified_mask});class_count=class_count+1;
 end
 if(rst_n && dut.filtered_valid) begin
  if(dut.filtered_x!=filter_count%W || dut.filtered_y!=filter_count/W) $fatal(1,"filtered coordinates");
  $fwrite(fm,"%c",{7'd0,dut.filtered_mask});filter_count=filter_count+1;
 end
end
task idle;input integer count;integer j;begin
 for(j=0;j<count;j=j+1) begin @(negedge clk);pixel_valid=0;sof=0;eof=0;end
end endtask
initial begin
 control=$fopen("frames.txt","r");results=$fopen("results.csv","w");
 if(!control || !results) $fatal(1,"file open");
 $fdisplay(results,"index,latency,new_observation,target_valid,frame_id,capture_epoch,cfg_id,target_id,area,cx,cy,xmin,xmax,ymin,ymax,reject_reason,peak_slots,component_count");
 #1;rst_n=0;idle(3);rst_n=1;idle(3);
 while(!$feof(control)) begin
  @(negedge clk);
  n=$fscanf(control,"%d %d %d %d %d %d %d %d %d\n",index,source_frame_id,source_epoch,requested_cfg_id,requested_color,requested_min_main,requested_min_diff_1,requested_min_diff_2,hblank);
  if(n!=9) $fatal(1,"bad metadata");
  active_epoch=source_epoch;class_count=0;filter_count=0;
  $sformat(filename,"frame_%0d.rgb",index);raw=$fopen(filename,"rb");
  $sformat(filename,"class_%0d.bin",index);cm=$fopen(filename,"wb");
  $sformat(filename,"filter_%0d.bin",index);fm=$fopen(filename,"wb");
  if(!raw || !cm || !fm) $fatal(1,"frame file open");
  for(yy=0;yy<H;yy=yy+1) begin
   for(xx=0;xx<W;xx=xx+1) begin
    @(negedge clk);r=$fgetc(raw);g=$fgetc(raw);b=$fgetc(raw);
    if(r<0 || g<0 || b<0) $fatal(1,"truncated RGB");
    pixel_valid=1;sof=(xx==0 && yy==0);eof=(xx==W-1 && yy==H-1);x=xx;y=yy;rgb={r[7:0],g[7:0],b[7:0]};
   end
   if(yy<H-1) idle(hblank);
  end
  idle(1);drain=0;
  while(events<index+1 && drain<W+8192) begin idle(1);drain=drain+1;end
  if(events!=index+1) $fatal(1,"missing/extra frame result");
  idle(64);
  if(events!=index+1 || class_count!=W*H || filter_count!=W*H) $fatal(1,"duplicate result or missing pixels");
  if($fgetc(raw)!=-1) $fatal(1,"trailing RGB bytes");
  $fclose(raw);$fclose(cm);$fclose(fm);total=total+1;
 end
 idle(256);if(events!=total) $fatal(1,"result after source stopped");
 $fclose(control);$fclose(results);$display("H4E_C4_REPLAY_PASS frames=%0d pixels=%0d quiet_clocks=256",total,total*W*H);$finish;
end
endmodule
