`timescale 1ns/1ps
module tb_calibration_roi;
    parameter integer WIDTH=1280,HEIGHT=720,LOGO_X=1104,LOGO_Y=16;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,abort=0,request=0,enable=0,v=0,s=0,l=0,e=0;
    reg [10:0] x=0,y=0;
    reg [23:0] rgb=24'h203040;
    reg [31:0] identity=0;
    wire [23:0] roi_rgb,final_rgb;
    wire hit,ov,os,ol,oe;
    wire [10:0] ox,oy;
    wire [31:0] oid;
    video_calibration_roi #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) roi(
        .clk(clk),.rst_n(rst_n),.stream_abort(abort),.roi_req_valid(request),.roi_req_enable(enable),
        .in_valid(v),.in_sof(s),.in_x(x),.in_y(y),.in_rgb(rgb),.out_rgb(roi_rgb),.roi_hit(hit));
    video_target_osd #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.LOGO_X(LOGO_X),.LOGO_Y(LOGO_Y)) osd(
        .clk(clk),.rst_n(rst_n),.stream_abort(abort),.in_valid(v),.in_sof(s),.in_eol(l),.in_eof(e),
        .in_x(x),.in_y(y),.in_rgb(roi_rgb),.in_refresh_id(identity),
        .completed_ready(1'b0),.completed_refresh_id(32'd0),.expected_cfg_id(16'd1),.expected_target_id(2'd0),
        .result_strobe(1'b0),.target_valid(1'b0),.result_frame_id(32'd0),.result_cfg_id(16'd1),.result_target_id(2'd0),
        .area(20'd0),.xmin(11'd0),.ymin(11'd0),.xmax(11'd0),.ymax(11'd0),.cx(11'd0),.cy(11'd0),
        .reason(3'd1),.labels_used(8'd0),.components(12'd0),
        .out_valid(ov),.out_sof(os),.out_eol(ol),.out_eof(oe),.out_x(ox),.out_y(oy),.out_rgb(final_rgb),.out_refresh_id(oid),
        .out_snapshot_ready(),.out_packet());
    reg [24:0] logo [0:25599];
    reg opened=0,previous_valid=0,previous_record=0,previous_s=0,previous_l=0,previous_e=0;
    reg [10:0] previous_x,previous_y;
    reg [31:0] previous_id;
    reg [23:0] previous_rgb;
    integer fd,checks=0,pixels=0,roi_pixels=0,overlaps=0,xx,yy,i;
    reg current_valid,current_hit;
    reg [23:0] current_rgb;
    reg [24:0] logo_pixel;
    // Expected visibility is explicitly specified by each scenario, not read from DUT.
    task tick;
        input expected_enable,record_pixel;
        begin
            #1;
            current_hit=rst_n && !abort && v && expected_enable &&
                WIDTH>=16 && HEIGHT>=16 && x>=(WIDTH-16)/2 && x<=(WIDTH-16)/2+15 &&
                y>=(HEIGHT-16)/2 && y<=(HEIGHT-16)/2+15 &&
                (x==(WIDTH-16)/2 || x==(WIDTH-16)/2+15 || y==(HEIGHT-16)/2 || y==(HEIGHT-16)/2+15);
            if(hit!==current_hit || roi_rgb!==(current_hit ? 24'hffff00 : rgb))
                $fatal(1,"ROI check=%0d xy=%0d,%0d expected_hit=%b got=%b",checks,x,y,current_hit,hit);
            current_valid=v && (opened || s) && x<WIDTH && y<HEIGHT;
            current_rgb=current_hit ? 24'hffff00 : rgb;
            logo_pixel=0;
            if(x>=LOGO_X && x<LOGO_X+160 && y>=LOGO_Y && y<LOGO_Y+160)
                logo_pixel=logo[(y-LOGO_Y)*160+x-LOGO_X];
            if(logo_pixel[24]) current_rgb=logo_pixel[23:0];
            if(record_pixel && current_hit)begin
                roi_pixels=roi_pixels+1;
                if(logo_pixel[24])overlaps=overlaps+1;
            end
            @(posedge clk);#1;
            if(!rst_n || abort)begin
                if(ov!==0 || os!==0 || ol!==0 || oe!==0)$fatal(1,"reset/abort pipeline");
                previous_valid=0;previous_record=0;opened=0;
            end else begin
                if(ov!==previous_valid)$fatal(1,"valid pipeline check %0d",checks);
                if(os!==(previous_valid && previous_s) || ol!==(previous_valid && previous_l) || oe!==(previous_valid && previous_e))
                    $fatal(1,"marker pipeline");
                if(previous_valid)begin
                    if(final_rgb!==previous_rgb || ox!==previous_x || oy!==previous_y || oid!==previous_id)
                        $fatal(1,"OSD mismatch check=%0d xy=%0d,%0d rgb=%h expected=%h",checks,ox,oy,final_rgb,previous_rgb);
                    if(previous_record)begin
                        $fwrite(fd,"%c%c%c",final_rgb[23:16],final_rgb[15:8],final_rgb[7:0]);pixels=pixels+1;
                    end
                end
                previous_valid=current_valid;previous_rgb=current_rgb;previous_record=record_pixel;
                previous_x=x;previous_y=y;previous_s=s;previous_l=l;previous_e=e;previous_id=identity;
                if(v && s)opened=1;
            end
            checks=checks+1;@(negedge clk);identity=identity+1;
        end
    endtask
    initial begin
        $readmemh("logo_reference.hex",logo);fd=$fopen("actual.rgb","wb");
        if(!fd)$fatal(1,"output open");
        @(negedge clk);tick(0,0);rst_n=1;
        x=(WIDTH-16)/2;y=(HEIGHT-16)/2;v=1;tick(0,0); // no SOF, no overlay
        request=1;enable=1;tick(0,0);request=0;tick(0,0);
        s=1;tick(1,0);s=0;tick(1,0);
        request=1;enable=0;tick(1,0);request=0;tick(1,0); // mid-frame stays ON
        v=0;s=1;tick(1,0);v=1;s=0;tick(1,0); // invalid SOF ignored
        s=1;request=1;enable=1;tick(0,0); // simultaneous request deferred
        s=0;request=0;tick(0,0);s=1;tick(1,0);s=0;
        request=1;enable=0;tick(1,0);enable=1;tick(1,0);request=0;
        s=1;tick(1,0);s=0; // latest request wins
        abort=1;tick(0,0);abort=0;tick(0,0);s=1;tick(1,0);s=0;
        rst_n=0;tick(0,0);rst_n=1;s=1;tick(0,0);s=0;
        // Request during abort retained, but waits for recovery SOF.
        abort=1;request=1;enable=1;tick(0,0);abort=0;request=0;tick(0,0);
        s=1;tick(1,0);s=0;
        x=2047;y=2047;tick(1,0);x=WIDTH;y=HEIGHT;tick(1,0);
        // Whole native-size image; mid-frame OFF request must not tear the ROI.
        for(yy=0;yy<HEIGHT;yy=yy+1)begin
            for(xx=0;xx<WIDTH;xx=xx+1)begin
                v=1;x=xx;y=yy;s=(xx==0 && yy==0);l=(xx==WIDTH-1);e=l && yy==HEIGHT-1;
                rgb={xx[7:0],yy[7:0],8'h40};request=(xx==0 && yy==HEIGHT/2);enable=0;
                tick(1,1);
            end
            request=0;v=0;s=0;l=0;e=0;tick(1,0); // line blanking
        end
        v=0;s=0;tick(1,0);tick(1,0);
        x=(WIDTH-16)/2;y=(HEIGHT-16)/2;v=1;s=1;tick(0,0);s=0;tick(0,0);
        if(pixels!=WIDTH*HEIGHT || roi_pixels!=60)$fatal(1,"pixel/ROI count %0d/%0d",pixels,roi_pixels);
        if(WIDTH==160 && overlaps==0)$fatal(1,"Logo overlap scenario missing");
        $fclose(fd);
        $display("PASS CALIBRATION_ROI: checks=%0d pixels=%0d border=60 logo_overlap=%0d",checks,pixels,overlaps);$finish;
    end
endmodule
