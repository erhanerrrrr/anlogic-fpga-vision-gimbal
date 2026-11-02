// C3b: candidate calculation only. No active/pending configuration outputs.
// Defaults reproduce audited C9 SAMPLE QUALITY rules, not C9 detector presets.
module h4e_calibration_candidate #(
    parameter [7:0] MAIN_LOW=8'd80, MAIN_HIGH=8'd224,
    parameter [7:0] MAX_SPREAD=8'd32, MIN_DOMINANCE=8'd40, MARGIN=8'd32
)(
    input wire clk,rst_n,source_flush,
    input wire [31:0] active_epoch,
    input wire sample_done,sample_ok,
    input wire [8:0] sample_count,
    input wire [31:0] sample_frame_id,sample_epoch,
    input wire [15:0] sample_cfg_id,
    input wire [1:0] sample_target_id,
    input wire [7:0] mean_r,mean_g,mean_b,min_r,min_g,min_b,max_r,max_g,max_b,
    output reg calibration_done,calibration_ok,
    output reg [2:0] calibration_reason,
    output reg [31:0] calibration_frame_id,calibration_epoch,
    output reg [15:0] calibration_cfg_id,
    output reg [1:0] calibration_target_id,candidate_color,
    output reg [7:0] candidate_min_main,candidate_diff_1,candidate_diff_2
);
    reg [1:0] dominant;
    reg [7:0] main_value,other_1,other_2;
    reg [2:0] reason;
    wire signed [9:0] d1=$signed({2'b0,main_value})-$signed({2'b0,other_1});
    wire signed [9:0] d2=$signed({2'b0,main_value})-$signed({2'b0,other_2});
    // Widen BEFORE subtraction. This also defines safe behavior for custom
    // quality parameters that permit a difference smaller than MARGIN.
    function [7:0] subtract_margin;
        input signed [9:0] value;
        reg signed [10:0] shifted;
        begin
            shifted=$signed({value[9],value})-$signed({3'b0,MARGIN});
            subtract_margin=shifted<0 ? 8'd0 : (shifted>255 ? 8'd255 : shifted[7:0]);
        end
    endfunction
    always @* begin
        if(mean_r>=mean_g && mean_r>=mean_b) begin dominant=0;main_value=mean_r;other_1=mean_g;other_2=mean_b;end
        else if(mean_g>=mean_b) begin dominant=1;main_value=mean_g;other_1=mean_r;other_2=mean_b;end
        else begin dominant=2;main_value=mean_b;other_1=mean_r;other_2=mean_g;end
        reason=0;
        if(source_flush || sample_epoch!=active_epoch) reason=6;
        else if(!sample_ok || sample_count!=256) reason=1;
        else if(min_r>mean_r || mean_r>max_r || min_g>mean_g || mean_g>max_g || min_b>mean_b || mean_b>max_b) reason=2;
        else if(main_value<MAIN_LOW || main_value>MAIN_HIGH) reason=3;
        else if(({1'b0,max_r}-{1'b0,min_r})>{1'b0,MAX_SPREAD} ||
                ({1'b0,max_g}-{1'b0,min_g})>{1'b0,MAX_SPREAD} ||
                ({1'b0,max_b}-{1'b0,min_b})>{1'b0,MAX_SPREAD}) reason=4;
        else if(d1<$signed({2'b0,MIN_DOMINANCE}) || d2<$signed({2'b0,MIN_DOMINANCE})) reason=5;
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            calibration_done<=0;calibration_ok<=0;calibration_reason<=0;
            calibration_frame_id<=0;calibration_epoch<=0;calibration_cfg_id<=0;calibration_target_id<=0;
            candidate_color<=0;candidate_min_main<=0;candidate_diff_1<=0;candidate_diff_2<=0;
        end else begin
            calibration_done<=sample_done;
            if(sample_done) begin
                calibration_ok<=reason==0;calibration_reason<=reason;
                calibration_frame_id<=sample_frame_id;calibration_epoch<=sample_epoch;
                calibration_cfg_id<=sample_cfg_id;calibration_target_id<=sample_target_id;
                candidate_color<=reason==0 ? dominant : 2'd0;
                candidate_min_main<=reason==0 ? subtract_margin($signed({2'b0,main_value})) : 8'd0;
                candidate_diff_1<=reason==0 ? subtract_margin(d1) : 8'd0;
                candidate_diff_2<=reason==0 ? subtract_margin(d2) : 8'd0;
            end
        end
    end
endmodule
