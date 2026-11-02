// Deduplicate consecutive presentations of one source capture frame.
// Upstream owns ordering/replay policy; comparison is equality, not numeric >.
module result_new_frame #(
    parameter FRAME_WIDTH=32,PAYLOAD_WIDTH=172
)(
    input wire clk,rst_n,input_strobe,
    input wire [FRAME_WIDTH-1:0] input_frame_id,
    input wire [PAYLOAD_WIDTH-1:0] input_payload,
    output reg result_strobe,
    output reg [FRAME_WIDTH-1:0] result_frame_id,
    output reg [PAYLOAD_WIDTH-1:0] result_payload
);
    reg seen_frame;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            seen_frame<=0;result_strobe<=0;result_frame_id<=0;result_payload<=0;
        end else begin
            result_strobe<=0;
            if(input_strobe && (!seen_frame || input_frame_id!=result_frame_id)) begin
                seen_frame<=1;result_strobe<=1;
                result_frame_id<=input_frame_id;result_payload<=input_payload;
            end
        end
    end
endmodule
