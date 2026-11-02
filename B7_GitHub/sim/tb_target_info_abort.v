`timescale 1ns/1ps
module tb_target_info_abort;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,stream_abort=0,in_valid=0,in_sof=0,st=0;
    wire v,s,l,e,ready;
    wire [10:0] x,y;
    wire [23:0] rgb;
    wire [31:0] rid;
    wire [159:0] packet;
    video_target_info dut(.clk(clk),.rst_n(rst_n),.stream_abort(stream_abort),
        .in_valid(in_valid),.in_sof(in_sof),.in_eol(1'b0),.in_eof(1'b0),
        .in_x(11'd0),.in_y(11'd0),.in_rgb(24'h123456),.in_refresh_id(32'd2),
        .completed_ready(1'b1),.completed_refresh_id(32'd1),.expected_cfg_id(16'd1),.expected_target_id(2'd0),
        .result_strobe(st),.target_valid(1'b1),.result_frame_id(32'd1),.result_cfg_id(16'd1),.result_target_id(2'd0),
        .area(20'd10000),.xmin(11'd100),.ymin(11'd200),.xmax(11'd199),.ymax(11'd299),
        .cx(11'd149),.cy(11'd249),.reason(3'd0),.labels_used(8'd7),.components(12'd3),
        .out_valid(v),.out_sof(s),.out_eol(l),.out_eof(e),.out_x(x),.out_y(y),.out_rgb(rgb),
        .out_refresh_id(rid),.out_snapshot_ready(ready),.out_packet(packet));
    task launch_frame;
        begin
            @(negedge clk);st=1;
            @(negedge clk);st=0;in_valid=1;in_sof=1;
            @(negedge clk);in_sof=0;
        end
    endtask
    initial begin
        repeat(3)@(negedge clk);rst_n=1;
        launch_frame();repeat(40)@(negedge clk);
        if(!v || !ready)$fatal(1,"Expected live partial frame");
        stream_abort=1;@(negedge clk);
        if(v || s || l || e || packet!==0 || dut.text_layer.numbers_ready)$fatal(1,"Abort failed");
        stream_abort=0;
        repeat(120)begin @(negedge clk);if(v || dut.text_layer.numbers_ready)$fatal(1,"Frame escaped after abort without SOF");end
        launch_frame();repeat(110)@(negedge clk);
        if(!v || !ready || !dut.text_layer.numbers_ready || dut.text_layer.xb!==16'h0149 ||
           dut.text_layer.yb!==16'h0249 || dut.text_layer.ab!==28'h0010000)$fatal(1,"Recovery failed");
        // Reset between clock edges, while the text/output pipeline is live.
        #2;rst_n=0;#1;
        if(v || packet!==0 || dut.text_layer.numbers_ready)$fatal(1,"Async reset failed");
        @(negedge clk);rst_n=1;
        repeat(120)begin @(negedge clk);if(v)$fatal(1,"Output without new SOF after reset");end
        launch_frame();repeat(110)@(negedge clk);
        if(!v || !ready || !dut.text_layer.numbers_ready)$fatal(1,"Reset recovery failed");
        $display("PASS TEXT ABORT: partial frame, flush, no-SOF suppression, async reset and recovery");$finish;
    end
endmodule
