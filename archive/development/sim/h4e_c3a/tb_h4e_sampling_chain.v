`timescale 1ns/1ps
module tb_h4e_capture_tracker;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=1,source_flush=0,pixel_valid=0,sof=0,eof=0;
    reg [31:0] active_epoch=7,source_frame_id=0,source_epoch=7;
    reg [23:0] rgb=0;
    reg [10:0] x=0,y=0;
    reg [15:0] requested_cfg_id=1;
    reg [1:0] requested_color=0;
    reg [7:0] requested_min_main=24,requested_min_diff_1=16,requested_min_diff_2=16;
    wire result_strobe,new_observation,new_source_sof,accepted_sof,frame_abort,stream_error;
    wire [15:0] active_cfg_id;
    wire [1:0] active_color;
    wire [7:0] active_min_main,active_min_diff_1,active_min_diff_2;
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
    h4e_sampling_tracker #(.WIDTH(64),.HEIGHT(32)) dut(
        .sample_req(1'b1),.clk(clk),.rst_n(rst_n),.source_flush(source_flush),.active_epoch(active_epoch),
        .pixel_valid(pixel_valid),.sof(sof),.eof(eof),.rgb(rgb),.x(x),.y(y),
        .source_frame_id(source_frame_id),.source_epoch(source_epoch),
        .requested_cfg_id(requested_cfg_id),.requested_color(requested_color),
        .requested_min_main(requested_min_main),.requested_min_diff_1(requested_min_diff_1),
        .requested_min_diff_2(requested_min_diff_2),
        .result_strobe(result_strobe),.new_observation(new_observation),
        .new_source_sof(new_source_sof),.accepted_sof(accepted_sof),.frame_abort(frame_abort),.stream_error(stream_error),
        .active_cfg_id(active_cfg_id),.active_color(active_color),.active_min_main(active_min_main),
        .active_min_diff_1(active_min_diff_1),.active_min_diff_2(active_min_diff_2),
        .target_valid(target_valid),
        .frame_id(frame_id),
        .capture_epoch(capture_epoch),
        .cfg_id(cfg_id),
        .target_id(target_id),
        .area(area),
        .cx(cx),
        .cy(cy),
        .xmin(xmin),
        .xmax(xmax),
        .ymin(ymin),
        .ymax(ymax),
        .reject_reason(reject_reason),
        .peak_slots(peak_slots),
        .component_count(component_count));
    integer src,results,pixels,configs,errors,n,cycle=-1,attempt=-1;
    reg saved_sof,saved_new;
    always @(posedge clk) begin
        saved_sof=accepted_sof;saved_new=new_source_sof;
        // Consumer view: sample pre-NBA packet and freshness at this clock edge.
        if(rst_n && result_strobe)
            $fdisplay(results,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",cycle,attempt,new_observation,target_valid,frame_id,capture_epoch,cfg_id,target_id,area,cx,cy,xmin,xmax,ymin,ymax,reject_reason,peak_slots,component_count);
        #1;
        if(rst_n && saved_sof)
            $fdisplay(configs,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",cycle,attempt,saved_new,
                active_cfg_id,active_color,active_min_main,active_min_diff_1,active_min_diff_2);
        if(rst_n && dut.tracker.classified_valid)
            $fdisplay(pixels,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                cycle,attempt,dut.tracker.held_frame,dut.tracker.held_epoch,active_cfg_id,active_color,
                active_min_main,active_min_diff_1,active_min_diff_2,dut.tracker.classified_x,dut.tracker.classified_y,
                dut.tracker.classified_mask,dut.tracker.processing_rst_n);
        if(rst_n && (frame_abort || stream_error))
            $fdisplay(errors,"%0d,%0d,%0d,%0d",cycle,attempt,frame_abort,stream_error);
    end
    initial begin #3000000;$fatal(1,"capture watchdog");end
    initial begin
        src=$fopen("stimulus.txt","r");results=$fopen("results.csv","w");
        pixels=$fopen("pixels.csv","w");configs=$fopen("configs.csv","w");errors=$fopen("errors.csv","w");
        if(!src || !results || !pixels || !configs || !errors) $fatal(1,"file open");
        $fdisplay(results,"cycle,attempt,new_observation,target_valid,frame_id,capture_epoch,cfg_id,target_id,area,cx,cy,xmin,xmax,ymin,ymax,reject_reason,peak_slots,component_count");
        $fdisplay(pixels,"cycle,attempt,frame_id,epoch,cfg,color,minimum,d1,d2,x,y,mask,processing_rst_n");
        $fdisplay(configs,"cycle,attempt,new_source_sof,cfg,color,minimum,d1,d2");
        $fdisplay(errors,"cycle,attempt,frame_abort,stream_error");
        while(!$feof(src)) begin
            @(negedge clk);
            n=$fscanf(src,"%d %d %d %d %h %d %d %d %d %d %h %h %h %h %d %d %d %d\n",
                cycle,attempt,rst_n,source_flush,active_epoch,pixel_valid,sof,eof,x,y,rgb,
                source_frame_id,source_epoch,requested_cfg_id,requested_color,
                requested_min_main,requested_min_diff_1,requested_min_diff_2);
            if(n!=18)$fatal(1,"bad stimulus %0d",n);
            @(posedge clk);#2;
        end
        $fclose(src);$fclose(results);$fclose(pixels);$fclose(configs);$fclose(errors);
        $display("H4E_C2B_CHAIN_COMPLETE");$finish;
    end
endmodule
