// Resource observation wrapper. Banked registers avoid assigning every internal
// metadata bit to a physical pin. Not a board-level interface.
module calibration_status_probe(
    input wire clk,rst_n,stream_abort,
    input wire c_status_valid,sample_req,sample_done,calibration_done,calibration_ok,cfg_applied,pending_valid,busy,
    input wire in_load,
    input wire [2:0] in_bank,in_probe,
    input wire [31:0] in_data,
    input wire in_valid,in_sof,in_eol,in_eof,
    input wire [10:0] in_x,in_y,
    input wire [23:0] in_rgb,
    output reg [31:0] out_probe
);
    reg [159:0] config_words;
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)config_words<=0;
        else if(in_load)case(in_bank)
            0:config_words[31:0]<=in_data;1:config_words[63:32]<=in_data;
            2:config_words[95:64]<=in_data;3:config_words[127:96]<=in_data;
            4:config_words[159:128]<=in_data;
            default:begin end
        endcase
    end
    wire [2:0] calibration_reason;
    wire [15:0] active_cfg_id;
    wire [1:0] active_color;
    wire [7:0] active_main,active_diff_1,active_diff_2;
    wire [83:0] in_tag;
    assign {calibration_reason,active_cfg_id,active_color,active_main,active_diff_1,active_diff_2,in_tag}=config_words[128:0];
    wire out_valid,out_sof,out_eol,out_eof;
    wire [10:0] out_x,out_y;
    wire [23:0] out_rgb;
    wire [83:0] out_tag;
    wire [50:0] out_status;
    wire [191:0] observation={7'd0,out_valid,out_sof,out_eol,out_eof,out_x,out_y,out_rgb,out_tag,out_status};
    always @*case(in_probe)
        0:out_probe=observation[31:0];1:out_probe=observation[63:32];
        2:out_probe=observation[95:64];3:out_probe=observation[127:96];
        4:out_probe=observation[159:128];5:out_probe=observation[191:160];
        default:out_probe=0;
    endcase
    wire [50:0] status_packet;
    calibration_status_view observer(.clk(clk),.rst_n(rst_n),.c_status_valid(c_status_valid),
        .sample_req(sample_req),.sample_done(sample_done),.calibration_done(calibration_done),.calibration_ok(calibration_ok),
        .cfg_applied(cfg_applied),.pending_valid(pending_valid),.busy(busy),.calibration_reason(calibration_reason),
        .active_cfg_id(active_cfg_id),.active_color(active_color),.active_main(active_main),
        .active_diff_1(active_diff_1),.active_diff_2(active_diff_2),.status_packet(status_packet));
    video_calibration_text renderer(.clk(clk),.rst_n(rst_n),.stream_abort(stream_abort),.status_packet(status_packet),
        .in_valid(in_valid),.in_sof(in_sof),.in_eol(in_eol),.in_eof(in_eof),.in_x(in_x),.in_y(in_y),.in_rgb(in_rgb),.in_tag(in_tag),
        .out_valid(out_valid),.out_sof(out_sof),.out_eol(out_eol),.out_eof(out_eof),.out_x(out_x),.out_y(out_y),.out_rgb(out_rgb),
        .out_tag(out_tag),.out_status(out_status));
endmodule
