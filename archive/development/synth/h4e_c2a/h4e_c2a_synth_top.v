// Synthesis-only word I/O harness: keeps every packet bit observable.
// Harness input staging and read mux are NOT part of the packet resource cost.
module h4e_c2a_synth_top(
    input wire clk,rst_n,write_enable,source_strobe,
    input wire [2:0] write_word,read_word,
    input wire [31:0] write_data,
    output reg [31:0] read_data,
    output wire result_strobe
);
    reg [191:0] sample;
    wire [191:0] payload;
    wire s=source_strobe;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) sample<=192'd0;
        else if(write_enable) case(write_word)
            3'd0:sample[31:0]<=write_data;
            3'd1:sample[63:32]<=write_data;
            3'd2:sample[95:64]<=write_data;
            3'd3:sample[127:96]<=write_data;
            3'd4:sample[159:128]<=write_data;
            3'd5:sample[191:160]<=write_data;
            default: ;
        endcase
    end
    h4e_target_packet dut(.clk(clk),.rst_n(rst_n),.t_result_strobe(s),
        .t_target_valid(sample[191]),
        .t_frame_id(sample[190:159]),
        .t_capture_epoch(sample[158:127]),
        .t_cfg_id(sample[126:111]),
        .t_target_id(sample[110:109]),
        .t_area(sample[108:89]),
        .t_cx(sample[88:78]),
        .t_cy(sample[77:67]),
        .t_xmin(sample[66:56]),
        .t_xmax(sample[55:45]),
        .t_ymin(sample[44:34]),
        .t_ymax(sample[33:23]),
        .t_reason(sample[22:20]),
        .t_peak_slots(sample[19:12]),
        .t_component_count(sample[11:0]),
        .result_strobe(result_strobe),
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
    always @* begin
        case(read_word)
            3'd0:read_data=payload[31:0];
            3'd1:read_data=payload[63:32];
            3'd2:read_data=payload[95:64];
            3'd3:read_data=payload[127:96];
            3'd4:read_data=payload[159:128];
            3'd5:read_data=payload[191:160];
            default:read_data=32'd0;
        endcase
    end
endmodule
