`timescale 1ns/1ps
module tb_h4e_calibrated_chain;
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
wire busy;
wire request_ignored;
wire sample_done;
wire sample_ok;
wire [1:0] sample_reason;
wire [31:0] sample_frame_id;
wire [31:0] sample_epoch;
wire [15:0] sample_cfg_id;
wire [1:0] sample_target_id;
wire [8:0] sample_count;
wire [15:0] sum_r;
wire [15:0] sum_g;
wire [15:0] sum_b;
wire [7:0] min_r;
wire [7:0] min_g;
wire [7:0] min_b;
wire [7:0] max_r;
wire [7:0] max_g;
wire [7:0] max_b;
wire [7:0] mean_r;
wire [7:0] mean_g;
wire [7:0] mean_b;
wire calibration_done;
wire calibration_ok;
wire [2:0] calibration_reason;
wire [31:0] calibration_frame_id;
wire [31:0] calibration_epoch;
wire [15:0] calibration_cfg_id;
wire [1:0] calibration_target_id;
wire [1:0] candidate_color;
wire [7:0] candidate_min_main;
wire [7:0] candidate_diff_1;
wire [7:0] candidate_diff_2;
reg calibrate_req=0;
reg color_select_req=0;
reg [1:0] color_select=0;
wire select_ignored;
wire cfg_applied;
wire operation_cancelled;
wire pending_valid;
wire [1:0] pending_color;
wire [7:0] pending_main;
wire [7:0] pending_diff_1;
wire [7:0] pending_diff_2;
h4e_calibrated_tracker #(.WIDTH(64),.HEIGHT(32)) dut(.clk(clk),.rst_n(rst_n),.source_flush(source_flush),.active_epoch(active_epoch),.pixel_valid(pixel_valid),.sof(sof),.eof(eof),.rgb(rgb),.x(x),.y(y),.source_frame_id(source_frame_id),.source_epoch(source_epoch),.result_strobe(result_strobe),.new_observation(new_observation),.new_source_sof(new_source_sof),.accepted_sof(accepted_sof),.frame_abort(frame_abort),.stream_error(stream_error),.active_cfg_id(active_cfg_id),.active_color(active_color),.active_min_main(active_min_main),.active_min_diff_1(active_min_diff_1),.active_min_diff_2(active_min_diff_2),.target_valid(target_valid),.frame_id(frame_id),.capture_epoch(capture_epoch),.cfg_id(cfg_id),.target_id(target_id),.area(area),.cx(cx),.cy(cy),.xmin(xmin),.xmax(xmax),.ymin(ymin),.ymax(ymax),.reject_reason(reject_reason),.peak_slots(peak_slots),.component_count(component_count),.busy(busy),.request_ignored(request_ignored),.sample_done(sample_done),.sample_ok(sample_ok),.sample_reason(sample_reason),.sample_frame_id(sample_frame_id),.sample_epoch(sample_epoch),.sample_cfg_id(sample_cfg_id),.sample_target_id(sample_target_id),.sample_count(sample_count),.sum_r(sum_r),.sum_g(sum_g),.sum_b(sum_b),.min_r(min_r),.min_g(min_g),.min_b(min_b),.max_r(max_r),.max_g(max_g),.max_b(max_b),.mean_r(mean_r),.mean_g(mean_g),.mean_b(mean_b),.calibration_done(calibration_done),.calibration_ok(calibration_ok),.calibration_reason(calibration_reason),.calibration_frame_id(calibration_frame_id),.calibration_epoch(calibration_epoch),.calibration_cfg_id(calibration_cfg_id),.calibration_target_id(calibration_target_id),.candidate_color(candidate_color),.candidate_min_main(candidate_min_main),.candidate_diff_1(candidate_diff_1),.candidate_diff_2(candidate_diff_2),.calibrate_req(calibrate_req),.color_select_req(color_select_req),.color_select(color_select),.select_ignored(select_ignored),.cfg_applied(cfg_applied),.operation_cancelled(operation_cancelled),.pending_valid(pending_valid),.pending_color(pending_color),.pending_main(pending_main),.pending_diff_1(pending_diff_1),.pending_diff_2(pending_diff_2));
    integer controls,candidates,src,results,pixels,configs,errors,n,cycle=-1,attempt=-1;
    reg saved_sof,saved_new;
    always @(posedge clk) begin
        saved_sof=accepted_sof;saved_new=new_source_sof;
        // Consumer view: sample pre-NBA packet and freshness at this clock edge.
        if(rst_n && result_strobe)
            $fdisplay(results,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",cycle,attempt,new_observation,target_valid,frame_id,capture_epoch,cfg_id,target_id,area,cx,cy,xmin,xmax,ymin,ymax,reject_reason,peak_slots,component_count);
        if(rst_n && calibration_done)
            $fdisplay(candidates,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",cycle,attempt,new_source_sof,calibration_ok,calibration_reason,calibration_frame_id,calibration_epoch,calibration_cfg_id,candidate_color,candidate_min_main,candidate_diff_1,candidate_diff_2);
        #1;
        if(rst_n && (cfg_applied || request_ignored || select_ignored || operation_cancelled))
            $fdisplay(controls,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",cycle,attempt,cfg_applied,request_ignored,select_ignored,operation_cancelled,active_cfg_id,pending_valid);
        if(rst_n && saved_sof)
            $fdisplay(configs,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",cycle,attempt,saved_new,
                active_cfg_id,active_color,active_min_main,active_min_diff_1,active_min_diff_2);
        if(rst_n && dut.candidate_tracker.sampling.tracker.classified_valid)
            $fdisplay(pixels,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                cycle,attempt,dut.candidate_tracker.sampling.tracker.held_frame,dut.candidate_tracker.sampling.tracker.held_epoch,active_cfg_id,active_color,
                active_min_main,active_min_diff_1,active_min_diff_2,dut.candidate_tracker.sampling.tracker.classified_x,dut.candidate_tracker.sampling.tracker.classified_y,
                dut.candidate_tracker.sampling.tracker.classified_mask,dut.candidate_tracker.sampling.tracker.processing_rst_n);
        if(rst_n && (frame_abort || stream_error))
            $fdisplay(errors,"%0d,%0d,%0d,%0d",cycle,attempt,frame_abort,stream_error);
    end
    initial begin #3000000;$fatal(1,"capture watchdog");end
    initial begin
        controls=$fopen("controls.csv","w");candidates=$fopen("candidates.csv","w");
        $fdisplay(controls,"cycle,attempt,applied,ignored,select_ignored,cancelled,cfg,pending");
        $fdisplay(candidates,"cycle,attempt,new_sof,ok,reason,fid,epoch,cfg,color,main,d1,d2");
        src=$fopen("stimulus.txt","r");results=$fopen("results.csv","w");
        pixels=$fopen("pixels.csv","w");configs=$fopen("configs.csv","w");errors=$fopen("errors.csv","w");
        if(!src || !results || !pixels || !configs || !errors) $fatal(1,"file open");
        $fdisplay(results,"cycle,attempt,new_observation,target_valid,frame_id,capture_epoch,cfg_id,target_id,area,cx,cy,xmin,xmax,ymin,ymax,reject_reason,peak_slots,component_count");
        $fdisplay(pixels,"cycle,attempt,frame_id,epoch,cfg,color,minimum,d1,d2,x,y,mask,processing_rst_n");
        $fdisplay(configs,"cycle,attempt,new_source_sof,cfg,color,minimum,d1,d2");
        $fdisplay(errors,"cycle,attempt,frame_abort,stream_error");
        while(!$feof(src)) begin
            @(negedge clk);
            n=$fscanf(src,"%d %d %d %d %h %d %d %d %d %d %h %h %h %d %d %d\n",
                cycle,attempt,rst_n,source_flush,active_epoch,pixel_valid,sof,eof,x,y,rgb,
                source_frame_id,source_epoch,calibrate_req,color_select_req,color_select);
            if(n!=16)$fatal(1,"bad stimulus %0d",n);
            @(posedge clk);#2;
        end
        $fclose(src);$fclose(results);$fclose(pixels);$fclose(configs);$fclose(errors);
        $display("H4E_C3C_CHAIN_COMPLETE");$finish;
    end
endmodule
