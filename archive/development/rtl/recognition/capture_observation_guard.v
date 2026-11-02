// Same-clock qualification of a complete C2a packet. No payload duplication.
// A supplies authoritative active_epoch and asserts source_flush at a restart barrier.
// Consumers sample result_strobe/new_observation and the unchanged packet together.
module capture_observation_guard (
    input wire clk,rst_n,packet_strobe,source_flush,
    input wire [31:0] packet_frame_id,packet_epoch,active_epoch,
    output wire result_strobe,new_observation
);
    reg seen;
    reg [31:0] last_frame,last_epoch;
    assign result_strobe=rst_n && packet_strobe && !source_flush && packet_epoch==active_epoch;
    assign new_observation=result_strobe && (!seen || packet_frame_id!=last_frame || packet_epoch!=last_epoch);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin seen<=0;last_frame<=0;last_epoch<=0;end
        else if(new_observation) begin
            seen<=1;last_frame<=packet_frame_id;last_epoch<=packet_epoch;
        end
    end
endmodule
