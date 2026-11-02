`timescale 1ns/1ps
module tb_calibration_text;
    parameter integer WIDTH=976,HEIGHT=160;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,abort=0,v=0,s=0,l=0,e=0;
    reg [10:0] x=0,y=0;
    reg [23:0] rgb=24'h203040;
    reg [83:0] tag=0;
    reg [50:0] status=0;
    wire ov,os,ol,oe;
    wire [10:0] ox,oy;
    wire [23:0] orgb;
    wire [83:0] otag;
    wire [50:0] ostat;
    video_calibration_text dut(.clk(clk),.rst_n(rst_n),.stream_abort(abort),.status_packet(status),
        .in_valid(v),.in_sof(s),.in_eol(l),.in_eof(e),.in_x(x),.in_y(y),.in_rgb(rgb),.in_tag(tag),
        .out_valid(ov),.out_sof(os),.out_eol(ol),.out_eof(oe),.out_x(ox),.out_y(oy),.out_rgb(orgb),.out_tag(otag),.out_status(ostat));
    wire final_valid;
    wire [23:0] final_rgb;
    wire [10:0] final_x,final_y;
    video_target_osd #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) logo_compositor(
        .clk(clk),.rst_n(rst_n),.stream_abort(abort),.in_valid(ov),.in_sof(os),.in_eol(ol),.in_eof(oe),
        .in_x(ox),.in_y(oy),.in_rgb(orgb),.in_refresh_id(otag[31:0]),
        .completed_ready(1'b0),.completed_refresh_id(32'd0),.expected_cfg_id(16'd1),.expected_target_id(2'd0),
        .result_strobe(1'b0),.target_valid(1'b0),.result_frame_id(32'd0),.result_cfg_id(16'd1),.result_target_id(2'd0),
        .area(20'd0),.xmin(11'd0),.ymin(11'd0),.xmax(11'd0),.ymax(11'd0),.cx(11'd0),.cy(11'd0),
        .reason(3'd1),.labels_used(8'd0),.components(12'd0),.out_valid(final_valid),.out_sof(),.out_eol(),.out_eof(),
        .out_x(final_x),.out_y(final_y),.out_rgb(final_rgb),.out_refresh_id(),.out_snapshot_ready(),.out_packet());
    reg [1:0] record_pipe=0;
    integer final_fd,final_pixels=0;
    always @(posedge clk)begin
        if(!rst_n || abort)record_pipe<=0;
        else record_pipe<={record_pipe[0],ov && otag[83]};
        #2;
        if(final_valid && record_pipe[1])begin
            if(final_x!==final_pixels%WIDTH || final_y!==(final_pixels/WIDTH)%HEIGHT)$fatal(1,"final image order");
            $fwrite(final_fd,"%c%c%c",final_rgb[23:16],final_rgb[15:8],final_rgb[7:0]);final_pixels=final_pixels+1;
        end
    end
    reg previous_valid=0,previous_record=0,previous_s,previous_l,previous_e;
    reg [10:0] previous_x,previous_y;
    reg [83:0] previous_tag;
    reg [50:0] previous_status;
    integer fd,frames=0,pixels=0,checks=0,xx,yy;
    task tick;
        input expected_valid,record_pixel;
        input [50:0] expected_status;
        begin
            tag[83]=record_pixel;
            @(posedge clk);#1;
            if(!rst_n || abort)begin
                if(ov!==0 || os!==0 || ol!==0 || oe!==0)$fatal(1,"flush output");
                previous_valid=0;previous_record=0;
            end else begin
                if(ov!==previous_valid)$fatal(1,"valid check=%0d",checks);
                if(os!==(previous_valid && previous_s) || ol!==(previous_valid && previous_l) || oe!==(previous_valid && previous_e))$fatal(1,"markers");
                if(previous_valid)begin
                    if(ox!==previous_x || oy!==previous_y || otag!==previous_tag || ostat!==previous_status)
                        $fatal(1,"metadata/snapshot check=%0d got=%h expected=%h",checks,ostat,previous_status);
                    if(!(oy>=112 && oy<128 || oy>=136 && oy<152) || ox<16 || ox>=976)
                        if(orgb!==24'h203040)$fatal(1,"outside panel modified");
                    if(previous_record)begin $fwrite(fd,"%c%c%c",orgb[23:16],orgb[15:8],orgb[7:0]);pixels=pixels+1;end
                end
                previous_valid=expected_valid;previous_record=record_pixel;
                previous_x=x;previous_y=y;previous_tag=tag;previous_status=expected_status;
                previous_s=s;previous_l=l;previous_e=e;
            end
            checks=checks+1;@(negedge clk);tag=tag+84'h123456789abcdef012345;
        end
    endtask
    task frame;
        input [50:0] initial_status,mid_status;
        begin
            status=initial_status;
            for(yy=0;yy<HEIGHT;yy=yy+1)begin
                for(xx=0;xx<WIDTH;xx=xx+1)begin
                    x=xx;y=yy;v=1;s=xx==0 && yy==0;l=xx==WIDTH-1;e=l && yy==HEIGHT-1;
                    if(xx==0 && yy==80)status=mid_status;
                    tick(1,1,initial_status);
                end
                v=0;s=0;l=0;e=0;tick(0,0,initial_status);
            end
            tick(0,0,initial_status);frames=frames+1;
        end
    endtask
    initial begin
        fd=$fopen("actual.rgb","wb");final_fd=$fopen("with_logo.rgb","wb");if(!fd || !final_fd)$fatal(1,"output");
        @(negedge clk);tick(0,0,0);rst_n=1;v=1;x=100;y=113;tick(0,0,0);
        `include "text_scenarios.vh"
        v=0;s=0;tick(0,0,0);tick(0,0,0); // drain the downstream Logo pipeline
        // Mid-frame abort discards pipeline and requires a fresh valid SOF.
        v=1;s=0;abort=1;tick(0,0,0);abort=0;tick(0,0,0);
        v=0;s=1;tick(0,0,0);v=1;s=0;tick(0,0,0);
        status=51'h7000000000000;s=1;tick(1,0,status);s=0;tick(1,0,status);
        rst_n=0;tick(0,0,0);rst_n=1;tick(0,0,0);
        v=0;s=0;tick(0,0,0);$fclose(fd);$fclose(final_fd);
        if(pixels!=frames*WIDTH*HEIGHT || final_pixels!=pixels)$fatal(1,"pixel count text=%0d logo=%0d",pixels,final_pixels);
        $display("PASS CALIBRATION_TEXT: frames=%0d pixels=%0d checks=%0d",frames,pixels,checks);$finish;
    end
endmodule
