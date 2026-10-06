`timescale 1ns/1ps
module tb_mask_frame_stats;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0,valid=0,mask=0,sof=0,eol=0,eof=0;
    reg [10:0] x=0,y=0;
    reg [31:0] fid=0;
    reg [23:0] rgb=0;
    wire cv,cm,cs,cl,ce;
    wire [10:0] cx,cy;
    wire [31:0] cf;
    wire ds,ss;
    wire [31:0] df,sf;
    wire [19:0] dc,sc;
    wire [10:0] dx0,dx1,dy0,dy1,sx0,sx1,sy0,sy1;
    color_mask_stream segmenter(clk,rst_n,valid,rgb,2'd0,x,y,sof,eol,eof,fid,
        cv,cm,cx,cy,cs,cl,ce,cf);
    mask_frame_stats direct(clk,rst_n,valid,mask,x,y,sof,eof,fid,ds,df,dc,dx0,dx1,dy0,dy1);
    mask_frame_stats chained(clk,rst_n,cv,cm,cx,cy,cs,ce,cf,ss,sf,sc,sx0,sx1,sy0,sy1);
    wire [95:0] direct_packet={df,dc,dx0,dy0,dx1,dy1};
    wire [95:0] chain_packet={sf,sc,sx0,sy0,sx1,sy1};
    reg [95:0] previous_direct=0,previous_chain=0;
    reg delayed_eof=0;
    integer config_file,actual_file,timing_file,n,w,h,pattern,abort_at,xx,yy,idx,k;
    integer cycle=0;
    reg [31:0] config_id;
    reg bit_value;
    reg [23:0] rgb_value;
    initial begin #100000000; $fatal(1,"watchdog"); end

    task beat;
        input reset_value,valid_value,mask_value,accepted;
        input [23:0] color;
        input integer px,py;
        input start_flag,line_flag,end_flag;
        reg expected_direct,expected_chain;
        begin
            @(negedge clk);
            if (direct_packet !== previous_direct || chain_packet !== previous_chain)
                $fatal(1,"fields changed between sampling edges");
            rst_n=reset_value; valid=valid_value; mask=mask_value; rgb=color;
            x=px;y=py;sof=start_flag;eol=line_flag;eof=end_flag;
            #1;
            if (!rst_n && ({ds,ss,direct_packet,chain_packet} !== 194'b0))
                $fatal(1,"reset did not clear results");
            expected_direct=reset_value && accepted && end_flag;
            expected_chain=reset_value && delayed_eof;
            @(posedge clk); #1;
            cycle=cycle+1;
            if ((^{ds,ss,direct_packet,chain_packet}) === 1'bx) $fatal(1,"unknown result");
            if (ds !== expected_direct || ss !== expected_chain) $fatal(1,"notification timing mismatch");
            if (rst_n && !ds && direct_packet !== previous_direct) $fatal(1,"direct result not held");
            if (rst_n && !ss && chain_packet !== previous_chain) $fatal(1,"chain result not held");
            if (ds) $fdisplay(actual_file,"direct,%0d,%0d,%0d,%0d,%0d,%0d,%0d",cycle,df,dc,dx0,dy0,dx1,dy1);
            if (ss) $fdisplay(actual_file,"chain,%0d,%0d,%0d,%0d,%0d,%0d,%0d",cycle,sf,sc,sx0,sy0,sx1,sy1);
            if (end_flag || ds || ss || !rst_n)
                $fdisplay(timing_file,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",cycle,rst_n,fid,valid,eof,ds,dc,ss,sc);
            previous_direct=direct_packet; previous_chain=chain_packet;
            delayed_eof=expected_direct;
        end
    endtask

    initial begin
        $dumpfile("eof_trace.vcd"); $dumpvars(0,tb_mask_frame_stats); $dumpoff;
        config_file=$fopen("cases.txt","r"); actual_file=$fopen("actual.csv","w");
        timing_file=$fopen("timing.csv","w");
        if (!config_file || !actual_file || !timing_file) $fatal(1,"file open failed");
        $fdisplay(actual_file,"path,cycle,frame_id,count,xmin,ymin,xmax,ymax");
        $fdisplay(timing_file,"cycle,rst_n,input_id,input_valid,input_eof,direct_strobe,direct_count,chain_strobe,chain_count");
        beat(0,0,0,0,0,0,0,0,0,0);
        beat(1,1,1,0,24'hc82828,3,2,0,1,1);
        while (!$feof(config_file)) begin
            n=$fscanf(config_file,"%d %d %h %d %d\n",w,h,config_id,pattern,abort_at);
            if (n!=5) $fatal(1,"bad case");
            fid=config_id;
            for (yy=0;yy<h;yy=yy+1) begin
                for (xx=0;xx<w;xx=xx+1) begin
                    idx=yy*w+xx;
                    if (idx==abort_at) beat(0,0,0,0,0,0,0,0,0,0);
                    case (pattern)
                        0:bit_value=(xx>=100 && xx<=140 && yy>=80 && yy<=110);
                        1:bit_value=(idx==0);
                        2,7:bit_value=0;
                        3:bit_value=(idx==w*h-1);
                        4:bit_value=1;
                        5:bit_value=(xx>=w-2 && yy>=h-2);
                        6:bit_value=(idx==0 || idx==w*h-1);
                        default:$fatal(1,"unknown pattern");
                    endcase
                    rgb_value=(pattern==7)?24'h28c828:(bit_value?24'hc82828:24'h000000);
                    if (pattern==3 && idx==w*h-3) $dumpon;
                    if (pattern==4 && w==1280 && idx==3) $dumpoff;
                    if (pattern==4 && w==1280 && idx==w*h-3) $dumpon;
                    if (config_id==1 && idx==3) $dumpoff;
                    beat(1,1,bit_value,(abort_at<0 || idx<abort_at),rgb_value,xx,yy,
                        idx==0,xx==w-1,idx==w*h-1);
                end
                // Back-to-back EOF/SOF, including 1x1 frames; inter-line gaps only.
                if (yy<h-1) for (k=0;k<1+(yy%3);k=k+1) beat(1,0,0,0,0,0,0,0,0,0);
            end
        end
        for (k=0;k<20;k=k+1) beat(1,0,0,0,0,0,0,0,0,0);
        $fclose(config_file); $fclose(actual_file); $fclose(timing_file);
        $display("C3_SIM_COMPLETE cycles=%0d",cycle);$finish;
    end
endmodule
