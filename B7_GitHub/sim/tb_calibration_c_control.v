`timescale 1ns/1ps
// Real, unmodified C9 control; sample statistics completion is a test stimulus.
module tb_calibration_c_control;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,pv=0,sof=0,req=0,sel=0,sdone=0,params_ok=1;
    reg [31:0] fid=0;
    reg [2:0] why=0;
    wire sreq,busy,ignored,select_ignored,done,ok,applied,pending;
    wire [2:0] reason;
    wire [15:0] cfg;
    wire [1:0] color;
    wire [7:0] main,d1,d2;
    wire [50:0] packet;
    calibration_control #(.INITIAL_CFG_ID(16'hffff)) c(
        .clk(clk),.rst_n(rst_n),.pixel_valid(pv),.sof(sof),.source_frame_id(fid),
        .calibrate_req(req),.color_select_req(sel),.color_select(2'd1),
        .sample_done(sdone),.params_valid(params_ok),.params_reason(why),.sample_frame_id(32'd7),
        .params_color(2'd0),.params_main(8'd168),.params_diff_1(8'd148),.params_diff_2(8'd138),
        .sample_req(sreq),.busy(busy),.request_ignored(ignored),.select_ignored(select_ignored),.ignored_requests(),
        .calibration_done(done),.calibration_ok(ok),.calibration_reason(reason),.calibration_frame_id(),
        .cfg_applied(applied),.pending_valid(pending),.pending_color(),.pending_main(),.pending_diff_1(),.pending_diff_2(),
        .active_color(color),.active_main(main),.active_diff_1(d1),.active_diff_2(d2),.active_cfg_id(cfg),
        .pixel_color(),.pixel_main(),.pixel_diff_1(),.pixel_diff_2(),.pixel_cfg_id());
    calibration_status_view observer(.clk(clk),.rst_n(rst_n),.c_status_valid(1'b1),.sample_req(sreq),.sample_done(sdone),
        .calibration_done(done),.calibration_ok(ok),.calibration_reason(reason),.cfg_applied(applied),.pending_valid(pending),.busy(busy),
        .active_cfg_id(cfg),.active_color(color),.active_main(main),.active_diff_1(d1),.active_diff_2(d2),.status_packet(packet));
    reg dv=0,ds=0;
    wire outv;
    wire [50:0] shown;
    video_calibration_text text(.clk(clk),.rst_n(rst_n),.stream_abort(1'b0),.status_packet(packet),
        .in_valid(dv),.in_sof(ds),.in_eol(1'b0),.in_eof(1'b0),.in_x(11'd0),.in_y(11'd0),.in_rgb(24'd0),.in_tag(84'd0),
        .out_valid(outv),.out_sof(),.out_eol(),.out_eof(),.out_x(),.out_y(),.out_rgb(),.out_tag(),.out_status(shown));
    integer cycles=0,fd;
    task tick;
        input [2:0] expected_phase;
        input [15:0] expected_cfg;
        begin
            @(posedge clk);#1;
            if(packet[49:47]!==expected_phase || packet[41:26]!==expected_cfg)
                $fatal(1,"C observer cycle=%0d phase=%0d cfg=%h expected=%0d/%h",cycles,packet[49:47],packet[41:26],expected_phase,expected_cfg);
            $fwrite(fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",cycles,req,sdone,done,applied,busy,pending,packet[49:47],packet[46:45],packet[41:26],packet[23:16],packet[44:42]);
            cycles=cycles+1;@(negedge clk);
        end
    endtask
    initial begin
        fd=$fopen("c_control_trace.csv","w");$fwrite(fd,"cycle,request,sample_done,calibration_done,cfg_applied,busy,pending,observed_phase,result,observed_cfg,observed_main,reason\n");
        @(negedge clk);tick(6,0);rst_n=1;tick(0,16'hffff);
        if(packet[23:0]!==24'h502828)$fatal(1,"real C startup must remain 80/40/40");
        req=1;sel=1;tick(1,16'hffff);if(!select_ignored)$fatal(1,"calibration priority");
        sel=0;tick(1,16'hffff);if(!ignored)$fatal(1,"busy ignore");req=0;
        // Completion and a NEW source SOF together: must NOT apply parameters yet.
        sdone=1;pv=1;sof=1;fid=1;tick(2,16'hffff);
        if(applied || !pending || !done)$fatal(1,"compute/SOF policy");
        sdone=0;pv=0;sof=0;req=1;tick(3,16'hffff);if(!ignored)$fatal(1,"pending ignore");req=0;
        if(packet[46:45]!==1 || packet[23:0]!==24'h502828)$fatal(1,"pending is not active");
        pv=1;sof=1;fid=1;tick(3,16'hffff);if(applied)$fatal(1,"repeated source ID applied");
        fid=2;req=1;tick(3,16'hffff);if(!applied || !ignored || cfg!==0)$fatal(1,"apply and ignore, cfg wrap");
        req=0;pv=0;sof=0;
        // Display SOF coincides with observer consuming cfg_applied.
        // It must snapshot OLD observer packet, not mixed new active fields.
        dv=1;ds=1;tick(4,0);ds=0;tick(4,0);
        if(!outv || shown[49:47]!==3 || shown[41:26]!==16'hffff)$fatal(1,"same-edge snapshot");
        tick(4,0);if(shown[49:47]!==3)$fatal(1,"midframe status changed");
        ds=1;tick(4,0);ds=0;tick(4,0);
        if(shown[49:47]!==4 || shown[41:26]!==0 || shown[23:0]!==24'ha8948a)$fatal(1,"applied snapshot");dv=0;
        // A later unsuccessful calibration preserves the activity/configuration.
        req=1;tick(1,0);req=0;sdone=1;params_ok=0;why=5;tick(2,0);
        sdone=0;tick(5,0);tick(5,0);
        if(packet[46:45]!==2 || packet[44:42]!==5 || packet[23:0]!==24'ha8948a)$fatal(1,"failure changed active settings");
        // Manual color selection can also have pending/applied config, without calibration OK.
        sel=1;tick(5,0);sel=0;tick(3,0);
        if(packet[46:45]!==0)$fatal(1,"manual selection reused calibration result");
        pv=1;sof=1;fid=3;tick(3,0);pv=0;sof=0;tick(4,1);
        if(packet[25:24]!==1 || packet[23:0]!==24'h502828 || packet[46:45]!==0)$fatal(1,"manual preset observation");
        rst_n=0;tick(6,0);rst_n=1;tick(0,16'hffff);
        $fclose(fd);$display("PASS C_CONTROL_STATUS: cycles=%0d",cycles);$finish;
    end
endmodule
