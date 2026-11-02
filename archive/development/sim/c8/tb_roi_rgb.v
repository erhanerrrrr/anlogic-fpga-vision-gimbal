`timescale 1ns/1ps
module tb_roi_rgb;
    parameter WIDTH=32,HEIGHT=24,ROI_X=8,ROI_Y=4;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,pixel_valid=0,sof=0,eol=0,eof=0,sample_req=0;
    reg [23:0] rgb=0;
    reg [10:0] x=0,y=0;
    reg [31:0] source_frame_id=0;
    reg [15:0] cfg_id=0;
    reg [1:0] active_color=0;
    wire filtered_valid;
    wire filtered_mask;
    wire [10:0] filtered_x;
    wire [10:0] filtered_y;
    wire filtered_sof;
    wire filtered_eol;
    wire filtered_eof;
    wire [31:0] filtered_frame_id;
    wire [15:0] filtered_cfg_id;
    wire [1:0] filtered_target_id;
    wire result_strobe;
    wire target_valid;
    wire [31:0] result_frame_id;
    wire [15:0] result_cfg_id;
    wire [1:0] target_id;
    wire [19:0] area;
    wire [10:0] cx;
    wire [10:0] xmin;
    wire [10:0] xmax;
    wire [10:0] cy;
    wire [10:0] ymin;
    wire [10:0] ymax;
    wire [2:0] reject_reason;
    wire [19:0] debug_count;
    wire [10:0] debug_xmin;
    wire [10:0] debug_ymin;
    wire [10:0] debug_xmax;
    wire [10:0] debug_ymax;
    wire b_filtered_valid;
    wire b_filtered_mask;
    wire [10:0] b_filtered_x;
    wire [10:0] b_filtered_y;
    wire b_filtered_sof;
    wire b_filtered_eol;
    wire b_filtered_eof;
    wire [31:0] b_filtered_frame_id;
    wire [15:0] b_filtered_cfg_id;
    wire [1:0] b_filtered_target_id;
    wire b_result_strobe;
    wire b_target_valid;
    wire [31:0] b_result_frame_id;
    wire [15:0] b_result_cfg_id;
    wire [1:0] b_target_id;
    wire [19:0] b_area;
    wire [10:0] b_cx;
    wire [10:0] b_xmin;
    wire [10:0] b_xmax;
    wire [10:0] b_cy;
    wire [10:0] b_ymin;
    wire [10:0] b_ymax;
    wire [2:0] b_reject_reason;
    wire [19:0] b_debug_count;
    wire [10:0] b_debug_xmin;
    wire [10:0] b_debug_ymin;
    wire [10:0] b_debug_xmax;
    wire [10:0] b_debug_ymax;
    wire busy;
    wire request_ignored;
    wire [15:0] ignored_requests;
    wire sample_done;
    wire sample_ok;
    wire [1:0] sample_reason;
    wire [31:0] sample_frame_id;
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
    rgb_sampling_result #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.ROI_X(ROI_X),.ROI_Y(ROI_Y)) dut(
        .clk(clk),
        .rst_n(rst_n),
        .pixel_valid(pixel_valid),
        .rgb(rgb),
        .x(x),
        .y(y),
        .sof(sof),
        .eol(eol),
        .eof(eof),
        .source_frame_id(source_frame_id),
        .cfg_id(cfg_id),
        .active_color(active_color),
        .filtered_valid(filtered_valid),
        .filtered_mask(filtered_mask),
        .filtered_x(filtered_x),
        .filtered_y(filtered_y),
        .filtered_sof(filtered_sof),
        .filtered_eol(filtered_eol),
        .filtered_eof(filtered_eof),
        .filtered_frame_id(filtered_frame_id),
        .filtered_cfg_id(filtered_cfg_id),
        .filtered_target_id(filtered_target_id),
        .result_strobe(result_strobe),
        .target_valid(target_valid),
        .result_frame_id(result_frame_id),
        .result_cfg_id(result_cfg_id),
        .target_id(target_id),
        .area(area),
        .cx(cx),
        .xmin(xmin),
        .xmax(xmax),
        .cy(cy),
        .ymin(ymin),
        .ymax(ymax),
        .reject_reason(reject_reason),
        .debug_count(debug_count),
        .debug_xmin(debug_xmin),
        .debug_ymin(debug_ymin),
        .debug_xmax(debug_xmax),
        .debug_ymax(debug_ymax),
        .sample_req(sample_req),
        .busy(busy),
        .request_ignored(request_ignored),
        .ignored_requests(ignored_requests),
        .sample_done(sample_done),
        .sample_ok(sample_ok),
        .sample_reason(sample_reason),
        .sample_frame_id(sample_frame_id),
        .sample_cfg_id(sample_cfg_id),
        .sample_target_id(sample_target_id),
        .sample_count(sample_count),
        .sum_r(sum_r),
        .sum_g(sum_g),
        .sum_b(sum_b),
        .min_r(min_r),
        .min_g(min_g),
        .min_b(min_b),
        .max_r(max_r),
        .max_g(max_g),
        .max_b(max_b),
        .mean_r(mean_r),
        .mean_g(mean_g),
        .mean_b(mean_b));
    rgb_fresh_result #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) baseline(
        .clk(clk),
        .rst_n(rst_n),
        .pixel_valid(pixel_valid),
        .rgb(rgb),
        .x(x),
        .y(y),
        .sof(sof),
        .eol(eol),
        .eof(eof),
        .source_frame_id(source_frame_id),
        .cfg_id(cfg_id),
        .active_color(active_color),
        .filtered_valid(b_filtered_valid),
        .filtered_mask(b_filtered_mask),
        .filtered_x(b_filtered_x),
        .filtered_y(b_filtered_y),
        .filtered_sof(b_filtered_sof),
        .filtered_eol(b_filtered_eol),
        .filtered_eof(b_filtered_eof),
        .filtered_frame_id(b_filtered_frame_id),
        .filtered_cfg_id(b_filtered_cfg_id),
        .filtered_target_id(b_filtered_target_id),
        .result_strobe(b_result_strobe),
        .target_valid(b_target_valid),
        .result_frame_id(b_result_frame_id),
        .result_cfg_id(b_result_cfg_id),
        .target_id(b_target_id),
        .area(b_area),
        .cx(b_cx),
        .xmin(b_xmin),
        .xmax(b_xmax),
        .cy(b_cy),
        .ymin(b_ymin),
        .ymax(b_ymax),
        .reject_reason(b_reject_reason),
        .debug_count(b_debug_count),
        .debug_xmin(b_debug_xmin),
        .debug_ymin(b_debug_ymin),
        .debug_xmax(b_debug_xmax),
        .debug_ymax(b_debug_ymax));
    wire [181:0] sample_packet={sample_ok,sample_reason,sample_frame_id,sample_cfg_id,sample_target_id,sample_count,sum_r,sum_g,sum_b,min_r,min_g,min_b,max_r,max_g,max_b,mean_r,mean_g,mean_b};
    reg [181:0] previous_packet=0;
    reg [17:0] previous_status=0;
    integer cycle=0,src,events,results,n,op,pattern,r1,r2,r3,stop_flag,missing,config_value,color_value,cycles,req_value;
    integer xx,yy,idx,k,ri,detector_notifications=0,checked_cycles=0;
    reg [31:0] id_value;
    reg [23:0] value;
    initial begin #400000000;$fatal(1,"watchdog");end
    always @(posedge clk) begin
        #1;
        if($time>10) begin
        cycle=cycle+1;
        if({filtered_valid,filtered_mask,filtered_x,filtered_y,filtered_sof,filtered_eol,filtered_eof,filtered_frame_id,filtered_cfg_id,filtered_target_id,result_strobe,target_valid,result_frame_id,result_cfg_id,target_id,area,cx,xmin,xmax,cy,ymin,ymax,reject_reason,debug_count,debug_xmin,debug_ymin,debug_xmax,debug_ymax} !== {b_filtered_valid,b_filtered_mask,b_filtered_x,b_filtered_y,b_filtered_sof,b_filtered_eol,b_filtered_eof,b_filtered_frame_id,b_filtered_cfg_id,b_filtered_target_id,b_result_strobe,b_target_valid,b_result_frame_id,b_result_cfg_id,b_target_id,b_area,b_cx,b_xmin,b_xmax,b_cy,b_ymin,b_ymax,b_reject_reason,b_debug_count,b_debug_xmin,b_debug_ymin,b_debug_xmax,b_debug_ymax}) $fatal(1,"C7 detector changed by sampling");
        checked_cycles=checked_cycles+1;
        if(result_strobe) detector_notifications=detector_notifications+1;
        if(!rst_n) begin
            if({sample_packet,busy,request_ignored,ignored_requests,sample_done}!==0) $fatal(1,"sampler reset failure");
        end else begin
            if((^{sample_packet,busy,request_ignored,ignored_requests,sample_done})===1'bx) $fatal(1,"unknown sampler output");
            if(!sample_done && sample_packet!==previous_packet) $fatal(1,"sample packet changed without done");
            if(sample_done && busy) $fatal(1,"done did not release busy");
        end
        if({busy,request_ignored,ignored_requests}!==previous_status || sample_done)
            $fdisplay(events,"%0d,%0d,%0d,%0d,%0d",cycle,busy,request_ignored,ignored_requests,sample_done);
        if(sample_done)
            $fdisplay(results,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                cycle,sample_frame_id,sample_cfg_id,sample_target_id,sample_ok,sample_reason,sample_count,
                sum_r,sum_g,sum_b,min_r,min_g,min_b,max_r,max_g,max_b,mean_r,mean_g,mean_b);
        previous_packet=sample_packet;previous_status={busy,request_ignored,ignored_requests};
        end
    end
    task beat;
        input rv,pv,req;
        input [23:0] data;
        input integer px,py;
        input s,l,f;
        begin
            @(negedge clk);rst_n=rv;pixel_valid=pv;sample_req=req;rgb=data;
            x=px;y=py;sof=s;eol=l;eof=f;
            @(posedge clk);#2;
        end
    endtask
    initial begin
        src=$fopen("cases.txt","r");events=$fopen("events.csv","w");results=$fopen("actual.csv","w");
        if(!src || !events || !results) $fatal(1,"file open failed");
        $fdisplay(events,"cycle,busy,request_ignored,ignored_requests,done");
        $fdisplay(results,"cycle,frame_id,cfg_id,target_id,ok,reason,count,sum_r,sum_g,sum_b,min_r,min_g,min_b,max_r,max_g,max_b,mean_r,mean_g,mean_b");
        $dumpfile("sampling_trace.vcd");$dumpvars(1,tb_roi_rgb);
        if(WIDTH>32) $dumpoff;
        beat(0,0,0,0,0,0,0,0,0);
        while(!$feof(src)) begin
            n=$fscanf(src,"%d %h %d %d %d %d %d %d %d %d %d %d\n",op,id_value,pattern,r1,r2,r3,stop_flag,missing,config_value,color_value,cycles,req_value);
            if(n!=12) $fatal(1,"bad case");
            if(op==1) beat(0,0,0,0,0,0,0,0,0);
            else if(op==2) begin
                for(k=0;k<cycles;k=k+1) beat(1,0,req_value,0,0,0,0,0,0);
            end else begin
                source_frame_id=id_value;cfg_id=config_value;active_color=color_value;
                for(yy=0;yy<HEIGHT;yy=yy+1) begin
                    for(xx=0;xx<WIDTH;xx=xx+1) begin
                        idx=yy*WIDTH+xx;
                        if(!stop_flag || yy<ROI_Y+16) begin
                            value=pattern==1 ? 24'h0000ff : 0;
                            if(xx>=ROI_X && xx<ROI_X+16 && yy>=ROI_Y && yy<ROI_Y+16) begin
                                ri=(yy-ROI_Y)*16+xx-ROI_X;
                                case(pattern)
                                    0,1:value=ri<128 ? 24'h902828 : 24'ha02828;
                                    2:value=24'hffffff;
                                    3:begin value[23:16]=(ri*17+3)%256;value[15:8]=(ri*29+7)%256;value[7:0]=(ri*43+11)%256;end
                                    4:value=24'h289828;
                                    5:value=24'h282898;
                                    default:value=0;
                                endcase
                            end
                            beat(1,!(missing && xx==ROI_X+15 && yy==ROI_Y+15),idx==r1 || idx==r2 || idx==r3,
                                 value,xx,yy,idx==0,xx==WIDTH-1,idx==WIDTH*HEIGHT-1);
                        end
                    end
                    if(yy<HEIGHT-1 && (!stop_flag || yy<ROI_Y+15))
                        for(k=0;k<1+yy%3;k=k+1) beat(1,0,0,0,0,0,0,0,0);
                end
            end
        end
        for(k=0;k<WIDTH+50;k=k+1) beat(1,0,0,0,0,0,0,0,0);
        $fclose(src);$fclose(events);$fclose(results);
        $display("C8_COMPLETE checked_cycles=%0d detector_notifications=%0d",checked_cycles,detector_notifications);
        $finish;
    end
endmodule
