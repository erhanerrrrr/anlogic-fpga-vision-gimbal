`timescale 1ns/1ps
module tb_h4e;
    reg clk=0,rst=0;
    wire de,usr,last,hs,vs;
    reg [23:0] rgb=0;
    wire rd,ode,ohs,ovs;
    wire [23:0] out_rgb;
    integer sx=0,sy=0,frame=0,results=0,pixels=0,display_pixels=0,cycles=0;
    integer expect_area,expect_x,expect_y,expect_xmin,expect_xmax,expect_ymin,expect_ymax;
    integer qx[0:3],qy[0:3];
    reg [3:0] qde=0,qhs=0,qvs=0,qknown=0,qmask=0;
    reg known=0;
    reg [23:0] exp_rgb;
    integer j;
    reg [86:0] previous_display=0;
    integer green_pixels=0, cyan_pixels=0;
    integer ra,rl,rr,rt,rb;
    integer filter_pixels=0, fx=0,fy=0,ff=1;
    reg input_sof;
    integer metrics_results=0,ew,eh,eb,ep,di;
    reg [55:0] previous_diag=0;
    reg [7:0] dh,dt,du;
    initial begin
        #2;
        for(di=0;di<=100;di=di+1)begin
            dh=48+di/100;dt=48+(di/10)%10;du=48+di%10;
            if(dut.u_mixer.decimal_percent(di)!=={dh,dt,du})$fatal(1,"Decimal display conversion %d",di);
        end
    end
    always #5 clk=~clk;
    // The exact native board timing generator, including its USER/LAST delays.
    uivtc #(.H_ActiveSize(1280),.H_FrameSize(1650),.H_SyncStart(1390),.H_SyncEnd(1430),
            .V_ActiveSize(720),.V_FrameSize(750),.V_SyncStart(725),.V_SyncEnd(730))
        timing(rst,clk,vs,hs,de,usr,last);
    h3d3_display_path dut(.I_clk(clk),.I_rst_n(rst),.I_video_vsync(vs),.I_video_hsync(hs),
        .I_video_de(de),.I_video_user(usr),.I_video_last(last),.I_debug_status(4'd0),
        .I_video_rd_data(rgb),.O_video_rd_en(rd),.O_hdmi_vsync(ovs),.O_hdmi_hsync(ohs),
        .O_hdmi_de(ode),.O_hdmi_data(out_rgb));

    reg [24:0] logo_ref[0:25599];
    reg [24:0] lp;
    integer logo_pixels=0,gate_results=0;
    integer gate_area,gate_reason;
    reg [45:0] previous_gate_display=0;
    reg [63:0] previous_region_snapshot=0;
    integer tu,tc;
    initial $readmemh("assets/logo_reference.hex",logo_ref);
    reg raw_mem[0:13*1280*720-1],filtered_mem[0:13*1280*720-1];
    reg [159:0] fs[0:13],rs[0:13];
    reg [351:0] ts[0:13];
    integer tev;
    initial begin
        $readmemb("simulation/pipeline_raw.mem",raw_mem);
        $readmemb("simulation/pipeline_filtered.mem",filtered_mem);
        $readmemh("simulation/f_stats.mem",fs);$readmemh("simulation/r_stats.mem",rs);
        $readmemh("simulation/t_stats.mem",ts);
    end
    function target_pixel;
        input integer f,x,y;
        begin target_pixel=(f>=1&&f<=13&&x>=0&&x<1280&&y>=0&&y<720)?raw_mem[(f-1)*1280*720+y*1280+x]:0;end
    endfunction
    function filter_reference;
        input integer f,x,y;
        begin filter_reference=(f>=1&&f<=13)?filtered_mem[(f-1)*1280*720+y*1280+x]:0;end
    endfunction
    task raw_expected;
        input integer f;
        begin {ra,rl,rr,rt,rb}=rs[f];end
    endtask
    task set_expected;
        input integer f;
        begin
            {expect_area,expect_xmin,expect_xmax,expect_ymin,expect_ymax}=fs[f];
            expect_x=(expect_xmin+expect_xmax)/2;expect_y=(expect_ymin+expect_ymax)/2;
        end
    endtask
    task set_selected;
        input integer f;
        begin
            {tev,gate_reason,expect_area,expect_xmin,expect_xmax,expect_ymin,expect_ymax,expect_x,expect_y,tu,tc}=ts[f];
            gate_area=expect_area;
        end
    endtask

    integer row_work=0,max_row_work=0,eof_wait=0,max_eof_wait=0;
    reg waiting_region=0;
    always @(posedge clk)begin
        #2;
        if(dut.region_busy)begin row_work=row_work+1;if(row_work>max_row_work)max_row_work=row_work;end
        else row_work=0;
        if(dut.filtered_valid && dut.filtered_eof)begin waiting_region=1;eof_wait=0;end
        if(waiting_region)eof_wait=eof_wait+1;
        if(dut.accepted_strobe)begin
            waiting_region=0;if(eof_wait>max_eof_wait)max_eof_wait=eof_wait;
        end
    end
    // Track the native stream independently of DUT counters. LAST advances rows.
    always @(negedge clk) begin
        if(!rst) begin sx=0;sy=0;frame=0;known=0;rgb=0;end
        else begin
            if(usr)begin sx=0;sy=0;frame=frame+1;known=1;end
            rgb=target_pixel(frame,sx,sy)?24'h250705:24'h606060;
        end
    end
    always @(posedge clk) begin
        if(!rst)begin
            qde=0;qhs=0;qvs=0;qknown=0;qmask=0;previous_display=0;
            for(j=0;j<4;j=j+1)begin qx[j]=0;qy[j]=0;end
        end else begin
            input_sof=known&&de&&usr;
            if(known&&de)begin
                if(dut.native_valid!==1 || dut.native_x!=sx || dut.native_y!=sy ||
                   dut.native_sof!==(sx==0&&sy==0) || dut.native_eof!==(sx==1279&&sy==719) ||
                   dut.native_refresh_id!=frame) $fatal(1,"Metadata frame%0d x%0d y%0d",frame,sx,sy);
                if(last!==(sx==1279))$fatal(1,"Native LAST not on last pixel");
                pixels=pixels+1;
            end
            for(j=3;j>0;j=j-1)begin qx[j]=qx[j-1];qy[j]=qy[j-1];end
            qx[0]=sx;qy[0]=sy;
            qde={qde[2:0],de};qhs={qhs[2:0],hs};qvs={qvs[2:0],vs};
            qknown={qknown[2:0],known&&de};qmask={qmask[2:0],target_pixel(frame,sx,sy)};
            if(known&&de)begin
                if(last)begin sx=0;sy=sy+1;end else sx=sx+1;
            end
            #1;cycles=cycles+1;
            if(rd!==de)$fatal(1,"DDR request shifted");
            if(cycles>5 && {ovs,ohs,ode}!={qvs[3],qhs[3],qde[3]})$fatal(1,"HDMI control latency");
            if(qknown[3]&&qde[3])begin
                if(^out_rgb===1'bx)$fatal(1,"Unknown HDMI RGB");
                if(qy[3]>=192)begin
                    exp_rgb=qmask[3]?24'hffffff:24'h000000;
                    if(((qx[3]==511||qx[3]==768)&&qy[3]>=231&&qy[3]<=488)||
                       ((qy[3]==231||qy[3]==488)&&qx[3]>=511&&qx[3]<=768))exp_rgb=24'hffff00;
                    if(qx[3]>=1104 && qx[3]<1264 && qy[3]>=16 && qy[3]<176)begin
                        lp=logo_ref[(qy[3]-16)*160+qx[3]-1104];
                        if(lp[24])exp_rgb=lp[23:0];
                    end
                    // Independent integer reference uses known previous-frame fixtures.
                    raw_expected(frame-1);
                    if(ra>0 && qx[3]>=rl && qx[3]<=rr && qy[3]>=rt && qy[3]<=rb &&
                       (qx[3]==rl || qx[3]==rr || qy[3]==rt || qy[3]==rb))exp_rgb=24'hff8000;
                    set_selected(frame-1);
                    if(expect_area>=256) begin
                        if(qx[3]>=expect_xmin && qx[3]<=expect_xmax && qy[3]>=expect_ymin && qy[3]<=expect_ymax &&
                           (qx[3]==expect_xmin || qx[3]==expect_xmin+1 || qx[3]==expect_xmax || qx[3]==expect_xmax-1 ||
                            qy[3]==expect_ymin || qy[3]==expect_ymin+1 || qy[3]==expect_ymax || qy[3]==expect_ymax-1)) exp_rgb=24'h00ff00;
                        if((qx[3]>=expect_x-8 && qx[3]<=expect_x+8 && qy[3]>=expect_y-1 && qy[3]<=expect_y+1) ||
                           (qx[3]>=expect_x-1 && qx[3]<=expect_x+1 && qy[3]>=expect_y-8 && qy[3]<=expect_y+8)) exp_rgb=24'h00ffff;
                    end
                    if(exp_rgb==24'h00ff00)green_pixels=green_pixels+1;
                    if(exp_rgb==24'h00ffff)cyan_pixels=cyan_pixels+1;
                    if(out_rgb!==exp_rgb)$fatal(1,"Mask/ROI pixel mismatch x=%d y=%d actual=%h expected=%h",qx[3],qy[3],out_rgb,exp_rgb);
                    display_pixels=display_pixels+1;
                end
            end
            if(qknown[3]&&qde[3] && qx[3]>=1104 && qx[3]<1264 && qy[3]>=16 && qy[3]<176)begin
                lp=logo_ref[(qy[3]-16)*160+qx[3]-1104];
                if(lp[24])begin
                    if(out_rgb!==lp[23:0])$fatal(1,"Logo changed");
                    logo_pixels=logo_pixels+1;
                end
            end
            if(dut.metrics_strobe)begin
                metrics_results=metrics_results+1;set_expected(metrics_results);
                ew=expect_area>0 ? expect_xmax-expect_xmin+1 : 0;
                eh=expect_area>0 ? expect_ymax-expect_ymin+1 : 0;
                eb=ew*eh;ep=eb>0 ? expect_area*100/eb : 0;
                if(dut.metrics_frame_id!=metrics_results || dut.metrics_valid!==(expect_area>0) ||
                   dut.metrics_width!=ew || dut.metrics_height!=eh || dut.metrics_box_area!=eb || dut.metrics_percent!=ep)
                    $fatal(1,"Metrics mismatch %0d",metrics_results);
                $display("DIAG %0d W=%0d H=%0d B=%0d PCT=%0d PASS",metrics_results,ew,eh,eb,ep);$fflush();
            end
            if(input_sof)begin
                set_expected(frame-1);
                ew=expect_area>0 ? expect_xmax-expect_xmin+1 : 0;
                eh=expect_area>0 ? expect_ymax-expect_ymin+1 : 0;
                eb=ew*eh;ep=eb>0 ? expect_area*100/eb : 0;
                if(dut.diag_display_valid!==(expect_area>0) || dut.diag_display_width!=ew || dut.diag_display_height!=eh ||
                   dut.diag_display_box_area!=eb || dut.diag_display_percent!=ep || dut.metrics_busy)
                    $fatal(1,"Diagnostic snapshot incomplete/wrong at SOF");
            end else if({dut.diag_display_valid,dut.diag_display_width,dut.diag_display_height,dut.diag_display_box_area,dut.diag_display_percent}!==previous_diag)
                $fatal(1,"Diagnostics changed within display frame");
            previous_diag={dut.diag_display_valid,dut.diag_display_width,dut.diag_display_height,dut.diag_display_box_area,dut.diag_display_percent};
            if(dut.accepted_strobe)begin
                gate_results=gate_results+1;
                set_selected(gate_results);
                if(dut.region_labels!=tu || dut.region_components!=tc)$fatal(1,"Region counts mismatch");
                if(dut.accepted_xmin!=expect_xmin || dut.accepted_xmax!=expect_xmax ||
                   dut.accepted_ymin!=expect_ymin || dut.accepted_ymax!=expect_ymax)$fatal(1,"Selected boundary mismatch");
                if(dut.accepted_valid!==(gate_area>0) || dut.accepted_area!=gate_area ||
                   dut.reject_reason!=gate_reason || dut.accepted_frame_id!=gate_results ||
                   dut.accepted_cfg_id!=1 || dut.accepted_target_id!=0)
                    $fatal(1,"Accepted result mismatch frame %d",gate_results);
                if(gate_area==0 && {dut.accepted_cx,dut.accepted_cy,dut.accepted_xmin,dut.accepted_xmax,dut.accepted_ymin,dut.accepted_ymax}!==0)
                    $fatal(1,"Rejected geometry not zero");
                if(gate_area>0 && (dut.accepted_cx!=expect_x || dut.accepted_cy!=expect_y))$fatal(1,"Accepted center changed");
                $display("T RESULT %0d F_area=%0d T_area=%0d reason=%0d PASS",gate_results,expect_area,gate_area,gate_reason);
                $fflush();
            end
            if(input_sof)begin
                set_selected(frame-1);
                if(dut.region_busy)$fatal(1,"Region not ready by next SOF");
                if(dut.gate_display_labels!=tu || dut.gate_display_components!=tc ||
                   dut.gate_display_xmin!=expect_xmin || dut.gate_display_xmax!=expect_xmax ||
                   dut.gate_display_ymin!=expect_ymin || dut.gate_display_ymax!=expect_ymax)$fatal(1,"Selected snapshot mismatch");
                if(dut.gate_display_valid!==(gate_area>0) || dut.gate_display_area!=gate_area || dut.gate_display_reason!=gate_reason ||
                   dut.gate_display_cx!=(gate_area>0 ? expect_x : 0) || dut.gate_display_cy!=(gate_area>0 ? expect_y : 0))
                    $fatal(1,"T frame snapshot mismatch");
            end else if({dut.gate_display_valid,dut.gate_display_reason,dut.gate_display_area,dut.gate_display_cx,dut.gate_display_cy}!==previous_gate_display)
                $fatal(1,"T snapshot changed within frame");
            previous_gate_display={dut.gate_display_valid,dut.gate_display_reason,dut.gate_display_area,dut.gate_display_cx,dut.gate_display_cy};
            if(!input_sof && {dut.gate_display_labels,dut.gate_display_components,dut.gate_display_xmin,dut.gate_display_xmax,dut.gate_display_ymin,dut.gate_display_ymax}!==previous_region_snapshot)
                $fatal(1,"Selected geometry changed within frame");
            previous_region_snapshot={dut.gate_display_labels,dut.gate_display_components,dut.gate_display_xmin,dut.gate_display_xmax,dut.gate_display_ymin,dut.gate_display_ymax};
            // The mixer's USER is delayed by the classifier stage. Check the held
            // ROI after that stage has published, not on the native SOF edge.
            if(frame>1 && qknown[3] && qde[3] && qx[3]==8 && qy[3]==0 && dut.u_mixer.held_count!=65536)
                $fatal(1,"ROI count changed");
            if(cycles>5&&!ode&&out_rgb!==0)$fatal(1,"Nonzero blanking");
            if(dut.pixel_valid && dut.meta_valid_d &&
                dut.guarded_mask!==(dut.mask && dut.y_d>=4 && dut.y_d<716))$fatal(1,"Guard removed wrong rows");
            if(dut.filtered_valid)begin
                if(dut.filtered_x!=fx || dut.filtered_y!=fy || dut.filtered_frame_id!=ff ||
                   dut.filtered_cfg_id!=1 || dut.filtered_target_id!=0 ||
                   dut.filtered_sof!==(fx==0&&fy==0) || dut.filtered_eol!==(fx==1279) ||
                   dut.filtered_eof!==(fx==1279&&fy==719) || dut.filtered_mask!==filter_reference(ff,fx,fy))
                    $fatal(1,"Filtered stream f=%0d x=%0d y=%0d mask=%b",ff,fx,fy,dut.filtered_mask);
                filter_pixels=filter_pixels+1;
                if(fx==1279)begin fx=0;if(fy==719)begin fy=0;ff=ff+1;end else fy=fy+1;end else fx=fx+1;
            end
            if(dut.result_strobe)begin
                results=results+1;
                set_expected(results);
                if(dut.result_refresh_id!=results || dut.result_cfg_id!=1 || dut.target_id!=0 ||
                    dut.target_valid!==(expect_area!=0) || dut.area!=expect_area ||
                    dut.cx!=expect_x || dut.cy!=expect_y || dut.xmin!=expect_xmin || dut.xmax!=expect_xmax ||
                    dut.ymin!=expect_ymin || dut.ymax!=expect_ymax)$fatal(1,"Geometry result %0d mismatch area=%d cx=%d cy=%d",results,dut.area,dut.cx,dut.cy);
                $display("RESULT %0d area=%0d cx=%0d cy=%0d PASS",results,dut.area,dut.cx,dut.cy);
            end
            if(input_sof)begin
                raw_expected(frame-1);
                if(dut.raw_display_valid!==(ra>0) || dut.raw_display_area!=ra || dut.raw_display_xmin!=rl ||
                   dut.raw_display_xmax!=rr || dut.raw_display_ymin!=rt || dut.raw_display_ymax!=rb)
                    $fatal(1,"Raw snapshot mismatch");
                set_expected(frame-1);
                if(dut.display_area!=expect_area || dut.display_cx!=expect_x || dut.display_cy!=expect_y ||
                   dut.display_valid!==(expect_area!=0) || dut.display_xmin!=expect_xmin || dut.display_xmax!=expect_xmax ||
                   dut.display_ymin!=expect_ymin || dut.display_ymax!=expect_ymax)$fatal(1,"Previous frame snapshot wrong");
            end else if({dut.display_valid,dut.display_area,dut.display_cx,dut.display_cy,dut.display_xmin,dut.display_xmax,dut.display_ymin,dut.display_ymax}!==previous_display)
                $fatal(1,"Display fields changed during frame");
            previous_display={dut.display_valid,dut.display_area,dut.display_cx,dut.display_cy,dut.display_xmin,dut.display_xmax,dut.display_ymin,dut.display_ymax};
            if(frame==14&&input_sof)begin
                if(filter_pixels!=13*1280*720 || results!=13 || display_pixels!=13*1280*(720-192) || green_pixels==0 || cyan_pixels==0)$fatal(1,"Coverage mismatch %d %d",results,display_pixels);
                $display("FILTERED pixels=%0d; isolated/2x2/line noise removed, rectangle center unchanged",filter_pixels);
                $display("OVERLAY green=%0d cyan=%0d",green_pixels,cyan_pixels);
                $display("PASS H4E: 13 complete native 720p frames, %0d metadata pixels, %0d HDMI mask/ROI pixels; moving rectangle, first/last corners, empty, full frame, held snapshot, sync and DDR",pixels,display_pixels);
                if(logo_pixels!=83031)$fatal(1,"Logo coverage %0d",logo_pixels);
                if(gate_results!=13)$fatal(1,"Missing gate results");
                $display("LOGO opaque pixels=%0d, area rejection/recovery and snapshots PASS",logo_pixels);
                if(metrics_results!=13)$fatal(1,"Missing diagnostic results");
                $display("PASS DIAG: metrics and frame-matched display snapshots; decimal 000..100");
                $display("ROW_ENGINE max_row_cycles=%0d max_EOF_wait=%0d",max_row_work,max_eof_wait);
                $finish;
            end
        end
    end
    initial begin repeat(8)@(negedge clk);rst=1;end
    initial begin #220000000;$fatal(1,"watchdog");end
endmodule
