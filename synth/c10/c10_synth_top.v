// Synthesis-only observable harness, not a board-level pin interface.
module c10_synth_top(
    input wire  clk,
    input wire  rst_n,
    input wire  pixel_valid,
    input wire [23:0] rgb,
    input wire [10:0] x,
    input wire [10:0] y,
    input wire  sof,
    input wire  eol,
    input wire  eof,
    input wire [31:0] source_frame_id,
    input wire  calibrate_req,
    input wire  color_select_req,
    input wire [1:0] color_select,
    input wire [5:0] read_index,
    output wire result_strobe,
    output reg [15:0] result_word
);
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
    wire [527:0] result_bits={15'b0,target_valid,result_frame_id,result_cfg_id,target_id,area,cx,xmin,xmax,cy,ymin,ymax,reject_reason,debug_count,debug_xmin,debug_ymin,debug_xmax,debug_ymax,busy,request_ignored,ignored_requests,sample_done,sample_ok,sample_reason,sample_frame_id,sample_cfg_id,sample_target_id,sample_count,sum_r,sum_g,sum_b,min_r,min_g,min_b,max_r,max_g,max_b,mean_r,mean_g,mean_b,select_ignored,calibration_done,calibration_ok,cfg_applied,pending_valid,calibration_reason,calibration_frame_id,active_cfg_id,active_color,pending_color,active_main,active_diff_1,active_diff_2,pending_main,pending_diff_1,pending_diff_2 };
    rgb_calibrated_result core(
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
        .calibrate_req(calibrate_req),
        .color_select_req(color_select_req),
        .color_select(color_select),
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
        .pending_diff_2(pending_diff_2),
        .result_strobe(result_strobe));
    always @* begin
        case(read_index)
            0:result_word=result_bits[15:0];
            1:result_word=result_bits[31:16];
            2:result_word=result_bits[47:32];
            3:result_word=result_bits[63:48];
            4:result_word=result_bits[79:64];
            5:result_word=result_bits[95:80];
            6:result_word=result_bits[111:96];
            7:result_word=result_bits[127:112];
            8:result_word=result_bits[143:128];
            9:result_word=result_bits[159:144];
            10:result_word=result_bits[175:160];
            11:result_word=result_bits[191:176];
            12:result_word=result_bits[207:192];
            13:result_word=result_bits[223:208];
            14:result_word=result_bits[239:224];
            15:result_word=result_bits[255:240];
            16:result_word=result_bits[271:256];
            17:result_word=result_bits[287:272];
            18:result_word=result_bits[303:288];
            19:result_word=result_bits[319:304];
            20:result_word=result_bits[335:320];
            21:result_word=result_bits[351:336];
            22:result_word=result_bits[367:352];
            23:result_word=result_bits[383:368];
            24:result_word=result_bits[399:384];
            25:result_word=result_bits[415:400];
            26:result_word=result_bits[431:416];
            27:result_word=result_bits[447:432];
            28:result_word=result_bits[463:448];
            29:result_word=result_bits[479:464];
            30:result_word=result_bits[495:480];
            31:result_word=result_bits[511:496];
            32:result_word=result_bits[527:512];
            default:result_word=0;
        endcase
    end
endmodule
