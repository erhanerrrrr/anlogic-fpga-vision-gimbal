// Per-channel thresholds; GREEN additionally requires ceil(G/4) dominance.
// One-register latency is retained.
module color_classifier_runtime(
    input wire [7:0] min_main,min_diff_1,min_diff_2,
    input wire clk,
    input wire rst_n,
    input wire pixel_valid,
    input wire [23:0] rgb,
    input wire [1:0] active_color, // 0=R, 1=G, 2=B; 3 invalid
    output reg mask_valid,
    output reg mask
);
    reg [7:0] main_channel, other_1, other_2;
    wire signed [8:0] difference_1;
    wire signed [8:0] difference_2;
    wire [8:0] rounded_main = {1'b0,main_channel} + (active_color==1?9'd3:9'd7);
    wire [7:0] relative_floor = active_color==1 ? {1'b0,rounded_main[8:2]} : {2'b0,rounded_main[8:3]};
    wire adaptive_color = active_color==2'd1 || active_color==2'd2;
    wire [7:0] required_1 = adaptive_color && relative_floor>min_diff_1 ? relative_floor : min_diff_1;
    wire [7:0] required_2 = adaptive_color && relative_floor>min_diff_2 ? relative_floor : min_diff_2;
    assign difference_1 = $signed({1'b0, main_channel}) - $signed({1'b0, other_1});
    assign difference_2 = $signed({1'b0, main_channel}) - $signed({1'b0, other_2});
    always @* begin
        main_channel = 0;
        other_1 = 0;
        other_2 = 0;
        case (active_color)
            2'd0: begin main_channel=rgb[23:16]; other_1=rgb[15:8]; other_2=rgb[7:0]; end
            2'd1: begin main_channel=rgb[15:8]; other_1=rgb[23:16]; other_2=rgb[7:0]; end
            2'd2: begin main_channel=rgb[7:0]; other_1=rgb[23:16]; other_2=rgb[15:8]; end
            default: begin main_channel=0; other_1=0; other_2=0; end
        endcase
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mask_valid <= 1'b0;
            mask <= 1'b0;
        end else begin
            mask_valid <= pixel_valid;
            mask <= pixel_valid && (active_color != 2'd3) &&
                    (main_channel >= min_main) &&
                    (difference_1 >= $signed({1'b0, required_1})) &&
                    (difference_2 >= $signed({1'b0, required_2}));
        end
    end
endmodule
