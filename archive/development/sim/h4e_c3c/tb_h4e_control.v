`timescale 1ns/1ps
module tb_h4e_control;
reg clk=0;always #5 clk=~clk;
reg rst_n=0;
reg source_flush=0;
reg [31:0] active_epoch=0;
reg new_source_sof=0;
reg calibrate_req=0;
reg color_select_req=0;
reg [1:0] color_select=0;
reg sampler_busy=0;
reg calibration_done=0;
reg calibration_ok=0;
reg [31:0] calibration_epoch=0;
reg [1:0] candidate_color=0;
reg [7:0] candidate_min_main=0;
reg [7:0] candidate_diff_1=0;
reg [7:0] candidate_diff_2=0;
reg [15:0] active_cfg_id=0;
reg [1:0] active_color=0;
reg [7:0] active_min_main=0;
reg [7:0] active_min_diff_1=0;
reg [7:0] active_min_diff_2=0;
wire sample_req;
wire busy;
wire operation_flush;
wire request_ignored;
wire select_ignored;
wire cfg_applied;
wire operation_cancelled;
wire pending_valid;
wire [1:0] pending_color;
wire [7:0] pending_main;
wire [7:0] pending_diff_1;
wire [7:0] pending_diff_2;
wire [15:0] requested_cfg_id;
wire [1:0] requested_color;
wire [7:0] requested_min_main;
wire [7:0] requested_min_diff_1;
wire [7:0] requested_min_diff_2;
h4e_calibration_control dut(.clk(clk),.rst_n(rst_n),.source_flush(source_flush),.active_epoch(active_epoch),.new_source_sof(new_source_sof),.calibrate_req(calibrate_req),.color_select_req(color_select_req),.color_select(color_select),.sampler_busy(sampler_busy),.calibration_done(calibration_done),.calibration_ok(calibration_ok),.calibration_epoch(calibration_epoch),.candidate_color(candidate_color),.candidate_min_main(candidate_min_main),.candidate_diff_1(candidate_diff_1),.candidate_diff_2(candidate_diff_2),.active_cfg_id(active_cfg_id),.active_color(active_color),.active_min_main(active_min_main),.active_min_diff_1(active_min_diff_1),.active_min_diff_2(active_min_diff_2),.sample_req(sample_req),.busy(busy),.operation_flush(operation_flush),.request_ignored(request_ignored),.select_ignored(select_ignored),.cfg_applied(cfg_applied),.operation_cancelled(operation_cancelled),.pending_valid(pending_valid),.pending_color(pending_color),.pending_main(pending_main),.pending_diff_1(pending_diff_1),.pending_diff_2(pending_diff_2),.requested_cfg_id(requested_cfg_id),.requested_color(requested_color),.requested_min_main(requested_min_main),.requested_min_diff_1(requested_min_diff_1),.requested_min_diff_2(requested_min_diff_2));
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin active_cfg_id<=65534;active_color<=0;active_min_main<=24;active_min_diff_1<=16;active_min_diff_2<=16;end
 else if(new_source_sof) begin active_cfg_id<=requested_cfg_id;active_color<=requested_color;active_min_main<=requested_min_main;active_min_diff_1<=requested_min_diff_1;active_min_diff_2<=requested_min_diff_2;end
end
integer f,o,n,cycle;reg sampled;
initial begin
 f=$fopen("control.txt","r");o=$fopen("control_actual.csv","w");
 $fdisplay(o,"cycle,sample,apply,ignored,select_ignored,cancelled,busy,pending,pc,pm,pd1,pd2,cfg,color,main,d1,d2");
 cycle=0;
 while(!$feof(f)) begin @(negedge clk);
n=$fscanf(f,"%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",rst_n,source_flush,active_epoch,new_source_sof,calibrate_req,color_select_req,color_select,sampler_busy,calibration_done,calibration_ok,calibration_epoch,candidate_color,candidate_min_main,candidate_diff_1,candidate_diff_2);
if(n!=15) $fatal(1,"bad control input");
@(posedge clk);sampled=sample_req;#1;
$fdisplay(o,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",cycle,sampled,cfg_applied,request_ignored,select_ignored,operation_cancelled,busy,pending_valid,pending_color,pending_main,pending_diff_1,pending_diff_2,active_cfg_id,active_color,active_min_main,active_min_diff_1,active_min_diff_2);
cycle=cycle+1;end
$fclose(f);$fclose(o);$display("C3C_CONTROL_PASS %0d",cycle);$finish;end
endmodule
