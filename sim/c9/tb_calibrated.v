`timescale 1ns/1ps
module tb_calibrated;
    parameter WIDTH=64,HEIGHT=48;
    reg  clk=0;
    reg  rst_n=0;
    reg  pixel_valid=0;
    reg [23:0] rgb=0;
    reg [10:0] x=0;
    reg [10:0] y=0;
    reg  sof=0;
    reg  eol=0;
    reg  eof=0;
    reg [31:0] source_frame_id=0;
    wire  filtered_valid;
    wire  filtered_mask;
    wire [10:0] filtered_x;
    wire [10:0] filtered_y;
    wire  filtered_sof;
    wire  filtered_eol;
    wire  filtered_eof;
    wire [31:0] filtered_frame_id;
    wire [15:0] filtered_cfg_id;
    wire [1:0] filtered_target_id;
    wire  result_strobe;
    wire  target_valid;
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
    reg  calibrate_req=0;
    reg  color_select_req=0;
    reg [1:0] color_select=0;
    wire  busy;
    wire  request_ignored;
    wire [15:0] ignored_requests;
    wire  sample_done;
    wire  sample_ok;
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
    wire  select_ignored;
    wire  calibration_done;
    wire  calibration_ok;
    wire  cfg_applied;
    wire  pending_valid;
    wire [2:0] calibration_reason;
    wire [31:0] calibration_frame_id;
    wire [15:0] active_cfg_id;
    wire [1:0] active_color;
    wire [1:0] pending_color;
    wire [7:0] active_main;
    wire [7:0] active_diff_1;
    wire [7:0] active_diff_2;
    wire [7:0] pending_main;
    wire [7:0] pending_diff_1;
    wire [7:0] pending_diff_2;
    always #5 clk=~clk;
    rgb_calibrated_result #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) dut(
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
        .calibrate_req(calibrate_req),
        .color_select_req(color_select_req),
        .color_select(color_select),
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
        .mean_b(mean_b),
        .select_ignored(select_ignored),
        .calibration_done(calibration_done),
        .calibration_ok(calibration_ok),
        .cfg_applied(cfg_applied),
        .pending_valid(pending_valid),
        .calibration_reason(calibration_reason),
        .calibration_frame_id(calibration_frame_id),
        .active_cfg_id(active_cfg_id),
        .active_color(active_color),
        .pending_color(pending_color),
        .active_main(active_main),
        .active_diff_1(active_diff_1),
        .active_diff_2(active_diff_2),
        .pending_main(pending_main),
        .pending_diff_1(pending_diff_1),
        .pending_diff_2(pending_diff_2));
    integer src,out,configs,calibs,raws,frames,masks=0,n,op,pattern,request_at,extra_at,select_at,select_value,stop_flag,idle_cycles;
    integer expected_cfg,expected_color,em,ed1,ed2,cycle=0,raw_count=0,checked_pixels=0,filtered_pixels=0;
    integer xx,yy,k,idx,ri,rx,ry,frame_index=0,out_index=0,bit_expected,meta_id,meta_cfg,meta_color;
    reg [31:0] id_value;
    reg [23:0] value;
    reg [1023:0] mask_path;
    reg in_input=0,ev,eb;
    reg [203:0] previous_result=0;
    wire [203:0] packet={result_frame_id,result_cfg_id,target_id,target_valid,area,xmin,ymin,xmax,ymax,cx,cy,
        reject_reason,debug_count,debug_xmin,debug_ymin,debug_xmax,debug_ymax};
    function expected_pixel;
        input [23:0] pixel;
        input integer c,m,d1,d2;
        integer a,b,d;
        begin
            case(c)
                0:begin a=pixel[23:16];b=pixel[15:8];d=pixel[7:0];end
                1:begin a=pixel[15:8];b=pixel[23:16];d=pixel[7:0];end
                default:begin a=pixel[7:0];b=pixel[23:16];d=pixel[15:8];end
            endcase
            expected_pixel=(a>=m && a-b>=d1 && a-d>=d2);
        end
    endfunction
    initial begin #400000000;$fatal(1,"watchdog");end
    always @(posedge clk) begin
        ev=rst_n && pixel_valid && (in_input || sof);
        eb=ev && expected_pixel(rgb,expected_color,em,ed1,ed2);
        #1;
        if($time>10) begin
            cycle=cycle+1;
            if(!rst_n) begin
                in_input=0;raw_count=0;out_index=0;
                if(masks) begin $fclose(masks);masks=0;end
                if(result_strobe || calibration_done || busy || active_cfg_id!=0) $fatal(1,"reset failure");
            end else begin
                if(pixel_valid && sof) begin
                    $fdisplay(configs,"%0d,%0d,%0d,%0d,%0d,%0d,%0d",cycle,source_frame_id,active_cfg_id,active_color,active_main,active_diff_1,active_diff_2);
                    if(active_cfg_id!=expected_cfg || active_color!=expected_color || active_main!=em || active_diff_1!=ed1 || active_diff_2!=ed2)
                        $fatal(1,"wrong frame settings id=%0d cfg=%0d expected=%0d",source_frame_id,active_cfg_id,expected_cfg);
                end
                if(dut.raw_valid!==ev || dut.raw_mask!==eb) $fatal(1,"runtime pixel mismatch");
                if(ev) begin
                    in_input=!eof;checked_pixels=checked_pixels+1;
                    if(dut.raw_cfg_id!=expected_cfg || dut.raw_color!=expected_color || dut.raw_frame_id!=source_frame_id ||
                        dut.raw_x!=x || dut.raw_y!=y || dut.raw_sof!=sof || dut.raw_eof!=eof) $fatal(1,"raw metadata mismatch");
                    if(sof) raw_count=0;
                    raw_count=raw_count+dut.raw_mask;
                    if(eof) $fdisplay(raws,"%0d,%0d,%0d,%0d",source_frame_id,dut.raw_cfg_id,dut.raw_color,raw_count);
                end
                if(filtered_valid) begin
                    if(filtered_sof) begin
                        if(masks) $fclose(masks);
                        $sformat(mask_path,"mask_%0d.txt",frame_index);masks=$fopen(mask_path,"r");
                        n=$fscanf(frames,"%d %d %d\n",meta_id,meta_cfg,meta_color);
                        if(n!=3 || !masks) $fatal(1,"missing expected frame");
                        frame_index=frame_index+1;out_index=0;
                    end
                    if(filtered_x!=out_index%WIDTH || filtered_y!=out_index/WIDTH || filtered_sof!=(out_index==0) ||
                        filtered_eol!=(out_index%WIDTH==WIDTH-1) || filtered_eof!=(out_index==WIDTH*HEIGHT-1)) $fatal(1,"filtered raster mismatch");
                    if(filtered_frame_id!=meta_id || filtered_cfg_id!=meta_cfg || filtered_target_id!=meta_color) $fatal(1,"filtered tags mismatch");
                    n=$fscanf(masks,"%d\n",bit_expected);
                    if(n!=1 || filtered_mask!==bit_expected[0]) $fatal(1,"filtered pixel mismatch frame=%0d index=%0d",frame_index-1,out_index);
                    out_index=out_index+1;filtered_pixels=filtered_pixels+1;
                end
                if(!result_strobe && packet!==previous_result) $fatal(1,"result packet changed without strobe");
                if((^{packet,busy,calibration_done,calibration_ok,pending_valid,active_cfg_id})===1'bx) $fatal(1,"unknown output");
                if(result_strobe) $fdisplay(out,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                    cycle,result_frame_id,result_cfg_id,target_id,target_valid,area,xmin,ymin,xmax,ymax,cx,cy,reject_reason,debug_count,debug_xmin,debug_ymin,debug_xmax,debug_ymax);
                if(calibration_done) $fdisplay(calibs,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",cycle,calibration_frame_id,calibration_ok,calibration_reason,pending_color,pending_main,pending_diff_1,pending_diff_2);
            end
            previous_result=packet;
        end
    end
    task beat;
        input rv,pv,req,sreq;
        input [23:0] data;
        input integer px,py;
        input s,l,f;
        begin
            @(negedge clk);rst_n=rv;pixel_valid=pv;calibrate_req=req;color_select_req=sreq;rgb=data;
            x=px;y=py;sof=s;eol=l;eof=f;
            @(posedge clk);#2;
        end
    endtask
    initial begin
        src=$fopen("cases.txt","r");out=$fopen("actual.csv","w");configs=$fopen("configs.csv","w");
        calibs=$fopen("calibrations.csv","w");raws=$fopen("raw_counts.csv","w");frames=$fopen("frames.txt","r");
        $fdisplay(out,"cycle,frame_id,cfg_id,target_id,valid,area,xmin,ymin,xmax,ymax,cx,cy,reason,debug_count,debug_xmin,debug_ymin,debug_xmax,debug_ymax");
        $fdisplay(configs,"cycle,frame_id,cfg_id,color,main,d1,d2");
        $fdisplay(calibs,"cycle,frame_id,ok,reason,pending_color,main,d1,d2");
        $fdisplay(raws,"frame_id,cfg_id,color,count");
        $dumpfile("calibration_trace.vcd");$dumpvars(1,tb_calibrated);if(WIDTH>64) $dumpoff;
        rx=(WIDTH-16)/2;ry=(HEIGHT-16)/2;
        beat(0,0,0,0,0,0,0,0,0,0);
        while(!$feof(src)) begin
            n=$fscanf(src,"%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",
                op,id_value,pattern,request_at,extra_at,select_at,select_value,stop_flag,idle_cycles,expected_cfg,expected_color,em,ed1,ed2,k);
            if(n!=15) $fatal(1,"bad command");
            if(op==1) beat(0,0,0,0,0,0,0,0,0,0);
            else if(op==2) for(k=0;k<idle_cycles;k=k+1) beat(1,0,0,0,0,0,0,0,0,0);
            else begin
                source_frame_id=id_value;color_select=select_value;
                for(yy=0;yy<HEIGHT;yy=yy+1) begin
                    for(xx=0;xx<WIDTH;xx=xx+1) begin
                        idx=yy*WIDTH+xx;
                        if(!stop_flag || yy<ry+16) begin
                            value=24'h640000;
                            if(pattern==8) value=24'h006400;
                            if(pattern==11) value=24'h000064;
                            if(pattern==2 || pattern==9) begin
                                case(xx*4/WIDTH)
                                    0:value=24'h823232;1:value=24'h823332;2:value=24'h772727;3:value=24'h782828;
                                endcase
                                if(pattern==9) value={value[15:8],value[23:16],value[7:0]};
                            end
                            if(xx>=rx && xx<rx+16 && yy>=ry && yy<ry+16) begin
                                case(pattern)
                                    1:value=yy<ry+8 ? 24'h902828 : 24'ha02828;
                                    3:value=24'h808080;4:value=24'h101010;5:value=24'hffffff;
                                    6:value=yy<ry+8 ? 24'hc82828 : 24'h2828c8;
                                    7:value=24'h289828;10:value=24'h282898;
                                endcase
                            end
                            beat(1,1,idx==request_at || idx==extra_at,idx==select_at,value,xx,yy,idx==0,xx==WIDTH-1,idx==WIDTH*HEIGHT-1);
                        end
                    end
                    if(yy<HEIGHT-1 && (!stop_flag || yy<ry+15))
                        for(k=0;k<1+yy%3;k=k+1) beat(1,0,0,0,0,0,0,0,0,0);
                end
            end
        end
        for(k=0;k<WIDTH+50;k=k+1) beat(1,0,0,0,0,0,0,0,0,0);
        $display("C9_CHAIN_COMPLETE cycles=%0d raw_pixels=%0d filtered_pixels=%0d",cycle,checked_pixels,filtered_pixels);
        $fclose(src);$fclose(out);$fclose(configs);$fclose(calibs);$fclose(raws);$fclose(frames);if(masks) $fclose(masks);$finish;
    end
endmodule
