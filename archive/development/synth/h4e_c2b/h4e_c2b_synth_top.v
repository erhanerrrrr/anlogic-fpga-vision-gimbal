// Full production-sized recognition branch, with word I/O for synthesis only.
// Neither this staging register nor its read mux belongs in the board design.
module h4e_c2b_synth_top(
    input wire clk,rst_n,write_enable,pixel_valid,sof,eof,source_flush,
    input wire [2:0] write_word,read_word,
    input wire [31:0] write_data,
    output reg [31:0] read_data,
    output wire result_strobe,new_observation
);
    reg [183:0] sample;
    wire [191:0] payload;
    wire new_source_sof,accepted_sof,frame_abort,stream_error;
    wire [15:0] active_cfg_id;
    wire [1:0] active_color;
    wire [7:0] active_min_main,active_min_diff_1,active_min_diff_2;
    wire [255:0] snapshot={18'd0,new_source_sof,accepted_sof,frame_abort,stream_error,
        active_cfg_id,active_color,active_min_main,active_min_diff_1,active_min_diff_2,payload};
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) sample<=0;
        else if(write_enable) case(write_word)
            3'd0:sample[31:0]<=write_data;
            3'd1:sample[63:32]<=write_data;
            3'd2:sample[95:64]<=write_data;
            3'd3:sample[127:96]<=write_data;
            3'd4:sample[159:128]<=write_data;
            3'd5:sample[183:160]<=write_data[23:0];
            default: ;
        endcase
    end
    h4e_capture_tracker tracker(
        .clk(clk),.rst_n(rst_n),.pixel_valid(pixel_valid),.sof(sof),.eof(eof),.source_flush(source_flush),
        .rgb(sample[183:160]),
        .x(sample[159:149]),
        .y(sample[148:138]),
        .source_frame_id(sample[137:106]),
        .source_epoch(sample[105:74]),
        .active_epoch(sample[73:42]),
        .requested_cfg_id(sample[41:26]),
        .requested_color(sample[25:24]),
        .requested_min_main(sample[23:16]),
        .requested_min_diff_1(sample[15:8]),
        .requested_min_diff_2(sample[7:0]),
        .result_strobe(result_strobe),.new_observation(new_observation),.new_source_sof(new_source_sof),
        .accepted_sof(accepted_sof),.frame_abort(frame_abort),.stream_error(stream_error),
        .active_cfg_id(active_cfg_id),.active_color(active_color),.active_min_main(active_min_main),
        .active_min_diff_1(active_min_diff_1),.active_min_diff_2(active_min_diff_2),
        .target_valid(payload[191]),
        .frame_id(payload[190:159]),
        .capture_epoch(payload[158:127]),
        .cfg_id(payload[126:111]),
        .target_id(payload[110:109]),
        .area(payload[108:89]),
        .cx(payload[88:78]),
        .cy(payload[77:67]),
        .xmin(payload[66:56]),
        .xmax(payload[55:45]),
        .ymin(payload[44:34]),
        .ymax(payload[33:23]),
        .reject_reason(payload[22:20]),
        .peak_slots(payload[19:12]),
        .component_count(payload[11:0]));
    always @* case(read_word)
        3'd0:read_data=snapshot[31:0];
        3'd1:read_data=snapshot[63:32];
        3'd2:read_data=snapshot[95:64];
        3'd3:read_data=snapshot[127:96];
        3'd4:read_data=snapshot[159:128];
        3'd5:read_data=snapshot[191:160];
        3'd6:read_data=snapshot[223:192];
        3'd7:read_data=snapshot[255:224];
        default:read_data=0;
    endcase
endmodule
