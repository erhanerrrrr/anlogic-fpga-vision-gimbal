`timescale 1ns/1ps
// B4a: one selected latency kind at a time, disjoint power-of-two windows.
// sample_valid is a one-clock measurement event, not a held "data present" bit.
// kind 0=acquisition SOF to display SOF, 1=acquisition EOF to result,
// kind 2=external measurement. Kind 3 is reserved and ignored.
// WINDOW_LOG2 must be 1..8. No divider, multiplier, RAM or per-sample buffer.
module latency_window_stats #(
    parameter integer WINDOW_LOG2=3
)(
    input wire clk,rst_n,clear,
    input wire sample_valid,
    input wire [31:0] sample_us,
    input wire [1:0] sample_kind,
    output reg stats_valid,
    output reg [1:0] stats_kind,
    output reg [31:0] min_us,avg_us,max_us,
    output reg [8:0] sample_count
);
    localparam integer WINDOW_SIZE=(1 << WINDOW_LOG2);
    reg accumulating;
    reg [1:0] active_kind;
    reg [8:0] count;
    reg [39:0] sum;
    reg [31:0] running_min,running_max;
    wire new_kind=!accumulating || sample_kind!=active_kind;
    wire [39:0] next_sum=sum+{8'd0,sample_us};

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            accumulating<=0;active_kind<=0;count<=0;sum<=0;
            running_min<=0;running_max<=0;
            stats_valid<=0;stats_kind<=0;
            min_us<=0;avg_us<=0;max_us<=0;sample_count<=0;
        end else if(clear) begin
            accumulating<=0;active_kind<=0;count<=0;sum<=0;
            running_min<=0;running_max<=0;
            stats_valid<=0;stats_kind<=0;
            min_us<=0;avg_us<=0;max_us<=0;sample_count<=0;
        end else if(sample_valid && sample_kind!=2'd3) begin
            if(new_kind) begin
                accumulating<=1;active_kind<=sample_kind;
                stats_valid<=0;sample_count<=0;
                count<=1;sum<={8'd0,sample_us};
                running_min<=sample_us;running_max<=sample_us;
            end else if(count==WINDOW_SIZE-1) begin
                count<=0;sum<=0;
                min_us<=sample_us<running_min ? sample_us : running_min;
                max_us<=sample_us>running_max ? sample_us : running_max;
                avg_us<=next_sum >> WINDOW_LOG2;
                stats_kind<=active_kind;sample_count<=WINDOW_SIZE;
                stats_valid<=1;
            end else if(count==0) begin
                count<=1;sum<={8'd0,sample_us};
                running_min<=sample_us;running_max<=sample_us;
            end else begin
                count<=count+1'b1;sum<=next_sum;
                if(sample_us<running_min)running_min<=sample_us;
                if(sample_us>running_max)running_max<=sample_us;
            end
        end
    end
endmodule
