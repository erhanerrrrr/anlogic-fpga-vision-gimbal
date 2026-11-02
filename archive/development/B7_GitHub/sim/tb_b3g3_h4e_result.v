`timescale 1ns/1ps
// Real unchanged H4E region selector + strict-source display snapshot.
// A's epoch input is synthetic here because the frozen H4E module has none.
module tb_b3g3_h4e_result;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,stream_abort=0;
    reg mask_valid=0,mask=0,sof=0,eof=0;
    reg [10:0] x=0,y=0;
    reg [31:0] frame_id=0;
    reg pixel_valid=0,pixel_sof=0;
    reg [31:0] pixel_epoch=9,pixel_frame_id=0;
    reg [15:0] pixel_cfg_id=3;
    reg [1:0] pixel_target_id=0;
    reg source_timeout=0,result_timeout=0;
    wire result_strobe,target_valid;
    wire [2:0] reason;
    wire [31:0] result_frame_id;
    wire [15:0] result_cfg_id;
    wire [1:0] result_target_id;
    wire [19:0] area;
    wire [10:0] xmin,xmax,ymin,ymax,cx,cy;
    wire [7:0] labels_used;
    wire [11:0] components;
    wire busy;
    h4e_region_select #(.WIDTH(32),.HEIGHT(32),.MIN_AREA(256)) c_result(
        .clk(clk),.rst_n(rst_n),.mask_valid(mask_valid),.mask(mask),
        .sof(sof),.eof(eof),.x(x),.y(y),.frame_id(frame_id),
        .cfg_id(16'd3),.target_id(2'd0),.result_strobe(result_strobe),
        .target_valid(target_valid),.reason(reason),.result_frame_id(result_frame_id),
        .result_cfg_id(result_cfg_id),.result_target_id(result_target_id),
        .area(area),.xmin(xmin),.xmax(xmax),.ymin(ymin),.ymax(ymax),
        .cx(cx),.cy(cy),.labels_used(labels_used),.components(components),.busy(busy));
    wire [159:0] result_packet={result_frame_id,result_cfg_id,result_target_id,
        target_valid,area,xmin,ymin,xmax,ymax,cx,cy,reason,labels_used,components};
    wire completed_ready;
    wire [31:0] completed_refresh_id;
    wire [15:0] expected_cfg_id;
    wire [1:0] expected_target_id;
    // H4E does not output epoch; this sideband is test-only until A binds it
    // atomically to the real captured source and resulting C packet.
    capture_target_gate gate_dut(.clk(clk),.rst_n(rst_n),.stream_abort(stream_abort),
        .pixel_valid(pixel_valid),.pixel_sof(pixel_sof),
        .pixel_epoch(pixel_epoch),.pixel_frame_id(pixel_frame_id),
        .pixel_cfg_id(pixel_cfg_id),.pixel_target_id(pixel_target_id),
        .result_strobe(result_strobe),.result_epoch(32'd9),
        .result_frame_id(result_frame_id),.result_cfg_id(result_cfg_id),
        .result_target_id(result_target_id),.source_timeout(source_timeout),
        .result_timeout(result_timeout),.completed_ready(completed_ready),
        .completed_refresh_id(completed_refresh_id),
        .expected_cfg_id(expected_cfg_id),.expected_target_id(expected_target_id));
    wire pixel_frame_open,pixel_ready;
    wire [159:0] pixel_packet;
    b1_target_snapshot #(.WIDTH(32),.HEIGHT(32)) snapshot(
        .clk(clk),.rst_n(rst_n),.stream_abort(stream_abort),
        .pixel_valid(pixel_valid),.pixel_sof(pixel_sof),
        .result_strobe(result_strobe),.result_packet(result_packet),
        .completed_ready(completed_ready),.completed_refresh_id(completed_refresh_id),
        .expected_cfg_id(expected_cfg_id),.expected_target_id(expected_target_id),
        .pixel_frame_open(pixel_frame_open),.pixel_ready(pixel_ready),
        .pixel_packet(pixel_packet));
    integer result_events=0;
    always @(posedge clk) begin
        #2;
        if(rst_n && result_strobe)result_events=result_events+1;
    end
    task blank;
        input integer cycles;
        integer k;
        begin
            for(k=0;k<cycles;k=k+1)begin
                @(negedge clk);mask_valid=0;sof=0;eof=0;
                pixel_valid=0;pixel_sof=0;
            end
        end
    endtask
    task display_sof;
        input [31:0] id,epoch;
        input expected_ready,expected_valid;
        input [2:0] expected_reason;
        begin
            @(negedge clk);pixel_valid=1;pixel_sof=1;
            pixel_frame_id=id;pixel_epoch=epoch;
            #1;
            if(pixel_ready!==expected_ready || completed_ready!==expected_ready ||
               pixel_packet[109]!==expected_valid || pixel_packet[22:20]!==expected_reason)
                $fatal(1,"display SOF %0d epoch %0d got ready=%b valid=%b reason=%0d",
                    id,epoch,pixel_ready,pixel_packet[109],pixel_packet[22:20]);
            if(expected_valid && (pixel_packet[108:89]!==20'd400 ||
                pixel_packet[88:78]!==11'd5 || pixel_packet[77:67]!==11'd5 ||
                pixel_packet[66:56]!==11'd24 || pixel_packet[55:45]!==11'd24 ||
                pixel_packet[44:34]!==11'd14 || pixel_packet[33:23]!==11'd14))
                $fatal(1,"C geometry not delivered atomically: %h",pixel_packet);
            @(posedge clk);#3;
            pixel_sof=0;pixel_valid=0;
        end
    endtask
    task send_mask_frame;
        input [31:0] id;
        input has_box;
        integer xx,yy;
        begin
            frame_id=id;
            for(yy=0;yy<32;yy=yy+1)begin
                for(xx=0;xx<32;xx=xx+1)begin
                    @(negedge clk);mask_valid=1;x=xx;y=yy;
                    mask=has_box && xx>=5 && xx<=24 && yy>=5 && yy<=24;
                    sof=(xx==0 && yy==0);eof=(xx==31 && yy==31);
                end
                if(yy!=31)blank(200);
            end
            @(negedge clk);mask_valid=0;sof=0;eof=0;
        end
    endtask
    task wait_result;
        input [31:0] id;
        input expected_valid;
        input [2:0] expected_reason;
        integer k;
        reg found;
        begin
            found=0;
            for(k=0;k<10000 && !found;k=k+1)begin
                @(posedge clk);#3;
                if(result_strobe)begin
                    found=1;
                    if(result_frame_id!==id || result_cfg_id!==16'd3 ||
                       result_target_id!==2'd0 || target_valid!==expected_valid ||
                       reason!==expected_reason || area!==(expected_valid ? 20'd400 : 20'd0))
                        $fatal(1,"H4E result mismatch id=%0d packet=%h",id,result_packet);
                end
            end
            if(!found)$fatal(1,"H4E result timeout id=%0d",id);
            blank(3);
        end
    endtask
    initial begin
        blank(3);rst_n=1;blank(3);
        display_sof(42,9,0,0,4);  // First display is before C has finished.
        send_mask_frame(42,1);wait_result(42,1,0);
        display_sof(42,9,1,1,0);  // Repeating the same source can draw its box.
        display_sof(43,9,0,0,4);  // A new source cannot reuse frame 42's box.
        display_sof(42,10,0,0,4); // Same frame ID with a new epoch is not equal.
        send_mask_frame(43,0);wait_result(43,0,1);
        display_sof(43,9,1,0,1);  // Empty C result clears the old box.
        if(result_events!=2)$fatal(1,"expected two C events, got %0d",result_events);
        $display("PASS B3G3_H4E_RESULT: two real C packets, repeated-source box and empty-result clearing");
        $finish;
    end
    initial begin #10000000;$fatal(1,"watchdog");end
endmodule
