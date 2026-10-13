// Standalone observable synthesis harness; excluded from controller cost.
module h4e_c3c_synth_top(input wire clk,rst_n,write_enable,
 input wire [3:0] write_word,read_word,input wire [31:0] write_data,
 output reg [31:0] read_data);
 reg [159:0] inputs;
 wire [95:0] payload;
 assign payload[95:76]=0;
 always @(posedge clk or negedge rst_n) begin
 if(!rst_n) inputs<=0;
 else if(write_enable) case(write_word)
 4'd0:inputs[31:0]<=write_data;
 4'd1:inputs[63:32]<=write_data;
 4'd2:inputs[95:64]<=write_data;
 4'd3:inputs[127:96]<=write_data;
 4'd4:inputs[159:128]<=write_data;
 default:;endcase end
 h4e_calibration_control dut(.clk(clk),
.rst_n(rst_n),
.source_flush(inputs[0:0]),
.active_epoch(inputs[32:1]),
.new_source_sof(inputs[33:33]),
.calibrate_req(inputs[34:34]),
.color_select_req(inputs[35:35]),
.color_select(inputs[37:36]),
.sampler_busy(inputs[38:38]),
.calibration_done(inputs[39:39]),
.calibration_ok(inputs[40:40]),
.calibration_epoch(inputs[72:41]),
.candidate_color(inputs[74:73]),
.candidate_min_main(inputs[82:75]),
.candidate_diff_1(inputs[90:83]),
.candidate_diff_2(inputs[98:91]),
.active_cfg_id(inputs[114:99]),
.active_color(inputs[116:115]),
.active_min_main(inputs[124:117]),
.active_min_diff_1(inputs[132:125]),
.active_min_diff_2(inputs[140:133]),
.sample_req(payload[0:0]),
.busy(payload[1:1]),
.operation_flush(payload[2:2]),
.request_ignored(payload[3:3]),
.select_ignored(payload[4:4]),
.cfg_applied(payload[5:5]),
.operation_cancelled(payload[6:6]),
.pending_valid(payload[7:7]),
.pending_color(payload[9:8]),
.pending_main(payload[17:10]),
.pending_diff_1(payload[25:18]),
.pending_diff_2(payload[33:26]),
.requested_cfg_id(payload[49:34]),
.requested_color(payload[51:50]),
.requested_min_main(payload[59:52]),
.requested_min_diff_1(payload[67:60]),
.requested_min_diff_2(payload[75:68]));
 always @* begin case(read_word)
 4'd0:read_data=payload[31:0];
 4'd1:read_data=payload[63:32];
 4'd2:read_data=payload[95:64];
 default:read_data=0;endcase end
endmodule
