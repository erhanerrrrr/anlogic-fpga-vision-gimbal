// One in-flight frame; no frame buffer and no ready/backpressure.
// Two pixel registers let the existing asynchronous-reset datapath be cleared
// for one full clock at SOF/abort before its first new pixel is presented.
// RAM contents need no reset: the existing filter/region core qualify history.
module capture_frame_guard #(
    parameter WIDTH=1280,HEIGHT=720
)(
    input wire clk,rst_n,source_flush,
    input wire [31:0] active_epoch,
    input wire pixel_valid,sof,eof,
    input wire [23:0] rgb,
    input wire [10:0] x,y,
    input wire [31:0] source_frame_id,source_epoch,
    input wire [15:0] requested_cfg_id,
    input wire [1:0] requested_color,
    input wire [7:0] requested_min_main,requested_min_diff_1,requested_min_diff_2,
    input wire candidate_strobe,
    input wire [31:0] candidate_frame_id,
    input wire [15:0] candidate_cfg_id,
    input wire [1:0] candidate_target_id,
    output wire accept_result,new_source_sof,accepted_sof,processing_rst_n,
    output reg frame_abort,stream_error,
    output reg out_valid,out_sof,out_eof,
    output reg [23:0] out_rgb,
    output reg [10:0] out_x,out_y,
    output reg [31:0] frame_id,frame_epoch,
    output reg [15:0] active_cfg_id,
    output reg [1:0] active_color,
    output reg [7:0] active_min_main,active_min_diff_1,active_min_diff_2
);
    reg have_source,input_open,job_pending,input_complete,clear_pipeline;
    reg [10:0] expected_x,expected_y;
    reg p_valid,p_sof,p_eof;
    reg [23:0] p_rgb;
    reg [10:0] p_x,p_y;
    wire final_pixel=(x==WIDTH-1 && y==HEIGHT-1);
    assign accepted_sof=rst_n && !source_flush && pixel_valid && sof && !eof &&
                        x==0 && y==0 && source_epoch==active_epoch;
    assign new_source_sof=accepted_sof && (!have_source || source_frame_id!=frame_id || source_epoch!=frame_epoch);
    wire rejected_sof=pixel_valid && sof && !accepted_sof;
    wire bad_pixel=input_open && pixel_valid && !sof &&
                   (x!=expected_x || y!=expected_y || eof!=final_pixel);
    // H4E majority-filter input has continuous pixels inside each row.
    wire bad_gap=input_open && !pixel_valid && expected_x!=0;
    wire revoked=job_pending && frame_epoch!=active_epoch;
    wire abort_now=source_flush || rejected_sof || bad_pixel || bad_gap || revoked;
    wire take_pixel=accepted_sof || (rst_n && !abort_now && input_open && pixel_valid && !sof);
    assign processing_rst_n=rst_n && !clear_pipeline;
    assign accept_result=rst_n && job_pending && input_complete && candidate_strobe &&
                         !accepted_sof && !abort_now && frame_epoch==active_epoch &&
                         candidate_frame_id==frame_id && candidate_cfg_id==active_cfg_id &&
                         candidate_target_id==active_color;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            have_source<=0;input_open<=0;job_pending<=0;input_complete<=0;clear_pipeline<=1;
            expected_x<=0;expected_y<=0;frame_id<=0;frame_epoch<=0;
            active_cfg_id<=1;active_color<=0;active_min_main<=24;active_min_diff_1<=16;active_min_diff_2<=16;
            frame_abort<=0;stream_error<=0;
            p_valid<=0;p_sof<=0;p_eof<=0;p_rgb<=0;p_x<=0;p_y<=0;
            out_valid<=0;out_sof<=0;out_eof<=0;out_rgb<=0;out_x<=0;out_y<=0;
        end else begin
            clear_pipeline<=accepted_sof || abort_now;
            frame_abort<=job_pending && (accepted_sof || abort_now);
            stream_error<=rejected_sof || bad_pixel || bad_gap;
            p_valid<=take_pixel;
            if(take_pixel) begin p_rgb<=rgb;p_x<=x;p_y<=y;p_sof<=sof;p_eof<=eof;end
            out_valid<=p_valid;
            if(p_valid) begin out_rgb<=p_rgb;out_x<=p_x;out_y<=p_y;out_sof<=p_sof;out_eof<=p_eof;end
            if(accepted_sof) begin
                have_source<=1;frame_id<=source_frame_id;frame_epoch<=source_epoch;
                input_open<=1;job_pending<=1;input_complete<=0;expected_x<=1;expected_y<=0;
                if(new_source_sof) begin
                    active_cfg_id<=requested_cfg_id;active_color<=requested_color;
                    active_min_main<=requested_min_main;active_min_diff_1<=requested_min_diff_1;
                    active_min_diff_2<=requested_min_diff_2;
                end
            end else if(abort_now) begin
                input_open<=0;job_pending<=0;input_complete<=0;expected_x<=0;expected_y<=0;
            end else begin
                if(take_pixel) begin
                    if(final_pixel) begin input_open<=0;input_complete<=1;expected_x<=0;expected_y<=0;end
                    else if(x==WIDTH-1) begin expected_x<=0;expected_y<=y+1'b1;end
                    else expected_x<=x+1'b1;
                end
                if(accept_result) job_pending<=0;
            end
        end
    end
endmodule
