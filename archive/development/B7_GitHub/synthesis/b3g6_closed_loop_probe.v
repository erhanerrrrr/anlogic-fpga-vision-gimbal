// B3g6 resource probe: same-clock closed-loop B display plus H4E selector.
module b3g6_closed_loop_probe(
    input wire clk,rst_n,in_load,
    input wire [2:0] in_buttons_async,
    input wire [3:0] in_bank,
    input wire [31:0] in_data,
    input wire in_valid,in_sof,in_eol,in_eof,in_abort,
    input wire in_source_timeout,in_result_timeout,
    input wire [10:0] in_x,in_y,
    input wire [23:0] in_rgb,
    output reg [31:0] out_probe
);
    reg [511:0] config_words;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)config_words<=0;
        else if(in_load)case(in_bank)
            0:config_words[31:0]<=in_data;1:config_words[63:32]<=in_data;
            2:config_words[95:64]<=in_data;3:config_words[127:96]<=in_data;
            4:config_words[159:128]<=in_data;5:config_words[191:160]<=in_data;
            6:config_words[223:192]<=in_data;7:config_words[255:224]<=in_data;
            8:config_words[287:256]<=in_data;9:config_words[319:288]<=in_data;
            10:config_words[351:320]<=in_data;11:config_words[383:352]<=in_data;
            12:config_words[415:384]<=in_data;13:config_words[447:416]<=in_data;
            14:config_words[479:448]<=in_data;15:config_words[511:480]<=in_data;
        endcase
    end
    wire [2:0] events;
    wire mode_evt,cal_evt,track_evt,ov,os,ol,oe,abort;
    wire [10:0] ox,oy;
    wire [23:0] rgb;
    wire [31:0] epoch,fid;
    wire [15:0] cfg,errors,used,peak;
    wire [1:0] target,mode;
    wire [50:0] cal_status;
    wire [37:0] track_status;
    wire [83:0] tag={epoch,fid,cfg,target,mode};
    wire snapshot_ready;
    wire [159:0] result_packet;
    wire c_strobe,c_busy;
    wire [31:0] c_epoch;
    wire [159:0] c_packet;
    video_b3_h4e_sameclk core(.clk(clk),.rst_n(rst_n),.stream_abort(in_abort),
        .in_valid(in_valid),.in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),
        .in_x(in_x),.in_y(in_y),.in_rgb(in_rgb),
        .in_epoch(config_words[31:0]),.in_frame_id(config_words[63:32]),
        .in_cfg_id(config_words[79:64]),.in_target_id(config_words[81:80]),
        .min_main(config_words[89:82]),.min_diff_1(config_words[97:90]),.min_diff_2(config_words[105:98]),
        .buttons_async(in_buttons_async),.roi_req_valid(config_words[106]),.roi_req_enable(config_words[107]),
        .calibration_status_packet(config_words[158:108]),.tracking_packet(config_words[196:159]),
        .source_timeout(in_source_timeout),.result_timeout(in_result_timeout),
        .press_event(events),.mode_next_evt(mode_evt),.calibrate_evt(cal_evt),.track_toggle_evt(track_evt),
        .out_valid(ov),.out_sof(os),.out_eol(ol),.out_eof(oe),.out_x(ox),.out_y(oy),.out_rgb(rgb),
        .out_epoch(epoch),.out_frame_id(fid),.out_cfg_id(cfg),.out_target_id(target),.out_mode(mode),
        .out_abort(abort),.error_flags(errors),.fifo_used(used),.fifo_peak(peak),
        .out_calibration_status(cal_status),.out_tracking_status(track_status),
        .out_snapshot_ready(snapshot_ready),.out_result_packet(result_packet),
        .region_busy(c_busy),.region_result_strobe(c_strobe),
        .region_result_epoch(c_epoch),.region_result_packet(c_packet));
    wire [767:0] observation={62'd0,c_strobe,c_busy,c_packet,c_epoch,
        63'd0,snapshot_ready,result_packet,
        9'd0,events,mode_evt,cal_evt,track_evt,ov,os,ol,oe,abort,ox,oy,rgb,tag,
        cal_status,track_status,errors,used,peak};
    // Test-only compact activity signature. Six registered groups keep the
    // observation logic off the pixel-output-to-pad timing path.
    reg [31:0] signature_group[0:5];
    genvar k;
    generate for(k=0;k<6;k=k+1)begin:signature
        always @(posedge clk or negedge rst_n)
            if(!rst_n)signature_group[k]<=0;
            else signature_group[k]<=observation[k*128 +:32] ^
                observation[k*128+32 +:32] ^
                observation[k*128+64 +:32] ^
                observation[k*128+96 +:32];
    end endgenerate
    always @(posedge clk or negedge rst_n)
        if(!rst_n)out_probe<=0;
        else out_probe<=signature_group[0]^signature_group[1]^
            signature_group[2]^signature_group[3]^
            signature_group[4]^signature_group[5];
endmodule
