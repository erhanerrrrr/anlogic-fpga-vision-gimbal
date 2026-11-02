`timescale 1ns/1ps
module tb_capture_target_gate;
    reg clk=0; always #5 clk=~clk;
    reg rst_n=0,stream_abort=0,pixel_valid=0,pixel_sof=0;
    reg [31:0] pixel_epoch=0,pixel_frame_id=0;
    reg [15:0] pixel_cfg_id=0;
    reg [1:0] pixel_target_id=0;
    reg result_strobe=0,source_timeout=0,result_timeout=0;
    reg [31:0] result_epoch=0,result_frame_id=0;
    reg [15:0] result_cfg_id=0;
    reg [1:0] result_target_id=0;
    reg [159:0] result_packet=0;
    wire completed_ready,pixel_frame_open,pixel_ready;
    wire [31:0] completed_refresh_id;
    wire [15:0] expected_cfg_id;
    wire [1:0] expected_target_id;
    wire [159:0] pixel_packet;
    integer checks=0;
    capture_target_gate gate_dut(.*);
    b1_target_snapshot #(.WIDTH(1280),.HEIGHT(720)) snapshot(
        .clk(clk),.rst_n(rst_n),.stream_abort(stream_abort),
        .pixel_valid(pixel_valid),.pixel_sof(pixel_sof),
        .result_strobe(result_strobe),.result_packet(result_packet),
        .completed_ready(completed_ready),.completed_refresh_id(completed_refresh_id),
        .expected_cfg_id(expected_cfg_id),.expected_target_id(expected_target_id),
        .pixel_frame_open(pixel_frame_open),.pixel_ready(pixel_ready),.pixel_packet(pixel_packet));
    function [159:0] packet;
        input [31:0] frame_id;
        input [15:0] cfg;
        input [1:0] target;
        input valid;
        begin
            packet={frame_id,cfg,target,valid,valid ? 20'd500 : 20'd0,
                valid ? 11'd100 : 11'd0,valid ? 11'd200 : 11'd0,
                valid ? 11'd199 : 11'd0,valid ? 11'd299 : 11'd0,
                valid ? 11'd149 : 11'd0,valid ? 11'd249 : 11'd0,
                valid ? 3'd0 : 3'd1,8'd7,12'd2};
        end
    endfunction
    task idle;
        begin
            @(negedge clk);pixel_valid=0;pixel_sof=0;result_strobe=0;
            source_timeout=0;result_timeout=0;stream_abort=0;
        end
    endtask
    task publish;
        input [31:0] ep,fid;
        input [15:0] cfg;
        input [1:0] target;
        input valid;
        begin
            idle();result_strobe=1;result_epoch=ep;result_frame_id=fid;
            result_cfg_id=cfg;result_target_id=target;
            result_packet=packet(fid,cfg,target,valid);
            idle();
        end
    endtask
    task start_frame;
        input [31:0] ep,fid;
        input [15:0] cfg;
        input [1:0] target;
        input expected_ready,expected_target_valid;
        begin
            @(negedge clk);pixel_valid=1;pixel_sof=1;
            pixel_epoch=ep;pixel_frame_id=fid;pixel_cfg_id=cfg;pixel_target_id=target;
            #1;
            if(completed_ready!==expected_ready || pixel_ready!==expected_ready ||
               pixel_frame_open!==1'b1 || pixel_packet[109]!==expected_target_valid ||
               (!expected_ready && pixel_packet[22:20]!==3'd4))
                $fatal(1,"SOF mismatch check=%0d ready=%b/%b target=%b packet=%h",
                    checks,completed_ready,pixel_ready,pixel_packet[109],pixel_packet);
            checks=checks+1;
            @(posedge clk);#1;
            pixel_sof=0;
        end
    endtask
    initial begin
        idle();rst_n=1;
        start_frame(9,42,3,0,0,0);  // No result yet.
        publish(9,42,3,0,1);
        start_frame(9,42,3,0,1,1);
        // A mid-frame result cannot change this frame's snapshot.
        publish(9,43,3,0,1);
        if(pixel_ready!==1 || pixel_packet[159:128]!==32'd42)
            $fatal(1,"frame changed after mid-frame result");
        start_frame(9,42,3,0,0,0);  // Newest result belongs to frame 43.
        start_frame(9,43,3,0,1,1);
        start_frame(10,43,3,0,0,0); // Epoch mismatch.
        start_frame(9,43,4,0,0,0);  // Configuration mismatch.
        start_frame(9,43,3,1,0,0);  // Color mismatch.
        publish(9,44,3,0,0);
        start_frame(9,44,3,0,1,0);  // New invalid result clears box.
        // Result arriving on SOF is held for the following display SOF.
        @(negedge clk);pixel_valid=1;pixel_sof=1;
        pixel_epoch=9;pixel_frame_id=44;pixel_cfg_id=3;pixel_target_id=0;
        result_strobe=1;result_epoch=9;result_frame_id=45;
        result_cfg_id=3;result_target_id=0;result_packet=packet(45,3,0,1);
        #1;
        if(pixel_ready!==1 || pixel_packet[159:128]!==32'd44)
            $fatal(1,"SOF event stole previous snapshot");
        @(posedge clk);#1;pixel_sof=0;
        idle();start_frame(9,45,3,0,1,1);
        @(negedge clk);pixel_valid=1;pixel_sof=1;source_timeout=1;
        #1;if(completed_ready!==0 || pixel_ready!==0)$fatal(1,"source timeout not gated");
        @(posedge clk);#1;pixel_sof=0;
        @(negedge clk);pixel_valid=1;pixel_sof=1;source_timeout=0;result_timeout=1;
        #1;if(completed_ready!==0 || pixel_ready!==0)$fatal(1,"result timeout not gated");
        @(posedge clk);#1;pixel_sof=0;
        idle();stream_abort=1;
        @(posedge clk);#1;
        if(pixel_frame_open!==0 || pixel_ready!==0)$fatal(1,"abort did not clear");
        idle();start_frame(9,45,3,0,0,0);
        publish(9,32'hffffffff,3,0,1);
        start_frame(9,32'hffffffff,3,0,1,1);
        publish(9,0,3,0,1);
        start_frame(9,0,3,0,1,1);   // Natural ID wrap.
        $display("PASS CAPTURE_TARGET_GATE: %0d SOF checks and event/timeout/abort cases",checks);
        $finish;
    end
    initial begin #1000000;$fatal(1,"watchdog");end
endmodule
