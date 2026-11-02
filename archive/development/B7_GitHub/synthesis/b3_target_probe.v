// Resource observation wrapper, not a board pin interface.
module b3_target_probe(
    input wire clk,rst_n,in_load,
    input wire [2:0] in_buttons_async,
    input wire [3:0] in_bank,in_probe,
    input wire [31:0] in_data,
    input wire in_valid,in_sof,in_eol,in_eof,in_abort,
    input wire in_result_strobe,in_source_timeout,in_result_timeout,
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
    wire [159:0] supplied_result=config_words[356:197];
    wire [31:0] result_fid;
    wire [15:0] result_cfg;
    wire [1:0] result_target;
    wire result_valid;
    wire [19:0] result_area;
    wire [10:0] rxmin,rymin,rxmax,rymax,rcx,rcy;
    wire [2:0] result_reason;
    wire [7:0] result_slots;
    wire [11:0] result_components;
    assign {result_fid,result_cfg,result_target,result_valid,result_area,
        rxmin,rymin,rxmax,rymax,rcx,rcy,result_reason,result_slots,
        result_components}=supplied_result;
    video_b3_target_stream core(.clk(clk),.rst_n(rst_n),.stream_abort(in_abort),
        .in_valid(in_valid),.in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),
        .in_x(in_x),.in_y(in_y),.in_rgb(in_rgb),
        .in_epoch(config_words[31:0]),.in_frame_id(config_words[63:32]),
        .in_cfg_id(config_words[79:64]),.in_target_id(config_words[81:80]),
        .min_main(config_words[89:82]),.min_diff_1(config_words[97:90]),.min_diff_2(config_words[105:98]),
        .buttons_async(in_buttons_async),.roi_req_valid(config_words[106]),.roi_req_enable(config_words[107]),
        .calibration_status_packet(config_words[158:108]),.tracking_packet(config_words[196:159]),
        .result_strobe(in_result_strobe),.target_valid(result_valid),
        .result_epoch(config_words[388:357]),.result_frame_id(result_fid),
        .result_cfg_id(result_cfg),.result_target_id(result_target),
        .area(result_area),.xmin(rxmin),.ymin(rymin),.xmax(rxmax),.ymax(rymax),.cx(rcx),.cy(rcy),
        .reason(result_reason),.labels_used(result_slots),.components(result_components),
        .source_timeout(in_source_timeout),.result_timeout(in_result_timeout),
        .press_event(events),.mode_next_evt(mode_evt),.calibrate_evt(cal_evt),.track_toggle_evt(track_evt),
        .out_valid(ov),.out_sof(os),.out_eol(ol),.out_eof(oe),.out_x(ox),.out_y(oy),.out_rgb(rgb),
        .out_epoch(epoch),.out_frame_id(fid),.out_cfg_id(cfg),.out_target_id(target),.out_mode(mode),
        .out_abort(abort),.error_flags(errors),.fifo_used(used),.fifo_peak(peak),
        .out_calibration_status(cal_status),.out_tracking_status(track_status),
        .out_snapshot_ready(snapshot_ready),.out_result_packet(result_packet));
    wire [511:0] observation={63'd0,snapshot_ready,result_packet,
        9'd0,events,mode_evt,cal_evt,track_evt,ov,os,ol,oe,abort,ox,oy,rgb,tag,
        cal_status,track_status,errors,used,peak};
    always @*case(in_probe)
        0:out_probe=observation[31:0];1:out_probe=observation[63:32];
        2:out_probe=observation[95:64];3:out_probe=observation[127:96];
        4:out_probe=observation[159:128];5:out_probe=observation[191:160];
        6:out_probe=observation[223:192];7:out_probe=observation[255:224];
        8:out_probe=observation[287:256];default:out_probe=0;
        9:out_probe=observation[319:288];10:out_probe=observation[351:320];
        11:out_probe=observation[383:352];12:out_probe=observation[415:384];
        13:out_probe=observation[447:416];14:out_probe=observation[479:448];
        15:out_probe=observation[511:480];
    endcase
endmodule
