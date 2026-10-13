// Observable standalone synthesis harness, excluded from module cost.
module h4e_c3b_synth_top(input wire clk,rst_n,write_enable,
 input wire [3:0] write_word,read_word,input wire [31:0] write_data,
 output reg [31:0] read_data);
 reg [223:0] inputs;
 wire [127:0] payload;
 assign payload[127:113]=0;
 always @(posedge clk or negedge rst_n) begin
 if(!rst_n) inputs<=0;
 else if(write_enable) case(write_word)
 4'd0:inputs[31:0]<=write_data;
 4'd1:inputs[63:32]<=write_data;
 4'd2:inputs[95:64]<=write_data;
 4'd3:inputs[127:96]<=write_data;
 4'd4:inputs[159:128]<=write_data;
 4'd5:inputs[191:160]<=write_data;
 4'd6:inputs[223:192]<=write_data;
 default:;endcase end
 h4e_calibration_candidate dut(.clk(clk),
.rst_n(rst_n),
.source_flush(inputs[0:0]),
.active_epoch(inputs[32:1]),
.sample_done(inputs[33:33]),
.sample_ok(inputs[34:34]),
.sample_count(inputs[43:35]),
.sample_frame_id(inputs[75:44]),
.sample_epoch(inputs[107:76]),
.sample_cfg_id(inputs[123:108]),
.sample_target_id(inputs[125:124]),
.mean_r(inputs[133:126]),
.mean_g(inputs[141:134]),
.mean_b(inputs[149:142]),
.min_r(inputs[157:150]),
.min_g(inputs[165:158]),
.min_b(inputs[173:166]),
.max_r(inputs[181:174]),
.max_g(inputs[189:182]),
.max_b(inputs[197:190]),
.calibration_done(payload[0:0]),
.calibration_ok(payload[1:1]),
.calibration_reason(payload[4:2]),
.calibration_frame_id(payload[36:5]),
.calibration_epoch(payload[68:37]),
.calibration_cfg_id(payload[84:69]),
.calibration_target_id(payload[86:85]),
.candidate_color(payload[88:87]),
.candidate_min_main(payload[96:89]),
.candidate_diff_1(payload[104:97]),
.candidate_diff_2(payload[112:105]));
 always @* begin case(read_word)
 4'd0:read_data=payload[31:0];
 4'd1:read_data=payload[63:32];
 4'd2:read_data=payload[95:64];
 4'd3:read_data=payload[127:96];
 default:read_data=0;endcase end
endmodule
