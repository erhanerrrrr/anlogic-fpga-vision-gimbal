`timescale 1ns/1ps
module tb_control;
    reg clk=0;
    reg rst_n=0;
    reg pixel_valid=0;
    reg sof=0;
    reg [31:0] source_frame_id=0;
    reg calibrate_req=0;
    reg color_select_req=0;
    reg [1:0] color_select=0;
    reg sample_done=0;
    reg params_valid=0;
    reg [2:0] params_reason=0;
    reg [31:0] sample_frame_id=0;
    reg [1:0] params_color=0;
    reg [7:0] params_main=0;
    reg [7:0] params_diff_1=0;
    reg [7:0] params_diff_2=0;
    wire sample_req;
    wire busy;
    wire request_ignored;
    wire select_ignored;
    wire [15:0] ignored_requests;
    wire calibration_done;
    wire calibration_ok;
    wire [2:0] calibration_reason;
    wire [31:0] calibration_frame_id;
    wire cfg_applied;
    wire pending_valid;
    wire [1:0] pending_color;
    wire [1:0] active_color;
    wire [7:0] pending_main;
    wire [7:0] pending_diff_1;
    wire [7:0] pending_diff_2;
    wire [7:0] active_main;
    wire [7:0] active_diff_1;
    wire [7:0] active_diff_2;
    wire [15:0] active_cfg_id;
    wire [1:0] pixel_color;
    wire [7:0] pixel_main;
    wire [7:0] pixel_diff_1;
    wire [7:0] pixel_diff_2;
    wire [15:0] pixel_cfg_id;
    always #5 clk=~clk;
    calibration_control #(.INITIAL_CFG_ID(16'hffff)) dut(
        .clk(clk),
        .rst_n(rst_n),
        .pixel_valid(pixel_valid),
        .sof(sof),
        .source_frame_id(source_frame_id),
        .calibrate_req(calibrate_req),
        .color_select_req(color_select_req),
        .color_select(color_select),
        .sample_done(sample_done),
        .params_valid(params_valid),
        .params_reason(params_reason),
        .sample_frame_id(sample_frame_id),
        .params_color(params_color),
        .params_main(params_main),
        .params_diff_1(params_diff_1),
        .params_diff_2(params_diff_2),
        .sample_req(sample_req),
        .busy(busy),
        .request_ignored(request_ignored),
        .select_ignored(select_ignored),
        .ignored_requests(ignored_requests),
        .calibration_done(calibration_done),
        .calibration_ok(calibration_ok),
        .calibration_reason(calibration_reason),
        .calibration_frame_id(calibration_frame_id),
        .cfg_applied(cfg_applied),
        .pending_valid(pending_valid),
        .pending_color(pending_color),
        .active_color(active_color),
        .pending_main(pending_main),
        .pending_diff_1(pending_diff_1),
        .pending_diff_2(pending_diff_2),
        .active_main(active_main),
        .active_diff_1(active_diff_1),
        .active_diff_2(active_diff_2),
        .active_cfg_id(active_cfg_id),
        .pixel_color(pixel_color),
        .pixel_main(pixel_main),
        .pixel_diff_1(pixel_diff_1),
        .pixel_diff_2(pixel_diff_2),
        .pixel_cfg_id(pixel_cfg_id));
    integer src,out,n,index;
    integer pre_sample_req;
    integer pre_pixel_color;
    integer pre_pixel_main;
    integer pre_pixel_diff_1;
    integer pre_pixel_diff_2;
    integer pre_pixel_cfg_id;
    initial begin #2000000;$fatal(1,"watchdog");end
    initial begin
        src=$fopen("control.txt","r");out=$fopen("control_actual.csv","w");index=0;
        $fdisplay(out,"index,pre_sample_req,pre_pixel_color,pre_pixel_main,pre_pixel_diff_1,pre_pixel_diff_2,pre_pixel_cfg_id,busy,request_ignored,select_ignored,ignored_requests,calibration_done,calibration_ok,calibration_reason,calibration_frame_id,cfg_applied,pending_valid,pending_color,active_color,pending_main,pending_diff_1,pending_diff_2,active_main,active_diff_1,active_diff_2,active_cfg_id");
        while(!$feof(src)) begin
            @(negedge clk);
            n=$fscanf(src,"%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",rst_n,pixel_valid,sof,source_frame_id,calibrate_req,color_select_req,color_select,sample_done,params_valid,params_reason,sample_frame_id,params_color,params_main,params_diff_1,params_diff_2);
            if(n!=15) $fatal(1,"bad control input");
            @(posedge clk);
            pre_sample_req=sample_req;
            pre_pixel_color=pixel_color;
            pre_pixel_main=pixel_main;
            pre_pixel_diff_1=pixel_diff_1;
            pre_pixel_diff_2=pixel_diff_2;
            pre_pixel_cfg_id=pixel_cfg_id;
            #1;
            $fdisplay(out,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",index,pre_sample_req,pre_pixel_color,pre_pixel_main,pre_pixel_diff_1,pre_pixel_diff_2,pre_pixel_cfg_id,busy,request_ignored,select_ignored,ignored_requests,calibration_done,calibration_ok,calibration_reason,calibration_frame_id,cfg_applied,pending_valid,pending_color,active_color,pending_main,pending_diff_1,pending_diff_2,active_main,active_diff_1,active_diff_2,active_cfg_id);
            index=index+1;
        end
        $display("C9_CONTROL_COMPLETE cycles=%0d",index);$fclose(src);$fclose(out);$finish;
    end
endmodule
