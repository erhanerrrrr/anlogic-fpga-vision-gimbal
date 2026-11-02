// Isolated synthesis harness. Staging and read mux excluded from module cost.
module h4e_c3a_synth_top(input wire clk,rst_n,write_enable,
 input wire [3:0] write_word,read_word,input wire [31:0] write_data,
 output reg [31:0] read_data);
 reg [191:0] inputs;
 wire [223:0] payload;
 assign payload[223:217]=0;
 always @(posedge clk or negedge rst_n) begin
 if(!rst_n) inputs<=0;
 else if(write_enable) case(write_word)
 4'd0:inputs[31:0]<=write_data;
 4'd1:inputs[63:32]<=write_data;
 4'd2:inputs[95:64]<=write_data;
 4'd3:inputs[127:96]<=write_data;
 4'd4:inputs[159:128]<=write_data;
 4'd5:inputs[191:160]<=write_data;
 default:;endcase
 end
 h4e_roi_sampler dut(.clk(clk),
.rst_n(rst_n),
.sample_req(inputs[0:0]),
.source_flush(inputs[1:1]),
.active_epoch(inputs[33:2]),
.source_epoch(inputs[65:34]),
.source_frame_id(inputs[97:66]),
.requested_cfg_id(inputs[113:98]),
.requested_color(inputs[115:114]),
.accepted_sof(inputs[116:116]),
.new_source_sof(inputs[117:117]),
.frame_abort(inputs[118:118]),
.pixel_valid(inputs[119:119]),
.sof(inputs[120:120]),
.eof(inputs[121:121]),
.rgb(inputs[145:122]),
.x(inputs[156:146]),
.y(inputs[167:157]),
.busy(payload[0:0]),
.request_ignored(payload[1:1]),
.sample_done(payload[2:2]),
.sample_ok(payload[3:3]),
.sample_reason(payload[5:4]),
.sample_frame_id(payload[37:6]),
.sample_epoch(payload[69:38]),
.sample_cfg_id(payload[85:70]),
.sample_target_id(payload[87:86]),
.sample_count(payload[96:88]),
.sum_r(payload[112:97]),
.sum_g(payload[128:113]),
.sum_b(payload[144:129]),
.min_r(payload[152:145]),
.min_g(payload[160:153]),
.min_b(payload[168:161]),
.max_r(payload[176:169]),
.max_g(payload[184:177]),
.max_b(payload[192:185]),
.mean_r(payload[200:193]),
.mean_g(payload[208:201]),
.mean_b(payload[216:209]));
 always @* begin case(read_word)
 4'd0:read_data=payload[31:0];
 4'd1:read_data=payload[63:32];
 4'd2:read_data=payload[95:64];
 4'd3:read_data=payload[127:96];
 4'd4:read_data=payload[159:128];
 4'd5:read_data=payload[191:160];
 4'd6:read_data=payload[223:192];
 default:read_data=0;endcase end
endmodule
