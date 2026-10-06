`timescale 1ns/1ps
module tb_color_mask_stream;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, pixel_valid=0;
    reg [23:0] rgb=0;
    reg [1:0] active_color=0;
    reg [10:0] x=0,y=0;
    reg sof=0,eol=0,eof=0;
    reg [31:0] source_frame_id=0;
    wire mask_valid,mask,mask_sof,mask_eol,mask_eof;
    wire [10:0] mask_x,mask_y;
    wire [31:0] mask_frame_id;
    color_mask_stream dut(clk,rst_n,pixel_valid,rgb,active_color,x,y,sof,eol,eof,
        source_frame_id,mask_valid,mask,mask_x,mask_y,mask_sof,mask_eol,mask_eof,mask_frame_id);
    wire [58:0] packet={mask_valid,mask,mask_sof,mask_eol,mask_eof,mask_x,mask_y,mask_frame_id};
    reg [58:0] previous_packet=0;
    reg first=1;
    integer cfg,actual,n,w,h,color,pattern,abort_at,xx,yy,index,blanks,k;
    reg [31:0] fid;
    reg [7:0] r,g,b;
    reg [23:0] value;
    reg [31:0] hash_value;
    integer cycles=0;
    initial begin #100000000; $fatal(1,"watchdog timeout"); end

    task beat;
        input reset_value, valid_value, expected_valid;
        input [23:0] rgb_value;
        input integer px,py;
        input s,l,f;
        begin
            @(negedge clk);
            if (!first && packet !== previous_packet) $fatal(1,"output hold failure");
            rst_n=reset_value; pixel_valid=valid_value; rgb=rgb_value;
            x=px; y=py; sof=s; eol=l; eof=f;
            #1;
            if (!rst_n && packet !== 59'b0) $fatal(1,"reset failure");
            if (rst_n && !first && packet !== previous_packet) $fatal(1,"early output");
            @(posedge clk); #1;
            if (^packet === 1'bx) $fatal(1,"unknown output");
            if (mask_valid !== expected_valid) $fatal(1,"valid mismatch");
            if (expected_valid) begin
                if ({mask_x,mask_y,mask_sof,mask_eol,mask_eof,mask_frame_id} !==
                    {x,y,sof,eol,eof,source_frame_id}) $fatal(1,"metadata misalignment");
                $fdisplay(actual,"%h",{mask,mask_sof,mask_eol,mask_eof,mask_x,mask_y,mask_frame_id});
            end else if (packet !== 59'b0) $fatal(1,"invalid output not cleared");
            previous_packet=packet; first=0; cycles=cycles+1;
        end
    endtask

    initial begin
        cfg=$fopen("cases.txt","r"); actual=$fopen("actual.hex","w");
        if (!cfg || !actual) $fatal(1,"file open failed");
        beat(0,0,0,0,0,0,0,0,0);
        // A tail of a frame before the first SOF must be ignored.
        beat(1,1,0,24'hc82828,7,2,0,1,1);
        while (!$feof(cfg)) begin
            n=$fscanf(cfg,"%d %d %h %d %d %d\n",w,h,fid,color,pattern,abort_at);
            if (n!=6) $fatal(1,"bad case file");
            active_color=color; source_frame_id=fid;
            for (yy=0;yy<h;yy=yy+1) begin
                for (xx=0;xx<w;xx=xx+1) begin
                    index=yy*w+xx;
                    if (index==abort_at) beat(0,0,0,0,0,0,0,0,0);
                    value=0;
                    case (pattern)
                        0,1: if (xx>=100 && xx<=140 && yy>=80 && yy<=110)
                            value=(pattern==0)?24'hc82828:24'h28c828;
                        2: case ((xx*6)/w)
                            0:value=24'hc82828; 1:value=24'h28c828; 2:value=24'h2828c8;
                            3:value=24'h000000; 4:value=24'hffffff; 5:value=24'h808080;
                        endcase
                        3: if (xx<=8 && yy<=6) value=24'hc82828;
                        4: begin
                            hash_value=(index+20261005)*32'd1664525+32'd1013904223;
                            r=hash_value[31:24]; g=hash_value[23:16]; b=hash_value[15:8];
                            value={r,g,b};
                        end
                        5:value=24'h28c828;
                    endcase
                    beat(1,1,(abort_at<0 || index<abort_at),value,xx,yy,
                        index==0,xx==w-1,index==w*h-1);
                end
                blanks=1+((yy+pattern)%4);
                for (k=0;k<blanks;k=k+1) beat(1,0,0,0,0,0,0,0,0);
            end
            for (k=0;k<3+pattern;k=k+1) beat(1,0,0,0,0,0,0,0,0);
        end
        // Stop input while clock continues: no stale mask data may emerge.
        for (k=0;k<20;k=k+1) beat(1,0,0,0,0,0,0,0,0);
        $fclose(cfg); $fclose(actual);
        $display("C2_SIM_COMPLETE cycles=%0d",cycles); $finish;
    end
endmodule
